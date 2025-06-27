# Connection Management System Documentation

## Table Overview: `connections`

The `connections` table models social relationships (friendships, requests, blocks) between users in the system. Each record represents a connection status between a user and a target user, supporting bidirectional relationships while maintaining data integrity.

### 🔑 Table Schema

| Column | Type | Description |
|--------|------|-------------|
| `connection_id` | `BIGSERIAL` | Primary key of the connection |
| `user_id` | `BIGINT` | Foreign key to `users.user_id` - The user who initiated the connection |
| `target_user_id` | `BIGINT` | Foreign key to `users.user_id` - The target user of the connection |
| `status` | `SMALLINT DEFAULT 0` | Connection status (see status codes below) |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | Timestamp when the connection was created |
| `updated_at` | `TIMESTAMP WITH TIME ZONE` | Timestamp when the connection was last updated |

### 🔒 Constraints & Indexes

- **Unique constraint** on `(user_id, target_user_id)` to prevent duplicate requests
- **Check constraint** to prevent self-connections (`user_id <> target_user_id`)
- **Indexes** on `user_id`, `target_user_id`, and the combined pair for faster lookups
- **Foreign key cascades**: `ON DELETE CASCADE` - deleting a user removes all related connections

### 📊 Status Code System

| Code | State | Description | Perspective |
|------|-------|-------------|-------------|
| **-1** | Error | No connection found / Error occurred | System |
| **0** | Pending | You sent a pending request | Outgoing |
| **1** | Accepted | Connection is established | Mutual |
| **2** | Blocked | You blocked them | Outgoing |
| **3** | Pending | They sent you a pending request | Incoming |
| **4** | Blocked | They blocked you | Incoming |
| **6** | Blocked | Both users blocked each other | Mutual |

## Core Functions

### Connection Request Management

#### `create_connection(user_id, target_user_id)`

**Purpose**: Creates a new connection request from one user to another.

**Parameters**:
- `user_id` (BIGINT): The user initiating the connection request
- `target_user_id` (BIGINT): The user receiving the connection request

**Returns**:
- `1`: Request successfully created
- `-1`: Failed (connection already exists in either direction)

**Usage Examples**:
```sql
-- User 1 sends connection request to User 3
SELECT create_connection(1, 3);
-- Returns: 1 (success)

-- Check the status from sender's perspective
SELECT find_connection(1, 3);
-- Returns: 0 (you sent pending request)

-- Check the status from receiver's perspective  
SELECT find_connection(3, 1);
-- Returns: 3 (they sent you pending request)

-- Try to create duplicate request
SELECT create_connection(1, 3);
-- Returns: -1 (already exists)
```

#### `accept_connection(user_id, target_user_id)`

**Purpose**: Accepts a connection request that was sent TO the user.

**Parameters**:
- `user_id` (BIGINT): The user accepting the request (must be the target of original request)
- `target_user_id` (BIGINT): The user who sent the original request

**Returns**:
- `1`: Request successfully accepted
- `-1`: No pending request found or not authorized

**Usage Examples**:
```sql
-- User 3 accepts connection request from User 1
SELECT accept_connection(3, 1);
-- Returns: 1 (success)

-- Check status from both perspectives
SELECT find_connection(1, 3); -- Returns: 1 (connected)
SELECT find_connection(3, 1); -- Returns: 1 (connected)

-- Try to accept non-existent request
SELECT accept_connection(5, 1);
-- Returns: -1 (no pending request)
```

#### `delete_connection(user_id, target_user_id)`

**Purpose**: Deletes an existing connection between two users (any direction).

**Parameters**:
- `user_id` (BIGINT): One of the users in the connection
- `target_user_id` (BIGINT): The other user in the connection

**Returns**:
- `1`: Connection successfully deleted
- `-1`: No connection found

**Usage Examples**:
```sql
-- Delete connection between User 1 and User 3
SELECT delete_connection(1, 3);
-- Returns: 1 (success)

-- Verify deletion
SELECT find_connection(1, 3);
-- Returns: -1 (no connection)

-- Can be called from either direction
SELECT delete_connection(3, 1); -- Same effect as above
```

### Blocking Management

#### `block_connection(user_id, target_user_id)`

**Purpose**: Block a target user with complex status management for mutual blocks.

**Parameters**:
- `user_id` (BIGINT): The user who wants to block
- `target_user_id` (BIGINT): The user to be blocked

**Returns**:
- `1`: Successfully blocked
- `0`: Nothing to do (already in desired state)
- `-1`: Error occurred

**Blocking Logic**:
- **No connection** → Create new block (status 2)
- **Status 1 (connected)** → Change to blocked (status 2)
- **Status 4 (target blocked user)** → Create mutual block (status 6)
- **Status 2 (already blocked)** → No change needed

**Usage Examples**:
```sql
-- User 1 blocks User 3
SELECT block_connection(1, 3);
-- Returns: 1 (success)
SELECT find_connection(1, 3); -- Returns: 2 (you blocked them)
SELECT find_connection(3, 1); -- Returns: 4 (they blocked you)

-- User 3 blocks User 1 back (creates mutual block)
SELECT block_connection(3, 1);
-- Returns: 1 (success)
SELECT find_connection(1, 3); -- Returns: 6 (both blocked)
SELECT find_connection(3, 1); -- Returns: 6 (both blocked)

-- Try to block again (no change needed)
SELECT block_connection(1, 3);
-- Returns: 0 (nothing to do)
```

#### `unblock_connection(user_id, target_user_id)`

**Purpose**: Unblock a target user with smart partial unblocking for mutual blocks.

**Parameters**:
- `user_id` (BIGINT): The user who wants to unblock
- `target_user_id` (BIGINT): The user to be unblocked

**Returns**:
- `1`: Successfully unblocked
- `0`: Nothing to unblock or not authorized
- `-1`: Error occurred

**Unblocking Logic**:
- **Status 2 (user blocked target)** → Delete connection entirely
- **Status 4 (target blocked user)** → Cannot unblock (user didn't block)
- **Status 6 (mutual block)** → Change to status 4 (only target blocking remains)

**Usage Examples**:
```sql
-- User 1 unblocks User 3 (from mutual block scenario)
SELECT unblock_connection(1, 3);
-- Returns: 1 (success)
SELECT find_connection(1, 3); -- Returns: 4 (they blocked you)
SELECT find_connection(3, 1); -- Returns: 2 (you blocked them)

-- User 1 tries to unblock when only target blocked them
SELECT unblock_connection(1, 3); -- when status is 4
-- Returns: 0 (cannot unblock - user didn't block target)

-- Complete unblock when user was sole blocker
SELECT unblock_connection(1, 3); -- when status is 2
-- Returns: 1 (success), connection deleted entirely
```

### Connection Querying

#### `find_connection(user_id, target_user_id)`

**Purpose**: Check the current connection status between two users from the requesting user's perspective.

**Parameters**:
- `user_id` (BIGINT): The user making the inquiry
- `target_user_id` (BIGINT): The target user to check

**Returns**: INT (status code from the reference table)

**Usage Examples**:
```sql
-- Check connection status from User 1's perspective
SELECT find_connection(1, 3);
-- Possible returns: -1, 0, 1, 2, 3, 4, 6

-- Check from other perspective (may differ)
SELECT find_connection(3, 1);
-- Returns status from User 3's viewpoint

-- Use in conditional logic
SELECT CASE find_connection(1, 3)
    WHEN -1 THEN 'No connection'
    WHEN 0  THEN 'Request sent'
    WHEN 1  THEN 'Connected'
    WHEN 2  THEN 'You blocked them'
    WHEN 3  THEN 'Request received' 
    WHEN 4  THEN 'They blocked you'
    WHEN 6  THEN 'Mutual block'
    ELSE 'Unknown status'
END as connection_status;
```

#### `get_connections(user_id)`

**Purpose**: Retrieve all active connections for a user (accepted connections only).

**Parameters**:
- `user_id` (BIGINT): The user whose connections to retrieve

**Returns**: TABLE with columns:
- `username` (VARCHAR): Connected user's username
- `full_name` (VARCHAR): Connected user's full name  
- `profile_pic_url` (VARCHAR): Connected user's profile picture URL

**Usage Examples**:
```sql
-- Get all connections for User 1
SELECT * FROM get_connections(1);

-- Count user's connections
SELECT COUNT(*) as friend_count FROM get_connections(1);

-- Find specific connections
SELECT username, full_name 
FROM get_connections(1) 
WHERE full_name ILIKE '%john%';

-- Get connections with custom formatting
SELECT 
    username,
    full_name,
    COALESCE(profile_pic_url, 'default.jpg') as profile_pic
FROM get_connections(1)
ORDER BY full_name;
```

## Complete Usage Scenarios

### Scenario 1: Standard Friend Request Flow
```sql
-- Step 1: User 1 sends request to User 3
SELECT create_connection(1, 3);        -- Returns: 1
SELECT find_connection(1, 3);          -- Returns: 0 (request sent)
SELECT find_connection(3, 1);          -- Returns: 3 (request received)

-- Step 2: User 3 accepts the request
SELECT accept_connection(3, 1);        -- Returns: 1
SELECT find_connection(1, 3);          -- Returns: 1 (connected)
SELECT find_connection(3, 1);          -- Returns: 1 (connected)

-- Step 3: Both users see each other in connections
SELECT * FROM get_connections(1);      -- Shows User 3
SELECT * FROM get_connections(3);      -- Shows User 1
```

### Scenario 2: Request Rejection
```sql
-- User 1 sends request to User 3
SELECT create_connection(1, 3);        -- Returns: 1

-- User 3 rejects by deleting the request
SELECT delete_connection(3, 1);        -- Returns: 1
SELECT find_connection(1, 3);          -- Returns: -1 (no connection)
```

### Scenario 3: Complex Blocking Scenario
```sql
-- Initial: Users are connected
SELECT create_connection(1, 3);        -- Request
SELECT accept_connection(3, 1);        -- Accept
SELECT find_connection(1, 3);          -- Returns: 1 (connected)

-- User 1 blocks User 3
SELECT block_connection(1, 3);         -- Returns: 1
SELECT find_connection(1, 3);          -- Returns: 2 (you blocked)
SELECT find_connection(3, 1);          -- Returns: 4 (they blocked)

-- User 3 blocks User 1 back
SELECT block_connection(3, 1);         -- Returns: 1
SELECT find_connection(1, 3);          -- Returns: 6 (mutual block)
SELECT find_connection(3, 1);          -- Returns: 6 (mutual block)

-- User 1 unblocks User 3 (partial unblock)
SELECT unblock_connection(1, 3);       -- Returns: 1
SELECT find_connection(1, 3);          -- Returns: 4 (they blocked)
SELECT find_connection(3, 1);          -- Returns: 2 (you blocked)

-- User 3 unblocks User 1 (complete resolution)
SELECT unblock_connection(3, 1);       -- Returns: 1
SELECT find_connection(1, 3);          -- Returns: -1 (no connection)
```

### Scenario 4: Connection Management
```sql
-- Get user's connection statistics
SELECT 
    COUNT(*) as total_connections,
    STRING_AGG(username, ', ') as friend_list
FROM get_connections(1);

-- Find mutual connections between users
SELECT c1.username as mutual_friend
FROM get_connections(1) c1
INNER JOIN get_connections(2) c2 ON c1.username = c2.username;

-- Clean up all connections for a user (before deletion)
SELECT delete_connection(1, target_user_id)
FROM (
    SELECT DISTINCT 
        CASE 
            WHEN user_id = 1 THEN target_user_id 
            ELSE user_id 
        END as target_user_id
    FROM connections 
    WHERE 1 IN (user_id, target_user_id)
) as user_connections;
```

## Design Principles

### Bidirectional Relationships
- Connections are **bidirectional** but stored in **one direction** only
- Functions automatically handle perspective-based queries
- Status codes encode both **state** and **direction** information

### Data Integrity
- Unique constraints prevent duplicate connections
- Check constraints prevent self-connections  
- Cascade deletes maintain referential integrity
- All functions include comprehensive error handling

### Performance Optimization
- Strategic indexing on frequently queried columns
- Efficient bidirectional lookups without table scans
- Minimal storage overhead with single-direction records

### Consistent API
- All modifying functions return `1` on success, negative values on failure
- Standardized parameter ordering (`user_id`, `target_user_id`)
- Comprehensive error handling with meaningful return codes

## Error Handling & Edge Cases

### Input Validation
- All functions validate for NULL parameters
- Self-connection attempts are rejected
- Invalid user IDs are handled gracefully

### State Management
- Functions handle all possible state transitions safely
- No data corruption possible from concurrent operations
- Idempotent operations where appropriate (blocking/unblocking)

### Debugging Support
- Warning messages logged for all errors
- Consistent return codes for programmatic error handling
- Clear status code system for troubleshooting