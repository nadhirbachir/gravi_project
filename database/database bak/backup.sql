--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: company_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.company_status AS ENUM (
    'inactive',
    'active',
    'suspended'
);


ALTER TYPE public.company_status OWNER TO postgres;

--
-- Name: email_type; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.email_type AS character varying(150)
	CONSTRAINT email_type_check CHECK (((VALUE)::text ~* '^[A-Za-z0-9_%+-]+(\.[A-Za-z0-9_%+-]+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,10}$'::text));


ALTER DOMAIN public.email_type OWNER TO postgres;

--
-- Name: remote_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.remote_type AS ENUM (
    'onsite',
    'hybrid',
    'remote'
);


ALTER TYPE public.remote_type OWNER TO postgres;

--
-- Name: url_type; Type: DOMAIN; Schema: public; Owner: postgres
--

CREATE DOMAIN public.url_type AS character varying(255)
	CONSTRAINT url_type_check CHECK (((VALUE IS NULL) OR ((VALUE)::text ~* '^((https?|ftp):\/\/)?([a-z0-9-]+\.)+[a-z]{2,10}([\/?#].*)?$'::text)));


ALTER DOMAIN public.url_type OWNER TO postgres;

--
-- Name: accept_connection(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.accept_connection(p_user_id bigint, p_target_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Only the target of the original request can accept
  IF NOT EXISTS (
    SELECT 1 FROM connections
    WHERE user_id = p_target_user_id AND target_user_id = p_user_id
	AND status = 0
  ) THEN
    RETURN -1;
  END IF;

  UPDATE connections
  SET status = 1,
      updated_at = NOW()
  WHERE user_id = p_target_user_id AND target_user_id = p_user_id;

  RETURN 1;
EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;
$$;


ALTER FUNCTION public.accept_connection(p_user_id bigint, p_target_user_id bigint) OWNER TO postgres;

--
-- Name: add_attachment(smallint, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_attachment(p_type smallint, p_url text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_attachment_id UUID;
BEGIN
    -- Validate inputs
    IF p_url IS NULL OR TRIM(p_url) = '' THEN
        RAISE EXCEPTION 'Attachment URL cannot be empty.';
    END IF;

    -- You might add more validation here for p_type if you have specific allowed values.
    -- For example: IF p_type NOT IN (1, 2, 3) THEN RAISE EXCEPTION 'Invalid attachment type.'; END IF;

    -- Insert the new attachment record
    INSERT INTO attachments (type, url)
    VALUES (p_type, p_url)
    RETURNING attachment_id INTO v_attachment_id;

    RETURN v_attachment_id;
END;
$$;


ALTER FUNCTION public.add_attachment(p_type smallint, p_url text) OWNER TO postgres;

--
-- Name: add_company(bigint, text, text, bigint, smallint, date, smallint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_company(p_by_user_id bigint, p_name text, p_website text, p_industry_id bigint, p_size smallint, p_founded_date date, p_location_id smallint) RETURNS uuid
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_company_count INTEGER;
    v_email TEXT;
    v_is_verified BOOLEAN;
    v_email_domain TEXT;
    v_website_domain TEXT;
    v_new_company_id UUID;
    v_user RECORD;
BEGIN
    -- 🔒 1. Null input checks
    IF p_by_user_id IS NULL OR p_name IS NULL OR TRIM(p_name) = '' OR
       p_website IS NULL OR p_industry_id IS NULL OR p_size IS NULL OR
       p_founded_date IS NULL OR p_location_id IS NULL THEN
        RAISE EXCEPTION 'Missing required fields for creating a company.';
    END IF;

    -- ✅ 2. Validate length
    IF LENGTH(p_name) > 255 THEN
        RAISE EXCEPTION 'Company name cannot exceed 255 characters.';
    END IF;

    IF LENGTH(p_website) > 150 THEN
        RAISE EXCEPTION 'Website URL cannot exceed 150 characters.';
    END IF;

    -- 👤 3. Check user existence & get email + verification
    SELECT * INTO v_user FROM get_user_by_id(p_by_user_id);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User (ID: %) does not exist.', p_by_user_id;
    END IF;

    v_email := v_user.email;
    v_is_verified := v_user.is_email_verified;

    IF v_email IS NULL OR TRIM(v_email) = '' THEN
        RAISE EXCEPTION 'User does not have a valid email.';
    END IF;

    IF NOT v_is_verified THEN
        RAISE EXCEPTION 'User email must be verified before creating a company.';
    END IF;

    -- 🏢 4. Count owned companies
    v_company_count := user_companies_number(p_by_user_id);

    IF v_company_count >= 1 THEN
        RAISE EXCEPTION 'User already owns a company. Please request approval for another.';
    END IF;

    -- 🌐 5. Validate domain match
    v_email_domain := lower(split_part(v_email, '@', 2));
    v_website_domain := lower(regexp_replace(p_website, '^https?://(www\.)?|/.*$', '', 'gi'));

    IF v_email_domain IS NULL OR v_website_domain IS NULL OR v_email_domain <> v_website_domain THEN
        RAISE EXCEPTION 'Email domain (%) does not match website domain (%), you need to request approval to create this company.', v_email_domain, v_website_domain;
    END IF;

    -- 🏭 6. Insert company
    INSERT INTO companies (
        name, website, contact_email, industry_id, size,
        founded_date, location_id, status
    ) VALUES (
        p_name, p_website, v_email, p_industry_id, p_size,
        p_founded_date, p_location_id, 0  -- status 0 = unofficial
    )
    RETURNING company_id INTO v_new_company_id;

    -- 👑 7. Register user as owner
    INSERT INTO company_admins (company_id, user_id, role)
    VALUES (v_new_company_id, p_by_user_id, 2); -- role = owner

    RETURN v_new_company_id;

-- ⚠️ 8. Catch and return SQL errors
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to create company: %', SQLERRM;
END;
$_$;


ALTER FUNCTION public.add_company(p_by_user_id bigint, p_name text, p_website text, p_industry_id bigint, p_size smallint, p_founded_date date, p_location_id smallint) OWNER TO postgres;

--
-- Name: add_person(text, text, text, integer, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_person(p_first_name text, p_middle_name text, p_last_name text, p_country_id integer, p_date_of_birth date, p_gender integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_id INTEGER;
    v_first_name VARCHAR(50);
    v_middle_name VARCHAR(50);
    v_last_name VARCHAR(50);
BEGIN

    v_first_name := SUBSTRING(NULLIF(TRIM(p_first_name), ''), 0, 50);
    v_middle_name := SUBSTRING(NULLIF(TRIM(p_middle_name), ''), 0, 50);
    v_last_name := SUBSTRING(NULLIF(TRIM(p_last_name), ''), 0, 50);

    IF v_first_name IS NULL OR v_last_name IS NULL THEN RETURN -1; END IF;

    BEGIN
        INSERT INTO people (
            first_name, middle_name, last_name,
            country_id, date_of_birth, gender
        )
        VALUES (
            v_first_name, v_middle_name, v_last_name,
            p_country_id, p_date_of_birth, p_gender::SMALLINT
        )
        RETURNING person_id INTO new_id;

        RETURN new_id;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Insert failed: %', SQLERRM;
            RETURN -1;
    END;
END;
$$;


ALTER FUNCTION public.add_person(p_first_name text, p_middle_name text, p_last_name text, p_country_id integer, p_date_of_birth date, p_gender integer) OWNER TO postgres;

--
-- Name: add_user(bigint, text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_user(p_person_id bigint, p_user_name text, p_phone_number text, p_email text, p_password_hash text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_username VARCHAR(50);
    v_phone_number VARCHAR(20);
    v_email VARCHAR(150);
    v_password_hash VARCHAR(300);
    new_id INTEGER;
BEGIN
    -- Handle VARCHAR conversions with proper length limits
    v_username := SUBSTRING(NULLIF(TRIM(p_user_name), ''), 1, 50);
    v_phone_number := SUBSTRING(NULLIF(TRIM(p_phone_number), ''), 1, 20);
    v_email := SUBSTRING(NULLIF(TRIM(LOWER(p_email)), ''), 1, 150);
    v_password_hash := SUBSTRING(NULLIF(TRIM(p_password_hash), ''), 1, 300);
    
    -- Check required NOT NULL fields
    IF v_username IS NULL OR v_email IS NULL OR v_password_hash IS NULL THEN
        RETURN -4; -- Required field is null or empty
    END IF;
    
    INSERT INTO users (
        person_id, 
        username, 
        phone_number, 
        email, 
        password_hash
    ) VALUES (
        p_person_id, 
        v_username, 
        v_phone_number, 
        v_email, 
        v_password_hash
    ) RETURNING user_id INTO new_id;
    
    RETURN new_id; -- Success
    
EXCEPTION
    WHEN foreign_key_violation THEN
        RETURN -1; -- Person ID not found
    WHEN unique_violation THEN
        RETURN -2; -- Username, email, or person_id already exists
    WHEN check_violation THEN
        RETURN -3; -- Username length, email format, or phone format problem
    WHEN OTHERS THEN
        RETURN 0; -- Unexpected exception
END;
$$;


ALTER FUNCTION public.add_user(p_person_id bigint, p_user_name text, p_phone_number text, p_email text, p_password_hash text) OWNER TO postgres;

--
-- Name: block_connection(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.block_connection(p_user_id bigint, p_target_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_status INT;
BEGIN
    -- Input validation
    IF p_user_id IS NULL OR p_target_user_id IS NULL THEN
        RETURN -1;
    END IF;
    
    IF p_user_id = p_target_user_id THEN
        RETURN -1; -- Cannot block yourself
    END IF;

    -- Get current connection status
    SELECT status INTO current_status
    FROM connections
    WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
    OR (user_id = p_target_user_id AND target_user_id = p_user_id)
    LIMIT 1;

    -- If no connection exists, create new blocked connection
    IF NOT FOUND THEN
        INSERT INTO connections (user_id, target_user_id, status, created_at, updated_at)
        VALUES (p_user_id, p_target_user_id, 2, NOW(), NOW());
        RETURN 1; -- Successfully blocked
    END IF;

    -- Handle existing connections based on current status
    CASE current_status
        WHEN 1 THEN -- Currently connected, user blocks target
            UPDATE connections
            SET status = 2, updated_at = NOW()
            WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
            OR (user_id = p_target_user_id AND target_user_id = p_user_id);
            
        WHEN 2 THEN -- User already blocked target
            RETURN 0; -- Nothing to do
            
        WHEN 4 THEN -- Target blocked user, now both block each other
            UPDATE connections
            SET status = 6, updated_at = NOW()
            WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
            OR (user_id = p_target_user_id AND target_user_id = p_user_id);
            
        WHEN 6 THEN -- Both already blocked
            RETURN 0; -- Nothing to do
            
        ELSE -- Pending or other status, set to user blocked target
            UPDATE connections
            SET status = 2, updated_at = NOW()
            WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
            OR (user_id = p_target_user_id AND target_user_id = p_user_id);
    END CASE;

    RETURN 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'block_connection failed for user_id % and target_user_id %: %', 
                      p_user_id, p_target_user_id, SQLERRM;
        RETURN -1;
END;
$$;


ALTER FUNCTION public.block_connection(p_user_id bigint, p_target_user_id bigint) OWNER TO postgres;

--
-- Name: check_years_of_exp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_years_of_exp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_age INT;
BEGIN
    SELECT EXTRACT(YEAR FROM AGE(p.date_of_birth)) INTO user_age
    FROM users u
    JOIN people p ON u.person_id = p.person_id
    WHERE u.user_id = NEW.user_id;

    IF NEW.years_of_exp > user_age - 10 THEN
        RAISE EXCEPTION 'Years of experience exceeds possible based on age.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_years_of_exp() OWNER TO postgres;

--
-- Name: create_connection(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_connection(p_user_id bigint, p_target_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Prevent self-connection
  IF p_user_id = p_target_user_id THEN
    RETURN -1;
  END IF;

  -- Insert the new connection
  INSERT INTO connections (user_id, target_user_id)
  VALUES (p_user_id, p_target_user_id);

  RETURN 1;

EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;
$$;


ALTER FUNCTION public.create_connection(p_user_id bigint, p_target_user_id bigint) OWNER TO postgres;

--
-- Name: create_private_chat(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_private_chat(p_user1_id bigint, p_user2_id bigint) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_chat_id UUID;
    v_connection_status SMALLINT;
    v_existing_chat_id UUID;
BEGIN
    -- 1. Prevent self-chat
    IF p_user1_id IS NULL OR p_user2_id IS NULL OR p_user1_id = p_user2_id 
	OR NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user1_id)
	OR NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user2_id)
	THEN
        RAISE EXCEPTION 'problem creating chat, parameters issue (user1_id, user2_id)';
    END IF;

    -- 2. Check for existing 1-on-1 chat between these two participants
    -- This query finds a chat where both p_user1_id and p_user2_id are participants,
    -- and that chat has exactly two participants.
    SELECT cp.chat_id
    INTO v_existing_chat_id
    FROM chat_participants cp
    WHERE cp.participant_id = p_user1_id
    AND EXISTS (
        SELECT 1
        FROM chat_participants cp2
        WHERE cp2.chat_id = cp.chat_id AND cp2.participant_id = p_user2_id
    )
    AND (
        SELECT COUNT(*) FROM chat_participants cp3 WHERE cp3.chat_id = cp.chat_id
    ) = 2
    LIMIT 1; -- Should only find one such chat if your chat_participants design is sound

    IF v_existing_chat_id IS NOT NULL THEN
        RAISE NOTICE 'A chat already exists between participants % and %. Returning existing chat ID.', p_user1_id, p_user2_id;
        RETURN v_existing_chat_id;
    END IF;

    -- 3. Check connection status for blocking
    -- Call find_connection with a consistent order of user IDs if your find_connection
    -- requires it, or ensure find_connection handles permutations.
    v_connection_status := find_connection(p_user1_id, p_user2_id);

    -- Conditions for blocking: status is 2 (user1 blocked user2), 4 (user2 blocked user1), or 6 (mutual block)
    IF v_connection_status <> 1 THEN
        RAISE EXCEPTION 'Chat cannot be created due to blocking or pending status (status %) between participants % and %.', v_connection_status, p_user1_id, p_user2_id;
    END IF;

    -- 4. Create the new chat
    INSERT INTO chats DEFAULT VALUES
    RETURNING chat_id INTO v_chat_id;

    -- 5. Add participants to the new chat
    INSERT INTO chat_participants (chat_id, participant_id)
    VALUES (v_chat_id, p_user1_id);

    INSERT INTO chat_participants (chat_id, participant_id)
    VALUES (v_chat_id, p_user2_id);

    RETURN v_chat_id;
END;
$$;


ALTER FUNCTION public.create_private_chat(p_user1_id bigint, p_user2_id bigint) OWNER TO postgres;

--
-- Name: delete_chat_if_no_participants(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_chat_if_no_participants() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Variable to store the count of remaining participants for the chat
    participant_count INT;
BEGIN
    -- Count the number of active participants for the chat that the deleted participant belonged to
    SELECT COUNT(*)
    INTO participant_count
    FROM chat_participants
    WHERE chat_id = OLD.chat_id; -- OLD refers to the row that was just deleted from chat_participants

    -- If no participants are left for this chat, delete the chat
    IF participant_count = 0 THEN
        DELETE FROM chats
        WHERE chat_id = OLD.chat_id;
    END IF;

    RETURN OLD; -- Allows the original DELETE operation on chat_participants to proceed
END;
$$;


ALTER FUNCTION public.delete_chat_if_no_participants() OWNER TO postgres;

--
-- Name: delete_connection(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_connection(p_user_id bigint, p_target_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM connections
    WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
       OR (user_id = p_target_user_id AND target_user_id = p_user_id)
  ) THEN
    RETURN -1;
  END IF;

  DELETE FROM connections
  WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
     OR (user_id = p_target_user_id AND target_user_id = p_user_id);

  RETURN 1;
EXCEPTION
  WHEN OTHERS THEN
    RETURN -1;
END;
$$;


ALTER FUNCTION public.delete_connection(p_user_id bigint, p_target_user_id bigint) OWNER TO postgres;

--
-- Name: delete_person(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_person(p_person_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN

    DELETE FROM people WHERE person_id = p_person_id;

    IF NOT FOUND THEN RETURN -1; END IF;

    RETURN 1;

    EXCEPTION
        WHEN OTHERS THEN RETURN -1;
END;
$$;


ALTER FUNCTION public.delete_person(p_person_id bigint) OWNER TO postgres;

--
-- Name: delete_user(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.delete_user(p_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    delete_count INTEGER;
BEGIN
    -- Check if user exists
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id) THEN RETURN -1; END IF;

    BEGIN
        DELETE FROM users WHERE user_id = p_user_id;
        
        GET DIAGNOSTICS delete_count = ROW_COUNT;
        
        IF delete_count = 0 THEN
            RETURN -1; -- User not found
        END IF;
        
        RETURN DELETE_COUNT; -- Success
        
    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN -11; -- Cannot delete due to foreign key constraints
        WHEN OTHERS THEN
            RETURN 0; -- Unexpected exception
    END;

END;
$$;


ALTER FUNCTION public.delete_user(p_user_id bigint) OWNER TO postgres;

--
-- Name: edu_mview_changes_trgfun(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.edu_mview_changes_trgfun() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Refresh the materialized view after any change in the educations table
    REFRESH MATERIALIZED VIEW edu_user_details;
    RETURN NULL;  -- Always return NULL in an AFTER trigger since we're not modifying the row
END;
$$;


ALTER FUNCTION public.edu_mview_changes_trgfun() OWNER TO postgres;

--
-- Name: find_chat_by_participants(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_chat_by_participants(p_user1_id bigint, p_user2_id bigint) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_chat_id UUID;
BEGIN
    -- Prevent searching for a chat with the same user
    IF p_user1_id IS NULL OR p_user2_id IS NULL OR p_user1_id = p_user2_id 
	OR NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user1_id)
	OR NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user2_id)
	THEN
        RETURN NULL;
    END IF;

    -- Look for a chat where both users are participants AND the chat has exactly two participants.
    SELECT cp.chat_id
    INTO v_chat_id
    FROM chat_participants cp
    WHERE cp.participant_id = p_user1_id
      AND EXISTS (
          SELECT 1
          FROM chat_participants cp2
          WHERE cp2.chat_id = cp.chat_id
            AND cp2.participant_id = p_user2_id
      )
      AND (
          SELECT COUNT(*)
          FROM chat_participants cp3
          WHERE cp3.chat_id = cp.chat_id
      ) = 2
    LIMIT 1; -- Ensure only one chat is returned if multiple somehow matched (though UNIQUE constraint on chat_participants(chat_id, participant_id) should prevent issues).

    RETURN v_chat_id;

	EXCEPTION
	WHEN OTHERS THEN
		RAISE EXCEPTION 'Exception occured %' , SQLERRM
	END;
END;
$$;


ALTER FUNCTION public.find_chat_by_participants(p_user1_id bigint, p_user2_id bigint) OWNER TO postgres;

--
-- Name: find_chat_by_participants_username(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_chat_by_participants_username(p_user1_username text, p_user2_username text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user1_id BIGINT;
    v_user2_id BIGINT;
    v_chat_id UUID;
BEGIN
    -- 1. Validate usernames and retrieve user_ids
    IF p_user1_username IS NULL OR p_user2_username IS NULL OR p_user1_username = p_user2_username THEN
        RETURN NULL;
    END IF;

    SELECT user_id INTO v_user1_id FROM users WHERE username = p_user1_username;
    SELECT user_id INTO v_user2_id FROM users WHERE username = p_user2_username;

    -- If either username does not exist, return NULL
    IF v_user1_id IS NULL OR v_user2_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 2. Look for a chat where both users are participants and the chat has exactly two participants.
    -- This approach is generally more robust for finding chats with specific participants.
    SELECT cp.chat_id
    INTO v_chat_id
    FROM chat_participants cp
    WHERE cp.participant_id = v_user1_id
      AND EXISTS (
          SELECT 1
          FROM chat_participants cp2
          WHERE cp2.chat_id = cp.chat_id
            AND cp2.participant_id = v_user2_id
      )
      AND (
          SELECT COUNT(*)
          FROM chat_participants cp3
          WHERE cp3.chat_id = cp.chat_id
      ) = 2
    LIMIT 1; -- Ensure only one chat is returned if multiple somehow matched (e.g., due to data inconsistencies)

    RETURN v_chat_id;

-- Corrected EXCEPTION block syntax
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error for debugging purposes if needed
        RAISE WARNING 'An exception occurred in find_chat_by_participants_username: %', SQLERRM;
        RETURN NULL; -- Or re-raise if you want the calling application to handle it
END;
$$;


ALTER FUNCTION public.find_chat_by_participants_username(p_user1_username text, p_user2_username text) OWNER TO postgres;

--
-- Name: find_connection(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_connection(p_user_id bigint, p_target_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    conn RECORD;
BEGIN

	IF p_user_id IS NULL OR p_target_user_id IS NULL
	OR p_user_id = p_target_user_id THEN
	RETURN -1;
	END IF;

    SELECT user_id, target_user_id, status
    INTO conn
    FROM connections
    WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
    OR (user_id = p_target_user_id AND target_user_id = p_user_id)
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN -1; -- No connection found
    END IF;

    -- Handle different status codes
    CASE conn.status
        WHEN 0 THEN -- Pending request
            IF conn.user_id = p_user_id THEN
                RETURN 0; -- You sent the pending request
            ELSE
                RETURN 3; -- They sent it to you
            END IF;
            
        WHEN 1 THEN -- Connected/Accepted
            RETURN 1;
            
        WHEN 2 THEN -- User blocked target
            IF conn.user_id = p_user_id THEN
                RETURN 2; -- You blocked them
            ELSE
                RETURN 4; -- They blocked you (reverse perspective)
            END IF;
            
        WHEN 4 THEN -- Target blocked user
            IF conn.user_id = p_user_id THEN
                RETURN 4; -- They blocked you
            ELSE
                RETURN 2; -- You blocked them (reverse perspective)
            END IF;
            
        WHEN 6 THEN -- Both blocked each other
            RETURN 6;
            
        ELSE -- Unknown status
            RETURN conn.status;
    END CASE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'find_connection failed for user_id % and target_user_id %: %', 
                      p_user_id, p_target_user_id, SQLERRM;
        RETURN -1;
END;
$$;


ALTER FUNCTION public.find_connection(p_user_id bigint, p_target_user_id bigint) OWNER TO postgres;

--
-- Name: follow_user(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.follow_user(follow_src bigint, follow_dst bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    succeed BIGINT DEFAULT -1;
BEGIN
    IF(follow_src IS NULL OR follow_dst IS NULL) THEN RETURN -2; END IF;

    BEGIN
        INSERT INTO follows (follower_id, followee_id) VALUES
        (follow_src, follow_dst)
        RETURNING follow_id INTO succeed;

        RETURN succeed;

        EXCEPTION
        WHEN OTHERS THEN RETURN -1;

    END;
END;
$$;


ALTER FUNCTION public.follow_user(follow_src bigint, follow_dst bigint) OWNER TO postgres;

--
-- Name: get_connections(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_connections(p_user_id bigint) RETURNS TABLE(username character varying, full_name character varying, profile_pic_url character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Input validation
    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        RAISE EXCEPTION 'Invalid user_id: %', p_user_id;
    END IF;

    RETURN QUERY
    SELECT
        u.username,
        CONCAT(
            p.first_name,
            CASE
                WHEN p.middle_name IS NOT NULL THEN CONCAT(' ', p.middle_name, ' ')
                ELSE ' '
            END,
            p.last_name
        )::VARCHAR(160) AS full_name,
        pr.profile_pic_url AS profile_pic_url
    FROM connections c
    JOIN users u ON (
        (c.user_id = p_user_id AND u.user_id = c.target_user_id) OR
        (c.target_user_id = p_user_id AND u.user_id = c.user_id)
    )
    JOIN people p ON u.person_id = p.person_id
    LEFT JOIN profiles pr ON pr.user_id = u.user_id
    WHERE c.status = 1;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'get_connections failed for user_id %: %', p_user_id, SQLERRM;
END
$$;


ALTER FUNCTION public.get_connections(p_user_id bigint) OWNER TO postgres;

--
-- Name: get_followers(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_followers(user_id_dst bigint) RETURNS TABLE(user_id bigint, username character varying, full_name character varying, profile_pic_url character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF user_id_dst IS NULL OR NOT EXISTS (
        SELECT 1 FROM users WHERE users.user_id = user_id_dst
    ) THEN
        RETURN QUERY SELECT NULL::bigint, NULL::varchar(50), NULL::varchar(150), NULL::varchar(255) WHERE FALSE;
    END IF;

    RETURN QUERY
    SELECT f.follower_id AS user_id,
           u.username,
           CONCAT(
               p.first_name,
               CASE 
                   WHEN p.middle_name IS NOT NULL AND TRIM(p.middle_name) != '' 
                   THEN ' ' || p.middle_name || ' ' 
                   ELSE ' ' 
               END,
               p.last_name
           )::VARCHAR(150) AS full_name,
           pr.profile_pic_url
    FROM
        follows f 
        JOIN users u ON f.follower_id = u.user_id
        JOIN people p ON u.person_id = p.person_id
        LEFT JOIN profiles pr ON pr.user_id = u.user_id
    WHERE
        f.followee_id = user_id_dst;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'get followers failed: %', SQLERRM;
        RETURN QUERY SELECT NULL::bigint, NULL::varchar(50), NULL::varchar(150), NULL::varchar(255) WHERE FALSE;
END;
$$;


ALTER FUNCTION public.get_followers(user_id_dst bigint) OWNER TO postgres;

--
-- Name: get_following(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_following(user_id_src bigint) RETURNS TABLE(user_id bigint, username character varying, full_name character varying, profile_pic_url character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF user_id_src IS NULL OR NOT EXISTS (
        SELECT 1 FROM users WHERE users.user_id = user_id_src
    ) THEN
        RETURN QUERY SELECT ROW(NULL, NULL, NULL, NULL)::get_following%ROWTYPE WHERE FALSE;
    END IF;

    RETURN QUERY
    SELECT f.followee_id AS user_id,
           u.username,
           CONCAT(
               p.first_name,
               CASE 
                   WHEN p.middle_name IS NOT NULL AND TRIM(p.middle_name) != '' 
                   THEN ' ' || p.middle_name || ' ' 
                   ELSE ' ' 
               END,
               p.last_name
           )::VARCHAR(150) AS full_name,
           pr.profile_pic_url
    FROM
        follows f 
        JOIN users u ON f.followee_id = u.user_id
        JOIN people p ON u.person_id = p.person_id
        LEFT JOIN profiles pr ON pr.user_id = u.user_id
    WHERE
        f.follower_id = user_id_src;

EXCEPTION
    WHEN OTHERS THEN
        RAISE 'get following failed: %', SQLERRM;
        RETURN QUERY SELECT ROW(NULL, NULL, NULL, NULL)::get_following%ROWTYPE WHERE FALSE;
END;
$$;


ALTER FUNCTION public.get_following(user_id_src bigint) OWNER TO postgres;

--
-- Name: get_messages(uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_messages(p_chat_id uuid, p_limit integer DEFAULT 40, p_page_number integer DEFAULT 1) RETURNS TABLE(message_id uuid, chat_id uuid, sender_id bigint, content text, url text, file_type text, created_at timestamp with time zone, last_update timestamp with time zone, seen boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_offset INT;
BEGIN
    -- Calculate the offset for pagination
    IF p_page_number < 1 THEN
        p_page_number := 1; -- Ensure page number is at least 1
    END IF;
    v_offset := (p_page_number - 1) * p_limit;

    RETURN QUERY
    SELECT * FROM get_messages_view v
    WHERE
        v.chat_id = p_chat_id
    LIMIT p_limit
    OFFSET v_offset;
END;
$$;


ALTER FUNCTION public.get_messages(p_chat_id uuid, p_limit integer, p_page_number integer) OWNER TO postgres;

--
-- Name: get_user_by_id(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_user_by_id(p_user_id bigint) RETURNS TABLE(user_id bigint, person_id bigint, username character varying, phone_number character varying, email character varying, is_email_verified boolean, status smallint, last_login timestamp without time zone, created_at timestamp without time zone, updated_at timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.person_id,
        u.username,
        u.phone_number,
        u.email,
        u.is_email_verified,
        u.status,
        u.last_login,
        u.created_at,
        u.updated_at
    FROM users u
    WHERE u.user_id = p_user_id;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return empty result set on error
        RETURN;
END;
$$;


ALTER FUNCTION public.get_user_by_id(p_user_id bigint) OWNER TO postgres;

--
-- Name: get_user_chats(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_user_chats(p_user_id bigint) RETURNS TABLE(chat_id uuid, other_participant_id bigint, other_participant_username character varying, profile_pic_url character varying, other_participant_full_name character varying, last_message_content text, last_message_created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
	chsv.chat_id,
	chsv.other_participant_id,
	chsv.other_participant_username,
	chsv.profile_pic_url,
	chsv.other_participant_full_name::VARCHAR(200),
	chsv.last_message_content,
	chsv.last_message_created_at
    FROM
        chat_summaries_view chsv
    WHERE
        chsv.user_id = p_user_id; -- Filter the view by the provided user ID
END;
$$;


ALTER FUNCTION public.get_user_chats(p_user_id bigint) OWNER TO postgres;

--
-- Name: is_followed_by(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_followed_by(followee_id bigint, follower_id bigint) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT EXISTS (
        SELECT 1 FROM follows
        WHERE follower_id = $2 AND followee_id = $1
    );
$_$;


ALTER FUNCTION public.is_followed_by(followee_id bigint, follower_id bigint) OWNER TO postgres;

--
-- Name: prevent_duplicate_or_reversed_connections(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prevent_duplicate_or_reversed_connections() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM connections
    WHERE (user_id = NEW.user_id AND target_user_id = NEW.target_user_id)
       OR (user_id = NEW.target_user_id AND target_user_id = NEW.user_id)
  ) THEN
    RAISE EXCEPTION 'A connection already exists between these users';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.prevent_duplicate_or_reversed_connections() OWNER TO postgres;

--
-- Name: send_message(uuid, bigint, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.send_message(p_chat_id uuid, p_sender_id bigint, p_content text, p_attachment_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_recipient_id BIGINT;
    v_connection_status SMALLINT;
    v_sender_exists SMALLINT;
    v_recipient_exists SMALLINT;
    v_message_id UUID;
BEGIN
    -- 1. Validate chat existence and get recipient ID
    SELECT cp.participant_id
    INTO v_recipient_id
    FROM chat_participants cp
    WHERE cp.chat_id = p_chat_id
      AND cp.participant_id <> p_sender_id
    LIMIT 1;

    IF v_recipient_id IS NULL THEN
        RAISE EXCEPTION 'Chat ID % does not exist or sender % is not a participant, or chat is not a 1-on-1 chat.', p_chat_id, p_sender_id;
    END IF;

    -- 2. Validate sender and recipient existence using user_exists()
    v_sender_exists := user_exists(p_sender_id);
    v_recipient_exists := user_exists(v_recipient_id);

    IF v_sender_exists = -1 THEN
        RAISE EXCEPTION 'Sender user (ID: %) does not exist.', p_sender_id;
    END IF;

    IF v_recipient_exists = -1 THEN
        RAISE EXCEPTION 'Recipient user (ID: %) does not exist.', v_recipient_id;
    END IF;

    -- 3. Check connection status for blocking between sender and recipient
    -- Assumes find_connection from create_private_chat_function is available.
    v_connection_status := find_connection(p_sender_id, v_recipient_id);

    -- Conditions for blocking: status is 2 (sender blocked recipient), 4 (recipient blocked sender), or 6 (mutual block)
    IF v_connection_status <> 1 THEN
        RAISE EXCEPTION 'Message cannot be sent due to blocking or pending status (status %) between sender % and recipient %.', v_connection_status, p_sender_id, v_recipient_id;
    END IF;

    -- 4. Insert the message
    INSERT INTO messages (chat_id, sender_id, content, attachment_id)
    VALUES (p_chat_id, p_sender_id, p_content, p_attachment_id)
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$;


ALTER FUNCTION public.send_message(p_chat_id uuid, p_sender_id bigint, p_content text, p_attachment_id uuid) OWNER TO postgres;

--
-- Name: toggle_follow(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.toggle_follow(user_id_src bigint, user_id_dst bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    exists_flag BOOLEAN;
BEGIN
    -- Null check and self-follow check
    IF user_id_src IS NULL OR user_id_dst IS NULL
    OR user_id_src = user_id_dst
    OR NOT EXISTS (SELECT 1 FROM users WHERE users.user_id = user_id_src)
    OR NOT EXISTS (SELECT 1 FROM users WHERE users.user_id = user_id_dst) THEN
        RETURN -1; END IF;

    -- Check if already following
    SELECT EXISTS (
        SELECT 1 FROM follows
        WHERE follower_id = user_id_src AND followee_id = user_id_dst
    ) INTO exists_flag;

    IF exists_flag THEN
        -- Unfollow
        DELETE FROM follows
        WHERE follower_id = user_id_src AND followee_id = user_id_dst;

        RETURN 0;  -- Unfollowed
    ELSE
        -- Follow
        INSERT INTO follows (follower_id, followee_id)
        VALUES (user_id_src, user_id_dst);

        RETURN 1;  -- Followed
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN -3;  -- Fallback for unexpected errors
END;
$$;


ALTER FUNCTION public.toggle_follow(user_id_src bigint, user_id_dst bigint) OWNER TO postgres;

--
-- Name: unblock_connection(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.unblock_connection(p_user_id bigint, p_target_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_status INT;
BEGIN
    -- Input validation
    IF p_user_id IS NULL OR p_target_user_id IS NULL THEN
        RETURN -1;
    END IF;
    
    IF p_user_id = p_target_user_id THEN
        RETURN -1; -- Cannot unblock yourself
    END IF;

    -- Get current connection status
    SELECT status INTO current_status
    FROM connections
    WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
    OR (user_id = p_target_user_id AND target_user_id = p_user_id)
    LIMIT 1;

    -- If no connection exists, nothing to unblock
    IF NOT FOUND THEN
        RETURN 0; -- Nothing to unblock
    END IF;

    -- Handle unblocking based on current status
    CASE current_status
        WHEN 2 THEN -- User blocked target, user unblocks
            -- Delete connection (user was not blocked by target)
            DELETE FROM connections
            WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
            OR (user_id = p_target_user_id AND target_user_id = p_user_id);
            
        WHEN 4 THEN -- Target blocked user (user wasn't blocking)
            RETURN 0; -- User can't unblock what they didn't block
            
        WHEN 6 THEN -- Both blocked each other, user unblocks
            -- Change status to 4 (only target blocking user now)
            UPDATE connections
            SET status = 4, updated_at = NOW()
            WHERE (user_id = p_user_id AND target_user_id = p_target_user_id)
            OR (user_id = p_target_user_id AND target_user_id = p_user_id);
            
        ELSE -- Not blocked or other status
            RETURN 0; -- Nothing to unblock
    END CASE;

    RETURN 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'unblock_connection failed for user_id % and target_user_id %: %', 
                      p_user_id, p_target_user_id, SQLERRM;
        RETURN -1;
END;
$$;


ALTER FUNCTION public.unblock_connection(p_user_id bigint, p_target_user_id bigint) OWNER TO postgres;

--
-- Name: unfollow_user(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.unfollow_user(follow_src bigint, follow_dst bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    delete_count BIGINT DEFAULT -1;
BEGIN
    IF(follow_src IS NULL OR follow_dst IS NULL) THEN RETURN -1; END IF;

    BEGIN
        DELETE FROM follows WHERE (follower_id = follow_src AND followee_id = follow_dst);

        GET DIAGNOSTICS delete_count = ROW_COUNT;
        
        IF delete_count = 0 THEN
            RETURN -1; -- User not found
        END IF;
        
        RETURN delete_count; -- Success

        EXCEPTION
        WHEN OTHERS THEN RETURN -1;

    END;
END;
$$;


ALTER FUNCTION public.unfollow_user(follow_src bigint, follow_dst bigint) OWNER TO postgres;

--
-- Name: update_chat_last_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_chat_last_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the last_update timestamp of the chat associated with the message.
    -- OLD.chat_id is used for DELETE operations, NEW.chat_id for INSERT/UPDATE.
    -- For INSERT and UPDATE, NEW.chat_id will be available.
    -- For DELETE, if you wanted to update the chat based on a deleted message,
    -- you would use OLD.chat_id, but typically last_update is on new/modified messages.
    UPDATE chats
    SET last_update = NOW()
    WHERE chat_id = NEW.chat_id;

    RETURN NEW; -- For AFTER INSERT/UPDATE triggers, RETURN NEW is standard.
END;
$$;


ALTER FUNCTION public.update_chat_last_update() OWNER TO postgres;

--
-- Name: update_person(bigint, text, text, text, integer, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_person(p_person_id bigint, p_first_name text, p_middle_name text, p_last_name text, p_country_id integer, p_date_of_birth date, p_gender integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_first_name   VARCHAR(50);
    v_middle_name  VARCHAR(50);
    v_last_name    VARCHAR(50);

    rec RECORD;  -- To store existing person data
BEGIN
    -- Fetch existing person record
    SELECT first_name, middle_name, last_name, country_id, date_of_birth, gender
    INTO rec
    FROM people
    WHERE person_id = p_person_id;

    IF NOT FOUND THEN
        RETURN -1; -- Person not found
    END IF;

    -- Trim and clean input
    v_first_name := SUBSTRING(NULLIF(TRIM(p_first_name), ''), 1, 50);
    v_middle_name := SUBSTRING(NULLIF(TRIM(p_middle_name), ''), 1, 50);
    v_last_name := SUBSTRING(NULLIF(TRIM(p_last_name), ''), 1, 50);

    -- Perform the update
    BEGIN
        UPDATE people
        SET
            first_name    = COALESCE(v_first_name, rec.first_name),
            middle_name   = COALESCE(v_middle_name, rec.middle_name),
            last_name     = COALESCE(v_last_name, rec.last_name),
            country_id    = COALESCE(p_country_id, rec.country_id),
            date_of_birth = COALESCE(p_date_of_birth, rec.date_of_birth),
            gender        = COALESCE(p_gender, rec.gender),
            updated_at    = CURRENT_TIMESTAMP
        WHERE person_id = p_person_id;

        RETURN 1; -- Success

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Update failed: %', SQLERRM;
            RETURN -1;
    END;
END;
$$;


ALTER FUNCTION public.update_person(p_person_id bigint, p_first_name text, p_middle_name text, p_last_name text, p_country_id integer, p_date_of_birth date, p_gender integer) OWNER TO postgres;

--
-- Name: update_seen(uuid[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_seen(p_message_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE messages
    SET
        seen = TRUE
    WHERE
        message_id = ANY(p_message_ids)
        AND seen = FALSE; -- Only update if not already seen
END;
$$;


ALTER FUNCTION public.update_seen(p_message_ids uuid[]) OWNER TO postgres;

--
-- Name: update_seen(bigint, uuid[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_seen(p_user_id bigint, p_message_ids uuid[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE messages
    SET
        seen = TRUE
    WHERE
        message_id = ANY(p_message_ids)
        AND seen = FALSE AND sender_id <> p_user_id; -- Only update if not already seen
END;
$$;


ALTER FUNCTION public.update_seen(p_user_id bigint, p_message_ids uuid[]) OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: update_user(bigint, text, text, text, text, boolean, smallint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_user(p_user_id bigint, p_user_name text DEFAULT NULL::text, p_phone_number text DEFAULT NULL::text, p_email text DEFAULT NULL::text, p_password_hash text DEFAULT NULL::text, p_is_email_verified boolean DEFAULT NULL::boolean, p_status smallint DEFAULT NULL::smallint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    update_count INTEGER;
BEGIN
    -- Check if user exists
    IF NOT EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id) THEN RETURN -1; END IF;

    BEGIN
        UPDATE users 
        SET 
            username = COALESCE(TRIM(p_user_name), username),
            phone_number = COALESCE(NULLIF(TRIM(p_phone_number), ''), phone_number),
            email = COALESCE(NULLIF(LOWER(TRIM(p_email)), ''), email),
            password_hash = COALESCE(NULLIF(TRIM(p_password_hash), ''), password_hash),
            is_email_verified = COALESCE(p_is_email_verified, is_email_verified),
            status = COALESCE(p_status, status),
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = p_user_id;

        GET DIAGNOSTICS update_count = ROW_COUNT;
        
        IF update_count = 0 THEN
            RETURN -1; -- User not found (shouldn't happen due to earlier check)
        END IF;
        
        RETURN update_count; -- Success
        
    EXCEPTION
        WHEN foreign_key_violation THEN
        RETURN -1; -- Person ID not found
    WHEN unique_violation THEN
        RETURN -2; -- Username, email, or person_id already exists
    WHEN check_violation THEN
        RETURN -3; -- Username length, email format, or phone format problem
    WHEN OTHERS THEN
        RETURN 0; -- Unexpected exception
    END;

END;
$$;


ALTER FUNCTION public.update_user(p_user_id bigint, p_user_name text, p_phone_number text, p_email text, p_password_hash text, p_is_email_verified boolean, p_status smallint) OWNER TO postgres;

--
-- Name: user_active_companies_number(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_active_companies_number(p_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM company_admins ca
		JOIN companies c ON ca.company_id = c.company_id
        WHERE user_id = p_user_id
		AND role = 2 AND c.status < 3
    );
END;
$$;


ALTER FUNCTION public.user_active_companies_number(p_user_id bigint) OWNER TO postgres;

--
-- Name: user_companies_number(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_companies_number(p_user_id bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM company_admins
        WHERE user_id = p_user_id
		AND role = 2
    );
END;
$$;


ALTER FUNCTION public.user_companies_number(p_user_id bigint) OWNER TO postgres;

--
-- Name: user_companies_number(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_companies_number(p_user_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM user_owned_companies
        WHERE user_id = p_user_id
    );
END;
$$;


ALTER FUNCTION public.user_companies_number(p_user_id uuid) OWNER TO postgres;

--
-- Name: user_exists(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_exists(p_user_id bigint) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_user_exists SMALLINT;
BEGIN
	IF p_user_id IS NULL OR p_user_id < 0 THEN
	RETURN -1;
	END IF;
	
	SELECT 1 INTO v_user_exists FROM users u WHERE u.user_id = p_user_id;
	
	IF v_user_exists IS NOT NULL THEN RETURN v_user_exists;
	ELSE RETURN -1;
	END IF;
	
	EXCEPTION
    WHEN OTHERS THEN
        -- Log the error for debugging purposes if needed
        RAISE WARNING 'An exception occurred in user_exists: %', SQLERRM;
        RETURN -1; -- Or re-raise if you want the calling application to handle it
END;
$$;


ALTER FUNCTION public.user_exists(p_user_id bigint) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attachments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attachments (
    attachment_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    type smallint NOT NULL,
    url text NOT NULL,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.attachments OWNER TO postgres;

--
-- Name: certificate_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.certificate_types (
    certificate_type_id integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(1024)
);


ALTER TABLE public.certificate_types OWNER TO postgres;

--
-- Name: certificate_types_certificate_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.certificate_types_certificate_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.certificate_types_certificate_type_id_seq OWNER TO postgres;

--
-- Name: certificate_types_certificate_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.certificate_types_certificate_type_id_seq OWNED BY public.certificate_types.certificate_type_id;


--
-- Name: chat_participants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chat_participants (
    chat_participant_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    chat_id uuid NOT NULL,
    participant_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.chat_participants OWNER TO postgres;

--
-- Name: chats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chats (
    chat_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.chats OWNER TO postgres;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    message_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    chat_id uuid NOT NULL,
    sender_id bigint NOT NULL,
    content text,
    attachment_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_update timestamp with time zone DEFAULT now() NOT NULL,
    seen boolean DEFAULT false NOT NULL,
    CONSTRAINT valid_message CHECK ((((content IS NOT NULL) AND (TRIM(BOTH FROM content) <> ''::text)) OR (attachment_id <> NULL::uuid)))
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- Name: people; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.people (
    person_id bigint NOT NULL,
    first_name character varying(50) NOT NULL,
    middle_name character varying(50),
    last_name character varying(50) NOT NULL,
    country_id integer NOT NULL,
    date_of_birth date NOT NULL,
    gender smallint NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT age_validation CHECK (((date_of_birth <= (CURRENT_DATE - '13 years'::interval)) AND (date_of_birth >= (CURRENT_DATE - '120 years'::interval)))),
    CONSTRAINT name_validation CHECK (((length(TRIM(BOTH FROM first_name)) > 0) AND (length(TRIM(BOTH FROM first_name)) > 0))),
    CONSTRAINT people_date_of_birth_check CHECK ((date_of_birth <= (CURRENT_DATE - '13 years'::interval))),
    CONSTRAINT valid_gender CHECK (((gender >= 0) AND (gender <= 2)))
);


ALTER TABLE public.people OWNER TO postgres;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    profile_id bigint NOT NULL,
    user_id bigint NOT NULL,
    headline character varying(255) NOT NULL,
    bio character varying(2500),
    profile_pic_url character varying(255),
    banner_pic_url character varying(255),
    website character varying(255),
    github character varying(255),
    open_to_work boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT profiles_headline_check CHECK ((length(TRIM(BOTH FROM headline)) >= 10))
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id bigint NOT NULL,
    person_id bigint NOT NULL,
    username character varying(50) NOT NULL,
    phone_number character varying(20),
    email character varying(150) NOT NULL,
    is_email_verified boolean DEFAULT false,
    password_hash character varying(128) NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    last_login timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT email_format_check CHECK (((email)::text ~* '^[A-Za-z0-9_%+-]+(\.[A-Za-z0-9_%+-]+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,10}$'::text)),
    CONSTRAINT users_password_hash_check CHECK ((length(TRIM(BOTH FROM password_hash)) >= 64)),
    CONSTRAINT users_phone_number_check CHECK (((phone_number)::text ~* '^(\+?[0-9\s\-]{7,20})$'::text)),
    CONSTRAINT users_username_check CHECK ((length(TRIM(BOTH FROM username)) > 1))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: chat_summaries_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.chat_summaries_view AS
 SELECT c.chat_id,
    cp_main.participant_id AS user_id,
    cp_other.participant_id AS other_participant_id,
    u_other.username AS other_participant_username,
    p_other.profile_pic_url,
        CASE
            WHEN (pe_other.middle_name IS NOT NULL) THEN concat_ws(' '::text, pe_other.first_name, pe_other.middle_name, pe_other.last_name)
            ELSE concat_ws(' '::text, pe_other.first_name, pe_other.last_name)
        END AS other_participant_full_name,
        CASE
            WHEN (m_latest.attachment_id IS NOT NULL) THEN concat(u_other.username, ' sent an attachment')
            ELSE m_latest.content
        END AS last_message_content,
    m_latest.created_at AS last_message_created_at
   FROM ((((((public.chats c
     JOIN public.chat_participants cp_main ON ((c.chat_id = cp_main.chat_id)))
     LEFT JOIN LATERAL ( SELECT cp_inner.participant_id
           FROM public.chat_participants cp_inner
          WHERE ((cp_inner.chat_id = c.chat_id) AND (cp_inner.participant_id <> cp_main.participant_id))
         LIMIT 1) cp_other ON (true))
     LEFT JOIN public.users u_other ON ((cp_other.participant_id = u_other.user_id)))
     LEFT JOIN public.profiles p_other ON ((u_other.user_id = p_other.user_id)))
     LEFT JOIN public.people pe_other ON ((u_other.person_id = pe_other.person_id)))
     LEFT JOIN LATERAL ( SELECT m_inner.content,
            m_inner.attachment_id,
            m_inner.created_at
           FROM public.messages m_inner
          WHERE (m_inner.chat_id = c.chat_id)
          ORDER BY m_inner.created_at DESC
         LIMIT 1) m_latest ON (true))
  WHERE (( SELECT count(*) AS count
           FROM public.chat_participants cp_count
          WHERE (cp_count.chat_id = c.chat_id)) = 2);


ALTER VIEW public.chat_summaries_view OWNER TO postgres;

--
-- Name: companies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.companies (
    company_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(255) NOT NULL,
    industry_id bigint NOT NULL,
    size smallint NOT NULL,
    founded_date date NOT NULL,
    website public.url_type,
    contact_email character varying(150) NOT NULL,
    location_id smallint NOT NULL,
    description text,
    logo_url public.url_type,
    banner_url public.url_type,
    remote_status smallint DEFAULT 0 NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_company_founded_date CHECK ((founded_date >= '1750-01-01'::date)),
    CONSTRAINT companies_founded_date_check CHECK ((founded_date < CURRENT_DATE)),
    CONSTRAINT companies_name_check CHECK ((TRIM(BOTH FROM name) <> ''::text)),
    CONSTRAINT companies_remote_status_check CHECK (((remote_status >= 0) AND (remote_status <= 2))),
    CONSTRAINT companies_size_check CHECK (((size >= 1) AND (size <= 8))),
    CONSTRAINT companies_status_check CHECK ((status = ANY (ARRAY[0, 1, 2]))),
    CONSTRAINT companies_website_check CHECK (((website IS NULL) OR (TRIM(BOTH FROM website) <> ''::text))),
    CONSTRAINT company_status_check CHECK (((status >= 0) AND (status <= 5))),
    CONSTRAINT valid_email CHECK (((contact_email)::text ~* '^[A-Za-z0-9_%+-]+(\.[A-Za-z0-9_%+-]+)*@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,10}$'::text))
);


ALTER TABLE public.companies OWNER TO postgres;

--
-- Name: TABLE companies; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.companies IS 'Stores information about various companies.';


--
-- Name: COLUMN companies.size; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.companies.size IS 'Size of the company (1: 1-10 |2: 11-50 |3: 51-200 |4: 201-500 |5: 501-1,000 |6: 1,001-5,000 |7: 5,001-10,000 |8: 10,001+).';


--
-- Name: COLUMN companies.remote_status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.companies.remote_status IS 'Remote work status of the company (0=On-site, 1=Hybrid, 2=Fully Remote).';


--
-- Name: COLUMN companies.status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.companies.status IS 'Company status:
0 = unofficial (user email verified only),
1 = official (fully approved),
2 = semi-official (approved, awaiting final status),
3 = pending application (e.g. second company),
4 = rejected,
5 = suspended.';


--
-- Name: company_admins; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.company_admins (
    company_admin_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    company_id uuid NOT NULL,
    user_id bigint NOT NULL,
    role smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT company_admins_role_check CHECK (((role >= 0) AND (role <= 2)))
);


ALTER TABLE public.company_admins OWNER TO postgres;

--
-- Name: TABLE company_admins; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.company_admins IS 'Maps users to companies with admin roles.';


--
-- Name: COLUMN company_admins.role; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.company_admins.role IS '0 = none, 1 = admin, 2 = owner';


--
-- Name: connections; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.connections (
    connection_id bigint NOT NULL,
    user_id bigint NOT NULL,
    target_user_id bigint NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT connections_check CHECK ((user_id <> target_user_id))
);


ALTER TABLE public.connections OWNER TO postgres;

--
-- Name: connections_connection_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.connections_connection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.connections_connection_id_seq OWNER TO postgres;

--
-- Name: connections_connection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.connections_connection_id_seq OWNED BY public.connections.connection_id;


--
-- Name: countries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.countries (
    country_id integer NOT NULL,
    name character varying(128) NOT NULL
);


ALTER TABLE public.countries OWNER TO postgres;

--
-- Name: countries_country_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.countries_country_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.countries_country_id_seq OWNER TO postgres;

--
-- Name: countries_country_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.countries_country_id_seq OWNED BY public.countries.country_id;


--
-- Name: educations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.educations (
    education_id bigint NOT NULL,
    user_id bigint NOT NULL,
    education_title character varying(255) NOT NULL,
    institution_name character varying(255) NOT NULL,
    institution_type_id integer,
    learning_mode_id integer NOT NULL,
    certificate_type_id integer NOT NULL,
    industry_id bigint NOT NULL,
    more_info text,
    certificate_link character varying(255),
    start_date date NOT NULL,
    end_date date,
    ongoing boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_end_date CHECK (((end_date IS NULL) OR (end_date > start_date)))
);


ALTER TABLE public.educations OWNER TO postgres;

--
-- Name: industries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.industries (
    industry_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(1024)
);


ALTER TABLE public.industries OWNER TO postgres;

--
-- Name: institution_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.institution_types (
    institution_type_id integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(1024)
);


ALTER TABLE public.institution_types OWNER TO postgres;

--
-- Name: learning_modes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.learning_modes (
    learning_mode_id integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(1024)
);


ALTER TABLE public.learning_modes OWNER TO postgres;

--
-- Name: edu_user_details; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW public.edu_user_details AS
 SELECT e.education_id,
    e.user_id,
    u.username,
    e.education_title,
    e.institution_name,
    it.name AS institution_type,
    it.description AS institution_description,
    lm.name AS learning_mode,
    lm.description AS learning_mode_description,
    ct.name AS certificate_type,
    ct.description AS certificate_type_description,
    i.name AS industry,
    i.description AS industry_description,
    e.start_date,
    e.end_date,
    e.ongoing,
    e.more_info,
    e.certificate_link
   FROM (((((public.educations e
     JOIN public.users u ON ((e.user_id = u.user_id)))
     LEFT JOIN public.institution_types it ON ((e.institution_type_id = it.institution_type_id)))
     JOIN public.learning_modes lm ON ((e.learning_mode_id = lm.learning_mode_id)))
     JOIN public.certificate_types ct ON ((e.certificate_type_id = ct.certificate_type_id)))
     JOIN public.industries i ON ((e.industry_id = i.industry_id)))
  WITH NO DATA;


ALTER MATERIALIZED VIEW public.edu_user_details OWNER TO postgres;

--
-- Name: educations_education_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.educations_education_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.educations_education_id_seq OWNER TO postgres;

--
-- Name: educations_education_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.educations_education_id_seq OWNED BY public.educations.education_id;


--
-- Name: follows; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.follows (
    follow_id bigint NOT NULL,
    follower_id bigint NOT NULL,
    followee_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT no_follow_self CHECK ((follower_id <> followee_id))
);


ALTER TABLE public.follows OWNER TO postgres;

--
-- Name: follows_follow_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.follows_follow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.follows_follow_id_seq OWNER TO postgres;

--
-- Name: follows_follow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.follows_follow_id_seq OWNED BY public.follows.follow_id;


--
-- Name: get_messages_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.get_messages_view AS
 SELECT m.message_id,
    m.chat_id,
    m.sender_id,
    m.content,
    a.url,
        CASE
            WHEN (a.type = 1) THEN 'file'::text
            WHEN (a.type = 2) THEN 'picture'::text
            WHEN (a.type = 3) THEN 'video'::text
            ELSE 'unknown'::text
        END AS file_type,
    m.created_at,
    m.last_update,
    m.seen
   FROM (public.messages m
     JOIN public.attachments a ON ((m.attachment_id = a.attachment_id)))
  ORDER BY m.created_at;


ALTER VIEW public.get_messages_view OWNER TO postgres;

--
-- Name: industries_industry_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.industries_industry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.industries_industry_id_seq OWNER TO postgres;

--
-- Name: industries_industry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.industries_industry_id_seq OWNED BY public.industries.industry_id;


--
-- Name: institution_types_institution_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.institution_types_institution_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.institution_types_institution_type_id_seq OWNER TO postgres;

--
-- Name: institution_types_institution_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.institution_types_institution_type_id_seq OWNED BY public.institution_types.institution_type_id;


--
-- Name: learning_modes_learning_mode_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.learning_modes_learning_mode_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.learning_modes_learning_mode_id_seq OWNER TO postgres;

--
-- Name: learning_modes_learning_mode_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.learning_modes_learning_mode_id_seq OWNED BY public.learning_modes.learning_mode_id;


--
-- Name: people_person_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.people_person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.people_person_id_seq OWNER TO postgres;

--
-- Name: people_person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.people_person_id_seq OWNED BY public.people.person_id;


--
-- Name: proficiency_levels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proficiency_levels (
    proficiency_id integer NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(1024)
);


ALTER TABLE public.proficiency_levels OWNER TO postgres;

--
-- Name: proficiency_levels_proficiency_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proficiency_levels_proficiency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proficiency_levels_proficiency_id_seq OWNER TO postgres;

--
-- Name: proficiency_levels_proficiency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proficiency_levels_proficiency_id_seq OWNED BY public.proficiency_levels.proficiency_id;


--
-- Name: profiles_profile_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.profiles_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.profiles_profile_id_seq OWNER TO postgres;

--
-- Name: profiles_profile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.profiles_profile_id_seq OWNED BY public.profiles.profile_id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    role_id bigint NOT NULL,
    role_title character varying(255) NOT NULL,
    description character varying(1024),
    industry_id bigint
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: roles_role_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roles_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_role_id_seq OWNER TO postgres;

--
-- Name: roles_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_role_id_seq OWNED BY public.roles.role_id;


--
-- Name: skills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.skills (
    skill_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(1024),
    industry_id bigint
);


ALTER TABLE public.skills OWNER TO postgres;

--
-- Name: skills_skill_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.skills_skill_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.skills_skill_id_seq OWNER TO postgres;

--
-- Name: skills_skill_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.skills_skill_id_seq OWNED BY public.skills.skill_id;


--
-- Name: user_owned_companies_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_owned_companies_view AS
 SELECT ca.user_id,
    ca.company_id,
    c.name,
    c.website,
    c.status,
    c.logo_url
   FROM (public.company_admins ca
     JOIN public.companies c ON ((ca.company_id = c.company_id)))
  WHERE (ca.role = 2);


ALTER VIEW public.user_owned_companies_view OWNER TO postgres;

--
-- Name: user_profile_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_profile_view AS
 SELECT u.username,
    u.phone_number,
    u.email,
    concat(p.first_name,
        CASE
            WHEN ((p.middle_name IS NOT NULL) AND (TRIM(BOTH FROM p.middle_name) <> ''::text)) THEN ((' '::text || (p.middle_name)::text) || ' '::text)
            ELSE ' '::text
        END, p.last_name) AS full_name,
    c.name AS country_name,
    p.date_of_birth,
        CASE
            WHEN (p.gender = 1) THEN 'Male'::text
            WHEN (p.gender = 2) THEN 'Female'::text
            ELSE 'Uknown'::text
        END AS "case",
    pr.headline,
    pr.bio,
    pr.profile_pic_url,
    pr.banner_pic_url,
    pr.website,
    pr.github,
    pr.open_to_work,
    u.status AS user_status
   FROM (((public.users u
     JOIN public.people p USING (person_id))
     JOIN public.countries c USING (country_id))
     LEFT JOIN public.profiles pr USING (user_id));


ALTER VIEW public.user_profile_view OWNER TO postgres;

--
-- Name: user_skills; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_skills (
    user_skill_id bigint NOT NULL,
    user_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    profi_level integer NOT NULL,
    years_of_exp smallint NOT NULL,
    added_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT user_skills_years_of_exp_check CHECK (((years_of_exp >= 0) AND (years_of_exp <= 100)))
);


ALTER TABLE public.user_skills OWNER TO postgres;

--
-- Name: user_skills_user_skill_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_skills_user_skill_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_skills_user_skill_id_seq OWNER TO postgres;

--
-- Name: user_skills_user_skill_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_skills_user_skill_id_seq OWNED BY public.user_skills.user_skill_id;


--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: certificate_types certificate_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificate_types ALTER COLUMN certificate_type_id SET DEFAULT nextval('public.certificate_types_certificate_type_id_seq'::regclass);


--
-- Name: connections connection_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections ALTER COLUMN connection_id SET DEFAULT nextval('public.connections_connection_id_seq'::regclass);


--
-- Name: countries country_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries ALTER COLUMN country_id SET DEFAULT nextval('public.countries_country_id_seq'::regclass);


--
-- Name: educations education_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.educations ALTER COLUMN education_id SET DEFAULT nextval('public.educations_education_id_seq'::regclass);


--
-- Name: follows follow_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows ALTER COLUMN follow_id SET DEFAULT nextval('public.follows_follow_id_seq'::regclass);


--
-- Name: industries industry_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.industries ALTER COLUMN industry_id SET DEFAULT nextval('public.industries_industry_id_seq'::regclass);


--
-- Name: institution_types institution_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institution_types ALTER COLUMN institution_type_id SET DEFAULT nextval('public.institution_types_institution_type_id_seq'::regclass);


--
-- Name: learning_modes learning_mode_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.learning_modes ALTER COLUMN learning_mode_id SET DEFAULT nextval('public.learning_modes_learning_mode_id_seq'::regclass);


--
-- Name: people person_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.people ALTER COLUMN person_id SET DEFAULT nextval('public.people_person_id_seq'::regclass);


--
-- Name: proficiency_levels proficiency_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proficiency_levels ALTER COLUMN proficiency_id SET DEFAULT nextval('public.proficiency_levels_proficiency_id_seq'::regclass);


--
-- Name: profiles profile_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles ALTER COLUMN profile_id SET DEFAULT nextval('public.profiles_profile_id_seq'::regclass);


--
-- Name: roles role_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles ALTER COLUMN role_id SET DEFAULT nextval('public.roles_role_id_seq'::regclass);


--
-- Name: skills skill_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.skills ALTER COLUMN skill_id SET DEFAULT nextval('public.skills_skill_id_seq'::regclass);


--
-- Name: user_skills user_skill_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_skills ALTER COLUMN user_skill_id SET DEFAULT nextval('public.user_skills_user_skill_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Data for Name: attachments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.attachments (attachment_id, type, url, uploaded_at, last_update) FROM stdin;
\.


--
-- Data for Name: certificate_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.certificate_types (certificate_type_id, name, description) FROM stdin;
1	General Education	A broad educational program typically covering subjects like math, science, language, and humanities, meant to provide foundational knowledge.
2	Professional Certification	A credential issued by a professional organization or regulatory body, verifying expertise in a specific field or profession.
3	Diploma Program	A specialized program focused on a specific area of study, often shorter than a degree program, and leading to a diploma.
4	Certificate Program	A program designed to provide specific skills or knowledge in a particular area, typically requiring less time than a full degree.
5	Apprenticeship	A formal, structured work-based learning program that combines hands-on work with classroom instruction, usually in skilled trades or technical fields.
6	Short Courses / Workshops	Short-duration courses that focus on specific skills or knowledge, often for professional development or personal enrichment.
7	Language School	A school focused on teaching one or more languages, typically for non-native speakers aiming to improve fluency in a new language.
\.


--
-- Data for Name: chat_participants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chat_participants (chat_participant_id, chat_id, participant_id, created_at, last_update) FROM stdin;
\.


--
-- Data for Name: chats; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chats (chat_id, created_at, last_update) FROM stdin;
\.


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.companies (company_id, name, industry_id, size, founded_date, website, contact_email, location_id, description, logo_url, banner_url, remote_status, status, created_at, updated_at) FROM stdin;
cdd107ae-4f52-4598-8cf7-cceb88b2b2dd	TechNova Solutions	18	4	2005-06-15	https://technova.com	info@technova.com	33	Cloud software services.	https://cdn.technova.com/logo.png	https://cdn.technova.com/banner.jpg	2	1	2025-06-29 19:51:18.245094+01	2025-06-29 19:51:18.245094+01
5939f0a8-5ac5-45ec-96c0-34fb06705442	Green Earth Org	11	2	1980-03-12	\N	contact@greenearth.org	145	Sustainability consultants.	\N	\N	1	1	2025-06-29 19:51:18.245094+01	2025-06-29 19:51:18.245094+01
6988043a-6188-479c-9edb-86c2cd79f6e7	Someone Inc.	5	2	2005-03-14	https://something.com	someone@something.com	34	\N	\N	\N	0	0	2025-06-29 22:23:51.128093+01	2025-06-29 22:23:51.128093+01
\.


--
-- Data for Name: company_admins; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.company_admins (company_admin_id, company_id, user_id, role, created_at, updated_at) FROM stdin;
bb447e58-3df6-491a-b9e6-f2bc3d988e5c	6988043a-6188-479c-9edb-86c2cd79f6e7	3	2	2025-06-29 22:23:51.128093+01	2025-06-29 22:23:51.128093+01
\.


--
-- Data for Name: connections; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.connections (connection_id, user_id, target_user_id, status, created_at, updated_at) FROM stdin;
3	1	3	1	2025-06-27 20:26:10.411482+01	2025-06-27 20:27:07.333749+01
\.


--
-- Data for Name: countries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.countries (country_id, name) FROM stdin;
1	Afghanistan
2	Albania
3	Algeria
4	Andorra
5	Angola
6	Antigua and Barbuda
7	Argentina
8	Armenia
9	Australia
10	Austria
11	Azerbaijan
12	Bahamas
13	Bahrain
14	Bangladesh
15	Barbados
16	Belarus
17	Belgium
18	Belize
19	Benin
20	Bhutan
21	Bolivia
22	Bosnia and Herzegovina
23	Botswana
24	Brazil
25	Brunei
26	Bulgaria
27	Burkina Faso
28	Burundi
29	Cabo Verde
30	Cambodia
31	Cameroon
32	Canada
33	Central African Republic
34	Chad
35	Chile
36	China
37	Colombia
38	Comoros
39	Congo (Brazzaville)
40	Congo (Kinshasa)
41	Costa Rica
42	Croatia
43	Cuba
44	Cyprus
45	Czechia
46	Denmark
47	Djibouti
48	Dominica
49	Dominican Republic
50	Ecuador
51	Egypt
52	El Salvador
53	Equatorial Guinea
54	Eritrea
55	Estonia
56	Eswatini
57	Ethiopia
58	Fiji
59	Finland
60	France
61	Gabon
62	Gambia
63	Georgia
64	Germany
65	Ghana
66	Greece
67	Grenada
68	Guatemala
69	Guinea
70	Guinea-Bissau
71	Guyana
72	Haiti
73	Honduras
74	Hungary
75	Iceland
76	India
77	Indonesia
78	Iran
79	Iraq
80	Ireland
81	Palestine
82	Italy
83	Jamaica
84	Japan
85	Jordan
86	Kazakhstan
87	Kenya
88	Kiribati
89	Kuwait
90	Kyrgyzstan
91	Laos
92	Latvia
93	Lebanon
94	Lesotho
95	Liberia
96	Libya
97	Liechtenstein
98	Lithuania
99	Luxembourg
100	Madagascar
101	Malawi
102	Malaysia
103	Maldives
104	Mali
105	Malta
106	Marshall Islands
107	Mauritania
108	Mauritius
109	Mexico
110	Micronesia
111	Moldova
112	Monaco
113	Mongolia
114	Montenegro
115	Morocco
116	Mozambique
117	Myanmar
118	Namibia
119	Nauru
120	Nepal
121	Netherlands
122	New Zealand
123	Nicaragua
124	Niger
125	Nigeria
126	North Korea
127	North Macedonia
128	Norway
129	Oman
130	Pakistan
131	Palau
132	Panama
133	Papua New Guinea
134	Paraguay
135	Peru
136	Philippines
137	Poland
138	Portugal
139	Qatar
140	Romania
141	Russia
142	Rwanda
143	Saint Kitts and Nevis
144	Saint Lucia
145	Saint Vincent and the Grenadines
146	Samoa
147	San Marino
148	Sao Tome and Principe
149	Saudi Arabia
150	Senegal
151	Serbia
152	Seychelles
153	Sierra Leone
154	Singapore
155	Slovakia
156	Slovenia
157	Solomon Islands
158	Somalia
159	South Africa
160	South Korea
161	South Sudan
162	Spain
163	Sri Lanka
164	Sudan
165	Suriname
166	Sweden
167	Switzerland
168	Syria
169	Taiwan
170	Tajikistan
171	Tanzania
172	Thailand
173	Timor-Leste
174	Togo
175	Tonga
176	Trinidad and Tobago
177	Tunisia
178	Turkey
179	Turkmenistan
180	Tuvalu
181	Uganda
182	Ukraine
183	United Arab Emirates
184	United Kingdom
185	United States
186	Uruguay
187	Uzbekistan
188	Vanuatu
189	Vatican City
190	Venezuela
191	Vietnam
192	Yemen
193	Zambia
194	Zimbabwe
\.


--
-- Data for Name: educations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.educations (education_id, user_id, education_title, institution_name, institution_type_id, learning_mode_id, certificate_type_id, industry_id, more_info, certificate_link, start_date, end_date, ongoing, created_at, updated_at) FROM stdin;
1	1	Front-end development	alzero-web-school	\N	3	6	18	made it in 2023 jun, learning took about 3 months...etc	\N	2023-06-17	2023-08-01	t	2025-06-12 08:53:30.365207	2025-06-12 08:53:30.365207
\.


--
-- Data for Name: follows; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.follows (follow_id, follower_id, followee_id, created_at) FROM stdin;
13	1	3	2025-06-26 09:39:50.43304
15	3	1	2025-06-26 09:56:42.978492
\.


--
-- Data for Name: industries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.industries (industry_id, name, description) FROM stdin;
1	Aerospace	The aerospace industry researches, develops, manufactures, operates, and maintains aircraft, spacecraft, and missiles.
2	Agriculture	The agriculture industry cultivates plants, lands, and animals for food, drinks, and other essential products.
3	Automotive	The automotive industry designs, develops, manufactures, markets, and sells motor vehicles.
4	Biotechnology	The biotechnology industry applies biological processes to develop products and technologies, especially in healthcare and agriculture.
5	Chemicals	The chemicals industry produces industrial chemicals, polymers, and specialty chemicals.
6	Construction	The construction industry plans, designs, constructs, and maintains buildings and infrastructure.
7	Consulting	The consulting industry provides expert advice to organizations on various matters, including management, strategy, and operations.
8	Education	The education industry encompasses academic institutions and services focused on teaching and learning.
9	Energy	The energy industry is involved in the production and distribution of energy, including fossil fuels, nuclear, and renewables.
10	Entertainment	The entertainment industry provides recreation, leisure, and amusement through various media like film, music, and gaming.
11	Environmental Services	The environmental services industry offers solutions for waste management, pollution control, and sustainability.
12	Fashion	The fashion industry designs, manufactures, markets, and sells clothing, footwear, and accessories.
13	Financial Services	The financial services industry manages money, including banking, investments, insurance, and real estate services.
14	Food and Beverage	The food and beverage industry processes, prepares, packages, and distributes food and drink products.
15	Government and Public Sector	The government and public sector encompasses governmental bodies and public services, including administration, defense, and public safety.
16	Healthcare	The healthcare industry provides medical and wellness services, including diagnosis, treatment, and preventive care.
17	Hospitality	The hospitality industry offers services related to lodging, food, and tourism, providing comfort and enjoyment to guests.
18	Information Technology	The information technology (IT) industry specializes in the management, processing, and dissemination of information, encompassing software, hardware, and services.
19	Insurance	The insurance industry provides financial protection against various risks, offering policies for health, property, and life.
20	Legal Services	The legal services industry provides advice, representation, and assistance in legal matters.
21	Manufacturing	The manufacturing industry involves the production of goods and products from raw materials or components.
22	Media	The media industry produces and disseminates news, information, and entertainment through various platforms like television, radio, and digital channels.
23	Mining	The mining industry extracts valuable minerals and other geological materials from the Earth.
24	Pharmaceuticals	The pharmaceutical industry researches, develops, manufactures, and sells medicines and drugs.
25	Real Estate	The real estate industry deals with the buying, selling, renting, and management of property.
26	Retail	The retail industry sells goods directly to consumers for their personal use.
27	Telecommunications	The telecommunications industry provides services, infrastructure, and equipment for communication over distances.
28	Tourism	The tourism industry caters to travelers, offering services like transportation, accommodation, and attractions.
29	Transportation and Logistics	The transportation and logistics industry plans, implements, and controls the efficient flow and storage of goods and services.
30	Utilities	The utilities industry provides essential public services such as electricity, gas, water, and sanitation.
\.


--
-- Data for Name: institution_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.institution_types (institution_type_id, name, description) FROM stdin;
1	Public School	An educational institution that is funded and operated by government agencies, offering free education to residents of the area.
2	Private School	An educational institution funded and operated privately, typically requiring tuition for enrollment.
3	Charter School	A publicly funded but independently operated school that has more flexibility in curriculum and management than traditional public schools.
4	Community College	A two-year institution offering associate degrees, certificates, and training programs, typically for local residents.
5	University	A higher education institution that offers both undergraduate and graduate degrees, often providing a wide range of academic disciplines.
6	Technical/Vocational Institute	An institution focused on providing specialized training in specific trades, skills, or technical fields.
7	Online University	An accredited higher education institution that offers degree programs primarily or entirely online.
8	Open University	A university that offers open admissions and allows students of all backgrounds to pursue higher education, often without strict entrance requirements.
\.


--
-- Data for Name: learning_modes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.learning_modes (learning_mode_id, name, description) FROM stdin;
1	Full-time	A learning mode where students attend classes full-time, typically requiring a commitment of 30+ hours per week.
2	Part-time	A learning mode where students attend classes part-time, balancing education with work or other responsibilities.
3	Online / E-learning	Education delivered through the internet, allowing students to learn remotely at their own pace or according to a set schedule.
4	Hybrid / Blended Learning	A combination of both in-person and online learning, allowing students flexibility in their learning environment.
5	Evening / Weekend Classes	Courses held during evenings or weekends to accommodate students who work during traditional business hours.
6	Self-paced	An education format where students can progress through the coursework at their own pace, without fixed deadlines or class schedules.
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (message_id, chat_id, sender_id, content, attachment_id, created_at, last_update, seen) FROM stdin;
\.


--
-- Data for Name: people; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.people (person_id, first_name, middle_name, last_name, country_id, date_of_birth, gender, created_at, updated_at) FROM stdin;
1	mohammed	sami	yousef	3	1998-01-01	1	2025-06-05 07:29:10.150337	2025-06-05 07:29:10.150337
9	dounia	marry	ali	6	2001-05-01	2	2025-06-06 07:16:04.168788	2025-06-06 07:16:04.168788
4	houd	rami	ali	22	1999-12-04	1	2025-06-05 09:15:39.071303	2025-06-06 13:04:49.479647
\.


--
-- Data for Name: proficiency_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proficiency_levels (proficiency_id, name, description) FROM stdin;
1	Entry Level	Just starting with the skill; requires supervision.
2	Intermediate	Able to perform basic tasks independently with some guidance.
3	Associated	Contributes to projects and supports more experienced team members.
4	Junior	Has basic experience; performs routine tasks with minimal help.
5	Mid-Level	Solid experience; works independently and mentors juniors.
6	Senior	Deep expertise; leads projects and makes strategic decisions.
7	Advanced	Highly specialized knowledge; recognized as an internal expert.
8	Expert	Top-tier mastery; often consulted as a subject matter authority.
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.profiles (profile_id, user_id, headline, bio, profile_pic_url, banner_pic_url, website, github, open_to_work, created_at, updated_at) FROM stdin;
1	1	SOFTWARE ENGNEER AT GOOGLE	hi, my name is mohammed and I am a software engneer at google	\N	\N	\N	\N	f	2025-06-08 07:41:25.9367	2025-06-08 07:41:25.9367
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (role_id, role_title, description, industry_id) FROM stdin;
1	Aerospace Engineer	Designs, develops, and tests aircraft, spacecraft, and related systems.	1
2	Aircraft Mechanic	Inspects, maintains, and repairs aircraft to ensure they are safe and operational.	1
3	Farmer	Manages and cultivates land and/or raises livestock to produce food and other agricultural products.	2
4	Agronomist	Specializes in soil management and crop production, providing advice to farmers.	2
5	Automotive Designer	Creates the aesthetic and ergonomic design of vehicles.	3
6	Automotive Technician	Diagnoses, repairs, and maintains automobiles.	3
7	Biomedical Scientist	Conducts research and experiments in biological and medical sciences to understand diseases and develop treatments.	4
8	Research Associate	Assists senior researchers in conducting experiments, collecting data, and preparing reports.	4
9	Chemical Engineer	Designs and develops chemical processes and equipment to transform raw materials into various products.	5
10	Laboratory Technician	Performs laboratory tests, experiments, and analyses under the supervision of scientists.	5
11	Civil Engineer	Designs, constructs, and maintains infrastructure projects such as roads, bridges, and buildings.	6
12	Construction Manager	Oversees and directs construction projects from conception to completion.	6
13	Management Consultant	Advises organizations on how to improve their efficiency and solve business problems.	7
14	Business Analyst	Analyzes an organization's operations and identifies areas for improvement and technological solutions.	7
15	Teacher	Educates students in various subjects, developing lesson plans and assessing progress.	8
16	University Professor	Conducts research, teaches at the university level, and mentors students.	8
17	Energy Analyst	Evaluates energy markets, consumption trends, and policy impacts.	9
18	Power Plant Operator	Monitors and controls the equipment that generates electricity in a power plant.	9
19	Film Director	Oversees the creative aspects of a film production, guiding actors and technical crew.	10
20	Animator	Creates animated sequences for films, television, video games, or other media.	10
21	Environmental Scientist	Conducts research to identify and abate sources of pollution and protect the environment.	11
22	Waste Treatment Specialist	Operates and maintains systems for treating and disposing of waste materials.	11
23	Fashion Designer	Creates original clothing, accessories, and footwear designs.	12
24	Merchandiser	Plans and develops product assortments, displays, and pricing strategies for retail.	12
25	Financial Advisor	Provides financial guidance and investment strategies to individuals and organizations.	13
26	Accountant	Prepares and examines financial records, ensuring accuracy and compliance with laws and regulations.	13
27	Chef	Prepares and cooks food in professional kitchens, often overseeing kitchen staff and menu development.	14
28	Food Scientist	Researches and develops new food products, improves existing ones, and ensures food safety and quality.	14
29	Policy Advisor	Provides expert advice to government officials on policy development and implementation.	15
30	Urban Planner	Develops plans for the use of land and physical facilities in urban and suburban areas.	15
31	Doctor	Diagnoses and treats illnesses and injuries, providing medical care to patients.	16
32	Nurse	Provides direct patient care, administers medications, and supports doctors.	16
33	Hotel Manager	Manages the daily operations of a hotel, ensuring guest satisfaction and efficient service.	17
34	Concierge	Assists hotel guests with various services, reservations, and information.	17
35	Software Engineer	Applies engineering principles to design, develop, maintain, and evaluate computer software.	18
36	Data Scientist	Analyzes complex data to extract insights and knowledge, often using statistical and machine learning methods.	18
37	Insurance Agent	Sells insurance policies to individuals and businesses, explaining coverage options.	19
38	Actuary	Analyzes financial risks using mathematics, statistics, and financial theory, primarily in insurance and pension industries.	19
39	Lawyer	Practices law, advising and representing clients in legal matters.	20
40	Paralegal	Assists lawyers with legal research, document preparation, and case management.	20
41	Production Manager	Oversees the manufacturing process to ensure efficient production and quality control.	21
42	Industrial Engineer	Optimizes complex processes, systems, or organizations, primarily in manufacturing.	21
43	Journalist	Researches, writes, and reports news stories for various media outlets.	22
44	Content Editor	Reviews and refines written or multimedia content for clarity, accuracy, and style.	22
45	Geologist	Studies the Earth's physical structure, substance, and processes.	23
46	Mining Engineer	Designs, develops, and manages the operations of mines.	23
47	Pharmacist	Dispenses prescription medications and provides advice on their safe and effective use.	24
48	Clinical Research Coordinator	Manages the daily operations of clinical trials, ensuring compliance with protocols and regulations.	24
49	Real Estate Agent	Facilitates the buying, selling, and renting of properties for clients.	25
50	Property Manager	Oversees the daily operations of real estate properties, including maintenance, tenant relations, and financial management.	25
51	Retail Manager	Manages the operations of a retail store, including sales, staff, and inventory.	26
52	Sales Associate	Assists customers with purchases and provides product information in a retail setting.	26
53	Telecommunications Engineer	Designs, installs, and maintains telecommunications equipment and systems.	27
54	Network Administrator	Manages and maintains computer networks, ensuring their smooth operation and security.	27
55	Tour Operator	Organizes and sells package tours, including transportation, accommodation, and activities.	28
56	Travel Agent	Assists clients in planning and booking travel arrangements, including flights, hotels, and tours.	28
57	Logistics Manager	Oversees the entire supply chain, ensuring efficient storage and transportation of goods.	29
58	Truck Driver	Operates heavy trucks to transport goods over short or long distances.	29
59	Utility Technician	Installs, maintains, and repairs equipment and infrastructure for utilities such as electricity or water.	30
60	Water Quality Specialist	Tests and monitors water quality, ensuring it meets safety and regulatory standards.	30
61	Cloud Architect	Designs and builds cloud computing environments and strategies.	18
62	Cybersecurity Analyst	Protects computer systems and networks from cyber threats and attacks.	18
63	DevOps Engineer	Works to bridge the gap between software development and IT operations, automating and streamlining processes.	18
64	Database Administrator	Manages and maintains databases, ensuring their performance, security, and availability.	18
65	Front-end Developer	Builds the user-facing side of websites and web applications, focusing on visual design and user interaction.	18
66	Back-end Developer	Develops the server-side logic and databases that power websites and applications.	18
67	Mobile Developer	Creates applications specifically for mobile devices, such as smartphones and tablets.	18
68	Machine Learning Engineer	Designs, builds, and deploys machine learning models and systems.	18
69	Big Data Engineer	Designs, constructs, installs, and maintains large-scale data processing systems.	18
70	UI/UX Designer	Focuses on creating intuitive, efficient, and enjoyable user interfaces and experiences for software and web applications.	18
71	IT Project Manager	Plans, executes, and closes IT projects, ensuring they are delivered on time and within budget.	18
72	Technical Support Specialist	Provides technical assistance and problem-solving help to users of computer systems and software.	18
73	Systems Administrator	Maintains and operates computer systems, servers, and networks.	18
74	Business Intelligence Developer	Designs and develops data warehousing and reporting solutions to support business decision-making.	18
75	Network Architect	Designs and implements complex computer networks, ensuring optimal performance and security.	18
76	Quality Assurance Engineer	Tests software and systems to ensure they meet quality standards and are free of defects.	18
77	Scrum Master	Facilitates agile development processes, ensuring the team adheres to Scrum principles and practices.	18
78	Solutions Architect	Designs and integrates complex software solutions to meet business requirements.	18
79	Web Developer	Builds and maintains websites, often specializing in either front-end or back-end development.	18
80	Full-stack Developer	Works on both the front-end and back-end of web applications, handling all aspects of development.	18
81	Site Reliability Engineer	Focuses on the reliability, availability, and performance of large-scale systems and services.	18
82	AI Research Scientist	Conducts research and develops new theories, algorithms, and models in the field of Artificial Intelligence.	18
\.


--
-- Data for Name: skills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.skills (skill_id, name, description, industry_id) FROM stdin;
1	CAD Design	Ability to create two-dimensional and three-dimensional designs and models using computer-aided design software.	1
2	Aircraft Maintenance	Performing inspections, repairs, and upkeep on aircraft systems and components.	1
3	Crop Management	Planning and overseeing agricultural practices to optimize crop yield and quality.	2
4	Livestock Care	Providing health, nutrition, and welfare management for farm animals.	2
5	Engine Diagnostics	Identifying and troubleshooting mechanical and electrical issues in vehicle engines.	3
6	Vehicle Assembly	Putting together vehicle components and systems on a production line.	3
7	Lab Research	Conducting scientific experiments and investigations in a laboratory setting.	4
8	Gene Sequencing	Determining the order of nucleotides in a DNA or RNA molecule.	4
9	Chemical Synthesis	Creating new chemical compounds through controlled reactions.	5
10	Quality Control	Ensuring products or services meet specified standards and requirements.	5
11	Project Management	Planning, executing, and closing projects effectively and efficiently.	6
12	Structural Engineering	Designing and analyzing the structural integrity of buildings and other constructions.	6
13	Strategic Planning	Developing long-term objectives and plans for an organization.	7
14	Data Analysis	Inspecting, cleaning, transforming, and modeling data to discover useful information and support decision-making.	7
15	Curriculum Development	Designing and organizing educational content and learning experiences.	8
16	Teaching	Instructing and guiding students in academic subjects or practical skills.	8
17	Renewable Energy Systems	Knowledge of designing, installing, and maintaining solar, wind, and other renewable energy systems.	9
18	Power Generation	Operating and maintaining systems that produce electrical power.	9
19	Event Production	Organizing and managing all technical and creative aspects of live events.	10
20	Content Creation	Developing original material for various media, including writing, video, and audio.	10
21	Waste Management	Collecting, transporting, processing, and disposing of waste materials.	11
22	Environmental Impact Assessment	Evaluating the likely environmental effects of a proposed project or development.	11
23	Fashion Design	Creating original designs for clothing, accessories, and footwear.	12
24	Textile Production	Manufacturing fabrics and other textile products from raw fibers.	12
25	Financial Modeling	Building abstract representations of real world financial situations using mathematical models.	13
26	Investment Analysis	Evaluating financial instruments, industries, and economic trends to make investment recommendations.	13
27	Food Preparation	The art and science of preparing food for consumption, often involving cooking techniques.	14
28	Food Safety	Ensuring that food products are safe for consumption, adhering to hygiene and regulatory standards.	14
29	Policy Analysis	Evaluating the effectiveness, efficiency, and equity of public policies.	15
30	Public Administration	Managing government agencies and implementing public policies.	15
31	Patient Care	Providing direct medical and supportive care to patients.	16
32	Medical Diagnosis	Identifying the nature and cause of a disease or condition through examination and analysis.	16
33	Customer Service	Assisting and supporting customers before, during, and after a purchase or service.	17
34	Hotel Management	Overseeing the operations of a hotel, including staffing, guest services, and finance.	17
35	Software Development	Designing, coding, testing, and maintaining software applications.	18
36	Network Security	Protecting computer networks and data from unauthorized access, misuse, and disruption.	18
37	Risk Assessment	Identifying and evaluating potential risks to an organization or project.	19
38	Claims Processing	Handling and settling insurance claims from policyholders.	19
39	Legal Research	Investigating legal precedents, statutes, and other legal sources to support legal arguments.	20
40	Litigation	Representing clients in legal disputes in court.	20
41	Production Planning	Organizing and scheduling manufacturing processes to meet production targets.	21
42	Assembly Line Management	Supervising and optimizing the efficiency of assembly line operations.	21
43	Journalism	Investigating and reporting news and current events.	22
44	Digital Marketing	Promoting products or services using digital channels and strategies.	22
45	Geological Survey	Conducting scientific studies of the Earth's structure, composition, and processes.	23
46	Heavy Equipment Operation	Operating large machinery used in construction, mining, or agriculture.	23
47	Drug Discovery	Identifying new therapeutic compounds for medicinal purposes.	24
48	Clinical Trials	Conducting research studies with human volunteers to test new medical treatments.	24
49	Property Valuation	Estimating the market value of real estate properties.	25
50	Lease Negotiation	Bargaining terms and conditions for rental agreements.	25
51	Sales Management	Overseeing sales teams and strategies to achieve revenue targets.	26
52	Inventory Management	Tracking and controlling the stock of goods to meet customer demand and minimize costs.	26
53	Network Engineering	Designing, implementing, and managing computer networks.	27
54	Fiber Optics Installation	Installing and maintaining fiber optic cables for high-speed data transmission.	27
55	Tour Guiding	Leading and informing groups of tourists about points of interest.	28
56	Travel Planning	Organizing itineraries, accommodations, and transportation for trips.	28
57	Supply Chain Management	Overseeing the entire process of producing and distributing goods, from raw materials to final delivery.	29
58	Logistics Planning	Strategizing the efficient movement and storage of goods and resources.	29
59	Grid Maintenance	Maintaining and repairing electrical power grids and distribution systems.	30
60	Water Treatment	Processes to improve the quality of water to make it more acceptable for a specific end-use.	30
61	Cloud Computing (AWS, Azure, GCP)	Proficiency in designing, deploying, and managing applications on major cloud platforms like Amazon Web Services, Microsoft Azure, and Google Cloud Platform.	18
62	Cybersecurity Operations	Skills in monitoring, detecting, and responding to cyber threats and incidents.	18
63	DevOps Automation	Automating software development and IT operations processes to improve efficiency and speed.	18
64	Database Management (SQL, NoSQL)	Administering and maintaining databases, including SQL (e.g., PostgreSQL, MySQL) and NoSQL (e.g., MongoDB, Cassandra) systems.	18
65	Front-end Development (React, Angular, Vue)	Building user interfaces and user experiences for web applications using frameworks like React, Angular, and Vue.js.	18
66	Back-end Development (Python, Node.js, Java)	Developing server-side logic, databases, and APIs for web applications using languages such as Python, Node.js, and Java.	18
67	Mobile App Development (iOS, Android)	Creating applications for mobile devices, specifically for Apple iOS and Google Android platforms.	18
68	Artificial Intelligence/Machine Learning	Designing, developing, and implementing AI and ML models and algorithms for various applications.	18
69	Big Data Technologies (Hadoop, Spark)	Working with large datasets using distributed processing frameworks like Hadoop and Spark.	18
70	UI/UX Design	Designing intuitive and aesthetically pleasing user interfaces (UI) and ensuring a positive user experience (UX).	18
71	IT Project Management	Managing IT projects from conception to completion, ensuring they are delivered on time and within budget.	18
72	Technical Support	Providing assistance and troubleshooting for hardware, software, and network issues to end-users.	18
73	Systems Administration	Managing, maintaining, and configuring computer systems and servers.	18
74	Data Warehousing	Designing, implementing, and managing systems for storing and analyzing large amounts of data for business intelligence.	18
75	API Development	Creating Application Programming Interfaces (APIs) for software applications to communicate with each other.	18
76	Blockchain Development	Developing applications and systems on blockchain platforms, including smart contracts and decentralized applications.	18
77	Embedded Systems Programming	Writing software for embedded systems, which are specialized computer systems designed for specific functions within a larger mechanical or electrical system.	18
78	Game Development	Designing, programming, and creating assets for video games across various platforms.	18
79	Network Architecture	Designing and planning computer networks, including hardware, software, and communication protocols.	18
80	Scrum/Agile Methodologies	Applying agile principles and practices, such as Scrum, for iterative and incremental software development.	18
81	Version Control (Git)	Using version control systems like Git to manage and track changes in source code during software development.	18
82	Containerization (Docker, Kubernetes)	Deploying and managing applications using container technologies like Docker and orchestration platforms like Kubernetes.	18
\.


--
-- Data for Name: user_skills; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_skills (user_skill_id, user_id, skill_id, profi_level, years_of_exp, added_at) FROM stdin;
1	1	35	4	2	2025-06-12 05:41:41.159709
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, person_id, username, phone_number, email, is_email_verified, password_hash, status, last_login, created_at, updated_at) FROM stdin;
1	1	user1	+1998982340	user1@email.com	f	0b14d501a594442a01c6859541bcb3e8164d183d32937b851835442f69d5c94e	0	2025-06-08 06:21:22.735508	2025-06-08 06:21:22.735508	2025-06-08 06:21:22.735508
3	9	user3	+12198403850	someone@something.com	t	0b14d501a594442a01c6859541bcb3e8164d183d32937b851835442f69d5c94e	0	2025-06-24 18:55:59.992803	2025-06-24 18:55:59.992803	2025-06-24 18:55:59.992803
\.


--
-- Name: certificate_types_certificate_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.certificate_types_certificate_type_id_seq', 7, true);


--
-- Name: connections_connection_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.connections_connection_id_seq', 3, true);


--
-- Name: countries_country_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.countries_country_id_seq', 194, true);


--
-- Name: educations_education_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.educations_education_id_seq', 3, true);


--
-- Name: follows_follow_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.follows_follow_id_seq', 15, true);


--
-- Name: industries_industry_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.industries_industry_id_seq', 30, true);


--
-- Name: institution_types_institution_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.institution_types_institution_type_id_seq', 8, true);


--
-- Name: learning_modes_learning_mode_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.learning_modes_learning_mode_id_seq', 6, true);


--
-- Name: people_person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.people_person_id_seq', 9, true);


--
-- Name: proficiency_levels_proficiency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proficiency_levels_proficiency_id_seq', 8, true);


--
-- Name: profiles_profile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.profiles_profile_id_seq', 1, true);


--
-- Name: roles_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_role_id_seq', 82, true);


--
-- Name: skills_skill_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.skills_skill_id_seq', 82, true);


--
-- Name: user_skills_user_skill_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_skills_user_skill_id_seq', 6, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 3, true);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (attachment_id);


--
-- Name: certificate_types certificate_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.certificate_types
    ADD CONSTRAINT certificate_types_pkey PRIMARY KEY (certificate_type_id);


--
-- Name: chat_participants chat_participants_chat_id_participant_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_chat_id_participant_id_key UNIQUE (chat_id, participant_id);


--
-- Name: chat_participants chat_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_pkey PRIMARY KEY (chat_participant_id);


--
-- Name: chats chats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (chat_id);


--
-- Name: companies companies_contact_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_contact_email_key UNIQUE (contact_email);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (company_id);


--
-- Name: companies companies_website_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_website_key UNIQUE (website);


--
-- Name: company_admins company_admins_company_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.company_admins
    ADD CONSTRAINT company_admins_company_id_user_id_key UNIQUE (company_id, user_id);


--
-- Name: company_admins company_admins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.company_admins
    ADD CONSTRAINT company_admins_pkey PRIMARY KEY (company_admin_id);


--
-- Name: connections connections_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_pkey PRIMARY KEY (connection_id);


--
-- Name: countries countries_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_name_key UNIQUE (name);


--
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (country_id);


--
-- Name: educations educations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.educations
    ADD CONSTRAINT educations_pkey PRIMARY KEY (education_id);


--
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (follow_id);


--
-- Name: industries industries_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.industries
    ADD CONSTRAINT industries_name_key UNIQUE (name);


--
-- Name: industries industries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.industries
    ADD CONSTRAINT industries_pkey PRIMARY KEY (industry_id);


--
-- Name: institution_types institution_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.institution_types
    ADD CONSTRAINT institution_types_pkey PRIMARY KEY (institution_type_id);


--
-- Name: learning_modes learning_modes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.learning_modes
    ADD CONSTRAINT learning_modes_pkey PRIMARY KEY (learning_mode_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- Name: follows no_duplicated_follow; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT no_duplicated_follow UNIQUE (follower_id, followee_id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (person_id);


--
-- Name: proficiency_levels proficiency_levels_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proficiency_levels
    ADD CONSTRAINT proficiency_levels_name_key UNIQUE (name);


--
-- Name: proficiency_levels proficiency_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proficiency_levels
    ADD CONSTRAINT proficiency_levels_pkey PRIMARY KEY (proficiency_id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (profile_id);


--
-- Name: profiles profiles_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_key UNIQUE (user_id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_id);


--
-- Name: roles roles_role_title_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_role_title_key UNIQUE (role_title);


--
-- Name: skills skills_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.skills
    ADD CONSTRAINT skills_name_key UNIQUE (name);


--
-- Name: skills skills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.skills
    ADD CONSTRAINT skills_pkey PRIMARY KEY (skill_id);


--
-- Name: connections unique_connection; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT unique_connection UNIQUE (user_id, target_user_id);


--
-- Name: user_skills unique_user_skill; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT unique_user_skill UNIQUE (user_id, skill_id);


--
-- Name: user_skills user_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT user_skills_pkey PRIMARY KEY (user_skill_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_person_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_person_id_key UNIQUE (person_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: follows_followee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX follows_followee_id ON public.follows USING btree (followee_id);


--
-- Name: follows_follower_followee_ids; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX follows_follower_followee_ids ON public.follows USING btree (follower_id, followee_id);


--
-- Name: follows_follower_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX follows_follower_id ON public.follows USING btree (follower_id);


--
-- Name: idx_chat_participants_chat_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chat_participants_chat_id ON public.chat_participants USING btree (chat_id);


--
-- Name: idx_chat_participants_participant_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chat_participants_participant_id ON public.chat_participants USING btree (participant_id);


--
-- Name: idx_companies_location_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_companies_location_id ON public.companies USING btree (location_id);


--
-- Name: idx_companies_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_companies_name ON public.companies USING btree (name);


--
-- Name: idx_companies_remote_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_companies_remote_status ON public.companies USING btree (remote_status);


--
-- Name: idx_company_admins_company_id_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_company_admins_company_id_user_id ON public.company_admins USING btree (company_id, user_id);


--
-- Name: idx_connections_target_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_connections_target_user_id ON public.connections USING btree (target_user_id);


--
-- Name: idx_connections_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_connections_user_id ON public.connections USING btree (user_id);


--
-- Name: idx_connections_user_id_to_target; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_connections_user_id_to_target ON public.connections USING btree (user_id, target_user_id);


--
-- Name: idx_education_certificate_type_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_education_certificate_type_id ON public.educations USING btree (certificate_type_id);


--
-- Name: idx_education_title; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_education_title ON public.educations USING btree (education_title);


--
-- Name: idx_industry_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_industry_id ON public.educations USING btree (industry_id);


--
-- Name: idx_institution_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_institution_name ON public.educations USING btree (institution_name);


--
-- Name: idx_people_first_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_people_first_name ON public.people USING btree (first_name);


--
-- Name: idx_people_last_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_people_last_name ON public.people USING btree (last_name);


--
-- Name: idx_people_middle_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_people_middle_name ON public.people USING btree (middle_name);


--
-- Name: idx_profiles_headline; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_profiles_headline ON public.profiles USING btree (headline);


--
-- Name: idx_profiles_open_to_work; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_profiles_open_to_work ON public.profiles USING btree (open_to_work);


--
-- Name: idx_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_id ON public.educations USING btree (user_id);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_phone_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone_number ON public.users USING btree (phone_number);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: messages after_message_activity_update_chat_last_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_message_activity_update_chat_last_update AFTER INSERT OR UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_chat_last_update();


--
-- Name: chat_participants after_participant_delete_cleanup_chat; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER after_participant_delete_cleanup_chat AFTER DELETE ON public.chat_participants FOR EACH ROW EXECUTE FUNCTION public.delete_chat_if_no_participants();


--
-- Name: connections check_duplicate_or_reversed_connection; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_duplicate_or_reversed_connection BEFORE INSERT ON public.connections FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_or_reversed_connections();


--
-- Name: educations edu_mview_trg; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER edu_mview_trg AFTER INSERT OR DELETE OR UPDATE ON public.educations FOR EACH ROW EXECUTE FUNCTION public.edu_mview_changes_trgfun();


--
-- Name: user_skills trg_check_years_of_exp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_years_of_exp BEFORE INSERT OR UPDATE ON public.user_skills FOR EACH ROW EXECUTE FUNCTION public.check_years_of_exp();


--
-- Name: companies update_companies_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: company_admins update_company_admins_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_company_admins_updated_at BEFORE UPDATE ON public.company_admins FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: connections update_connection_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_connection_updated_at BEFORE UPDATE ON public.connections FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: chat_participants chat_participants_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(chat_id) ON DELETE CASCADE;


--
-- Name: chat_participants chat_participants_participant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chat_participants
    ADD CONSTRAINT chat_participants_participant_id_fkey FOREIGN KEY (participant_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: companies companies_industry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES public.industries(industry_id);


--
-- Name: companies companies_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.countries(country_id);


--
-- Name: company_admins company_admins_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.company_admins
    ADD CONSTRAINT company_admins_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(company_id) ON DELETE CASCADE;


--
-- Name: company_admins company_admins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.company_admins
    ADD CONSTRAINT company_admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: connections connections_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: connections connections_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.connections
    ADD CONSTRAINT connections_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: educations educations_certificate_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.educations
    ADD CONSTRAINT educations_certificate_type_id_fkey FOREIGN KEY (certificate_type_id) REFERENCES public.certificate_types(certificate_type_id);


--
-- Name: educations educations_industry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.educations
    ADD CONSTRAINT educations_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES public.industries(industry_id);


--
-- Name: educations educations_institution_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.educations
    ADD CONSTRAINT educations_institution_type_id_fkey FOREIGN KEY (institution_type_id) REFERENCES public.institution_types(institution_type_id);


--
-- Name: educations educations_learning_mode_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.educations
    ADD CONSTRAINT educations_learning_mode_id_fkey FOREIGN KEY (learning_mode_id) REFERENCES public.learning_modes(learning_mode_id);


--
-- Name: educations educations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.educations
    ADD CONSTRAINT educations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: follows follows_followee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_followee_id_fkey FOREIGN KEY (followee_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: follows follows_follower_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: messages messages_attachment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_attachment_id_fkey FOREIGN KEY (attachment_id) REFERENCES public.attachments(attachment_id);


--
-- Name: messages messages_chat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_chat_id_fkey FOREIGN KEY (chat_id) REFERENCES public.chats(chat_id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: people people_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(country_id);


--
-- Name: profiles profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: roles roles_industry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES public.industries(industry_id);


--
-- Name: skills skills_industry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.skills
    ADD CONSTRAINT skills_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES public.industries(industry_id);


--
-- Name: user_skills user_skills_profi_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT user_skills_profi_level_fkey FOREIGN KEY (profi_level) REFERENCES public.proficiency_levels(proficiency_id);


--
-- Name: user_skills user_skills_skill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT user_skills_skill_id_fkey FOREIGN KEY (skill_id) REFERENCES public.skills(skill_id);


--
-- Name: user_skills user_skills_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT user_skills_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: users users_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.people(person_id) ON DELETE CASCADE;


--
-- Name: edu_user_details; Type: MATERIALIZED VIEW DATA; Schema: public; Owner: postgres
--

REFRESH MATERIALIZED VIEW public.edu_user_details;


--
-- PostgreSQL database dump complete
--

