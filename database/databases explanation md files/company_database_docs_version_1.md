# Company Management Database Documentation

## Overview

This database schema provides a comprehensive system for managing companies and their administrative relationships. It includes user ownership, role management, approval workflows, and company status tracking.

## Tables

### `companies`

The main table storing company information with comprehensive validation and status tracking.

**Structure:**
- `company_id` (UUID, Primary Key) - Unique identifier for each company
- `name` (VARCHAR(255), NOT NULL) - Company name with trim validation
- `industry_id` (BIGINT, NOT NULL) - Foreign key to industries table
- `size` (SMALLINT, NOT NULL) - Company size category (1-8)
- `founded_date` (DATE, NOT NULL) - Company founding date (must be after 1750-01-01)
- `website` (url_type, UNIQUE) - Company website URL
- `contact_email` (email_type, UNIQUE, NOT NULL) - Primary contact email
- `location_id` (SMALLINT, NOT NULL) - Foreign key to countries table
- `description` (TEXT) - Company description
- `logo_url` (url_type) - Company logo URL
- `banner_url` (url_type) - Company banner URL
- `remote_status` (SMALLINT, DEFAULT 0) - Remote work policy
- `status` (SMALLINT, DEFAULT 0) - Company approval status
- `previous_status` (SMALLINT) - Previous status before suspension
- `created_at` (TIMESTAMPTZ, DEFAULT NOW()) - Creation timestamp
- `updated_at` (TIMESTAMPTZ, DEFAULT NOW()) - Last update timestamp

**Company Size Categories:**
- 1: 1-10 employees
- 2: 11-50 employees
- 3: 51-200 employees
- 4: 201-500 employees
- 5: 501-1,000 employees
- 6: 1,001-5,000 employees
- 7: 5,001-10,000 employees
- 8: 10,001+ employees

**Remote Status Options:**
- 0: On-site
- 1: Hybrid
- 2: Fully Remote

**Company Status Values:**
- 0: Unofficial (user email verified only)
- 1: Official (fully approved)
- 2: Semi-official (approved to make new company, awaiting final status)
- 3: Pending application (e.g., second company)
- 4: Rejected
- 5: Suspended

**Indexes:**
- `idx_companies_name` - On company name
- `idx_companies_location_id` - On location
- `idx_companies_remote_status` - On remote status

### `company_admins`

Junction table managing user-company relationships and administrative roles.

**Structure:**
- `company_admin_id` (UUID, Primary Key) - Unique identifier
- `company_id` (UUID, NOT NULL) - Foreign key to companies table
- `user_id` (BIGINT, NOT NULL) - Foreign key to users table
- `role` (SMALLINT, NOT NULL) - Administrative role level
- `created_at` (TIMESTAMPTZ, DEFAULT NOW()) - Creation timestamp
- `updated_at` (TIMESTAMPTZ, DEFAULT NOW()) - Last update timestamp

**Role Values:**
- 0: None
- 1: Admin
- 2: Owner

**Constraints:**
- Unique combination of company_id and user_id
- Only one owner (role = 2) per company
- Cascade delete when company or user is deleted

**Indexes:**
- `idx_company_admins_company_id_user_id` - Composite index on company_id and user_id
- `unique_single_owner_per_company` - Ensures single owner per company

## Custom Data Types

### `url_type`
Custom domain for URL validation supporting HTTP, HTTPS, and FTP protocols.

### `email_type`
Custom domain for email validation with comprehensive regex pattern matching.

## Views

### `user_owned_companies_view`
Provides a simplified view of companies owned by users, showing essential company information for owners only.

**Columns:**
- `user_id` - User identifier
- `company_id` - Company identifier
- `name` - Company name
- `website` - Company website
- `status` - Company status
- `logo_url` - Company logo URL

## Functions

### Utility Functions

#### `user_companies_number(p_user_id BIGINT) RETURNS INTEGER`
Returns the total number of companies owned by a specific user.

#### `user_active_companies_number(p_user_id BIGINT) RETURNS INTEGER`
Returns the number of active companies (status = 1) owned by a specific user.

#### `user_pending_company_exists(p_user_id BIGINT) RETURNS BOOLEAN`
Checks if a user has any pending company applications (status = 3).

#### `get_company_admins(p_company_id UUID) RETURNS TABLE`
Returns all administrators for a specific company with their roles and creation dates.

**Return Columns:**
- `user_id` (BIGINT) - User identifier
- `role` (SMALLINT) - Role number
- `role_alias` (VARCHAR(150)) - Human-readable role name
- `created_at` (TIMESTAMPTZ) - When the admin role was created

### Company Management Functions

#### `add_company(...)` 
Creates a new company with automatic domain validation and ownership assignment.

**Parameters:**
- `p_by_user_id` (BIGINT) - ID of the user creating the company
- `p_name` (TEXT) - Company name
- `p_website` (TEXT) - Company website
- `p_industry_id` (BIGINT) - Industry category
- `p_size` (SMALLINT) - Company size category
- `p_founded_date` (DATE) - Company founding date
- `p_location_id` (SMALLINT) - Company location

**Validation Rules:**
- User must exist and have verified email
- User can only own one company initially
- Email domain must match website domain
- All required fields must be provided
- Company starts with status 0 (unofficial)

**Returns:** UUID of the created company

#### `send_company_application(...)`
Submits an application for a second company when user already owns an active company.

**Parameters:** Same as `add_company`

**Validation Rules:**
- User must have at least one active company
- User cannot have existing pending applications
- Company name and website must be unique
- Company starts with status 3 (pending)

**Returns:** UUID of the created company application

#### `give_ownership(p_company_id UUID, p_user_id BIGINT) RETURNS UUID`
Transfers company ownership from current owner to an existing admin.

**Parameters:**
- `p_company_id` (UUID) - Company to transfer
- `p_user_id` (BIGINT) - User to promote to owner

**Requirements:**
- Target user must be an existing admin (role = 1)
- Company and user must exist

**Returns:** UUID of the updated company_admin record

## Procedures

### Company Status Management

#### `fully_approve_company(p_company_id UUID)`
Approves a company, changing status from unofficial (0) or semi-official (2) to official (1).

#### `semi_approve_company(p_company_id UUID)`
Gives semi-official approval to a pending company application (status 3 → 2).

#### `reject_company_application(p_company_id UUID)`
Rejects a pending company application (status 3 → 4).

#### `suspend_company(p_company_id UUID)`
Suspends a company, storing the previous status for potential restoration.

**Behavior:**
- Sets status to 5 (suspended)
- Stores current status in `previous_status` field
- Cannot suspend an already suspended company

#### `unsuspend_company(p_company_id UUID)`
Restores a suspended company to its previous status.

**Requirements:**
- Company must be suspended (status = 5)
- Must have a valid previous_status recorded

## Triggers

### Automatic Timestamp Updates
- `update_companies_updated_at` - Updates `updated_at` on company modifications
- `update_company_admins_updated_at` - Updates `updated_at` on admin role changes

### Status Management
- `trg_set_previous_status` - Automatically stores previous status when suspending companies

### Ownership Management
- `trg_check_owner_after_admin_delete` - Handles owner deletion by:
  - Promoting the oldest admin to owner, or
  - Suspending the company if no admins remain

## Workflow Examples

### Creating a First Company
1. User registers and verifies email
2. User calls `add_company()` with matching email/website domains
3. Company created with status 0 (unofficial)
4. Admin can approve with `fully_approve_company()`

### Applying for Additional Companies
1. User with active company calls `send_company_application()`
2. Application created with status 3 (pending)
3. Admin reviews and either:
   - Calls `semi_approve_company()` then `fully_approve_company()`
   - Calls `reject_company_application()`

### Managing Company Suspension
1. Admin calls `suspend_company()` - status becomes 5, previous status stored
2. Later, admin calls `unsuspend_company()` - status restored to previous value

## Security Features

- **Email Domain Validation**: Prevents unauthorized company creation
- **Single Ownership**: Each company has exactly one owner
- **Cascade Protection**: Automatic ownership transfer when owners are deleted
- **Status Tracking**: Complete audit trail of company approval states
- **Input Validation**: Comprehensive checks on all user inputs

---

## User-Accessible Functions and Procedures

### Functions
- `add_company(p_by_user_id BIGINT, p_name TEXT, p_website TEXT, p_industry_id BIGINT, p_size SMALLINT, p_founded_date DATE, p_location_id SMALLINT) RETURNS UUID`
- `send_company_application(p_by_user_id BIGINT, p_name TEXT, p_website TEXT, p_industry_id BIGINT, p_size SMALLINT, p_founded_date DATE, p_location_id SMALLINT) RETURNS UUID`
- `give_ownership(p_company_id UUID, p_user_id BIGINT) RETURNS UUID`
- `user_companies_number(p_user_id BIGINT) RETURNS INTEGER`
- `user_active_companies_number(p_user_id BIGINT) RETURNS INTEGER`
- `user_pending_company_exists(p_user_id BIGINT) RETURNS BOOLEAN`
- `get_company_admins(p_company_id UUID) RETURNS TABLE`

### Procedures
- `fully_approve_company(p_company_id UUID)`
- `semi_approve_company(p_company_id UUID)`
- `reject_company_application(p_company_id UUID)`
- `suspend_company(p_company_id UUID)`
- `unsuspend_company(p_company_id UUID)`

### Views
- `user_owned_companies_view`