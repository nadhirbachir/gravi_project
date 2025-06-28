# Chat System Database Documentation

## Overview

This database schema implements a comprehensive private chat messaging system designed for one-on-one conversations between users. The system includes user connection management, file attachments, message tracking, and automated cleanup features with intelligent triggers for maintaining data consistency.

## Database Architecture

### Core Tables Structure

| Table | Primary Key | Purpose | Dependencies |
|-------|-------------|---------|--------------|
| `chats` | `chat_id` (UUID) | Central conversation hub | None |
| `chat_participants` | `chat_participant_id` (UUID) | User-to-chat relationships | `chats`, `users` |
| `messages` | `message_id` (UUID) | Message content and metadata | `chats`, `users`, `attachments` |
| `attachments` | `attachment_id` (UUID) | File management system | None |

### Relationship Overview

```
chats (1) ←→ (many) chat_participants ←→ (many) users
chats (1) ←→ (many) messages
messages (many) ←→ (1) attachments [optional]
```

## Detailed Table Specifications

### Chats Table
**Purpose**: Central hub for all conversations with minimal overhead design

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `chat_id` | UUID | PRIMARY KEY, AUTO-GENERATED | Unique conversation identifier |
| `created_at` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Chat creation timestamp |
| `last_update` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Last activity timestamp (auto-updated) |

**Design Philosophy:**
- **Minimal Storage**: Only essential metadata to reduce overhead
- **UUID Strategy**: Ensures global uniqueness and prevents ID collision
- **Automatic Timestamps**: Eliminates manual timestamp management
- **Activity Tracking**: `last_update` automatically maintained by message triggers

### Chat Participants Table
**Purpose**: Many-to-many relationship manager supporting flexible participation models

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `chat_participant_id` | UUID | PRIMARY KEY, AUTO-GENERATED | Unique participation record |
| `chat_id` | UUID | FOREIGN KEY, CASCADE DELETE | Chat reference |
| `participant_id` | BIGINT | FOREIGN KEY, CASCADE DELETE | User reference |
| `created_at` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Join timestamp |
| `last_update` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Last modification |

**Key Constraints:**
- `UNIQUE (chat_id, participant_id)` - Prevents duplicate participation
- **Cascading Deletes** - Maintains referential integrity

**Strategic Design:**
- **Future-Proof**: Ready for group chat implementation
- **Efficient Queries**: Indexed on both chat_id and participant_id
- **Data Integrity**: Automatic cleanup when users or chats are deleted

### Messages Table
**Purpose**: Complete message storage with content validation and status tracking

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `message_id` | UUID | PRIMARY KEY, AUTO-GENERATED | Unique message identifier |
| `chat_id` | UUID | FOREIGN KEY, CASCADE DELETE | Parent chat reference |
| `sender_id` | BIGINT | FOREIGN KEY, CASCADE DELETE | Message author |
| `content` | TEXT | NULLABLE | Message text content |
| `attachment_id` | UUID | FOREIGN KEY, NULLABLE | Optional file attachment |
| `created_at` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Send timestamp |
| `last_update` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Modification timestamp |
| `seen` | BOOLEAN | NOT NULL, DEFAULT FALSE | Read status flag |

**Content Validation:**
- `CHECK ((content IS NOT NULL AND TRIM(content) <> '') OR attachment_id IS NOT NULL)`
- Ensures every message has either text content or an attachment
- Prevents empty/meaningless messages from being stored

**Why This Validation:**
- **Data Quality**: Eliminates spam and accidental empty messages
- **Storage Efficiency**: Reduces wasted database space
- **User Experience**: Ensures all messages have meaningful content

### Attachments Table
**Purpose**: Centralized file management with type-based categorization

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `attachment_id` | UUID | PRIMARY KEY, AUTO-GENERATED | Unique file identifier |
| `type` | SMALLINT | NOT NULL | File category (1=file, 2=picture, 3=video) |
| `url` | TEXT | NOT NULL | Storage location/CDN URL |
| `uploaded_at` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Upload timestamp |
| `last_update` | TIMESTAMP WITH TIME ZONE | NOT NULL, DEFAULT NOW() | Modification timestamp |

**Type Classification:**
| Type Code | Category | Use Case |
|-----------|----------|----------|
| 1 | General Files | Documents, PDFs, archives |
| 2 | Pictures | Images, photos, graphics |
| 3 | Videos | Video files, animations |

**Design Benefits:**
- **Reusability**: Can be used across different system features
- **Type-Specific Handling**: Enables different processing logic per file type
- **Scalability**: URL-based storage supports CDN integration
- **Audit Trail**: Complete upload and modification tracking

## Automated System Functions & Triggers

### Trigger System Overview

| Trigger | Event | Function | Impact |
|---------|-------|----------|---------|
| Chat Cleanup | `AFTER DELETE` on `chat_participants` | `delete_chat_if_no_participants()` | Removes orphaned chats |
| Activity Tracking | `AFTER INSERT` on `messages` | Auto-update chat timestamp | Maintains chat activity order |

### Smart Chat Lifecycle Management

#### Automatic Orphan Cleanup
**Trigger**: `after_participant_delete_cleanup_chat`
**Function**: `delete_chat_if_no_participants()`

**Process Flow:**
1. **Trigger Activation**: Fires when participant is removed from chat
2. **Participant Count**: Counts remaining participants in affected chat
3. **Cleanup Decision**: If count = 0, initiates chat deletion
4. **Cascading Cleanup**: Removes chat, messages, and attachment references

**System Benefits:**
- **Zero Maintenance**: Automatic cleanup without manual intervention
- **Resource Efficiency**: Prevents database bloat from empty chats
- **Data Integrity**: Ensures consistent state after user departures
- **Performance**: Eliminates need for periodic cleanup jobs

#### Real-Time Activity Tracking
**Trigger**: Auto-update on message insertion

**Mechanism:**
- New message insertion automatically updates parent chat's `last_update`
- Enables real-time chat list sorting by activity
- Eliminates application-level timestamp management
- Provides accurate "last seen" functionality

## Core Business Logic Functions

### Chat Management Functions

| Function | Parameters | Return | Validation Layers |
|----------|------------|--------|-------------------|
| `create_private_chat()` | user1_id, user2_id | chat_id (UUID) | User existence → Duplicate check → Blocking status |
| `find_chat_by_participants()` | user1_id, user2_id | chat_id (UUID) | User validation → Chat existence |
| `find_chat_by_participants_username()` | username1, username2 | chat_id (UUID) | Username resolution → Chat lookup |

#### Private Chat Creation Logic
**Function**: `create_private_chat(user1_id, user2_id)`

**Multi-Layer Validation Pipeline:**

| Layer | Validation | Failure Action | Purpose |
|-------|------------|----------------|---------|
| **Input Sanitization** | Non-null, different users | Exception: "Parameter issue" | Prevent invalid requests |
| **User Existence** | Both users exist in database | Exception: "User not found" | Ensure valid participants |
| **Duplicate Prevention** | Check existing 1-on-1 chat | Return existing chat_id | Prevent chat duplication |
| **Relationship Status** | Check blocking/connection status | Exception: "Cannot create due to blocking" | Respect user privacy |
| **Chat Creation** | Create chat + add participants | Return new chat_id | Successful chat establishment |

**Why This Complex Validation:**
- **Data Integrity**: Prevents invalid chat states
- **User Privacy**: Respects blocking relationships
- **Resource Efficiency**: Avoids duplicate chats
- **Error Clarity**: Provides specific failure reasons
- **Atomic Operations**: All-or-nothing chat creation

### Message Management Functions

| Function | Parameters | Return | Security Features |
|----------|------------|--------|-------------------|
| `send_message()` | chat_id, sender_id, content, attachment_id | message_id (UUID) | Participation verification → Blocking check → Content validation |
| `update_seen()` | user_id, message_ids[] | VOID | Ownership validation → Bulk status update |
| `get_messages()` | chat_id, limit, page | Message records | Pagination → Chronological ordering |

#### Secure Message Delivery
**Function**: `send_message(chat_id, sender_id, content, attachment_id)`

**Security Validation Chain:**

| Step | Validation | Security Benefit |
|------|------------|------------------|
| **Chat Membership** | Sender is participant in chat | Prevents message injection attacks |
| **User Verification** | Both sender and recipient exist | Prevents orphaned messages |
| **Privacy Enforcement** | Check blocking status between users | Maintains communication boundaries |
| **Content Validation** | Message has content or attachment | Ensures meaningful communication |
| **Atomic Insertion** | Single transaction message creation | Maintains data consistency |

**Advanced Security Features:**
- **Real-time Blocking**: Checks current relationship status, not cached data
- **Participant Validation**: Ensures sender belongs to target chat
- **Content Requirements**: Enforces message quality standards
- **Error Specificity**: Provides detailed failure reasons for debugging

### Attachment & Status Functions

| Function | Parameters | Return | Special Features |
|----------|------------|--------|------------------|
| `add_attachment()` | type, url | attachment_id (UUID) | URL validation → Type categorization |
| `update_seen()` | user_id, message_ids[] | VOID | Self-message exclusion → Bulk processing |

#### Smart Status Management
**Function**: `update_seen(user_id, message_ids[])`

**Intelligent Update Logic:**
- **Self-Exclusion**: Users cannot mark their own messages as "seen"
- **Status Checking**: Only updates messages not already marked as seen
- **Bulk Processing**: Handles multiple messages in single transaction
- **Performance Optimization**: Reduces database round-trips

## Data Retrieval & Views

### Optimized Query Functions

| Function | Purpose | Optimization Strategy |
|----------|---------|----------------------|
| `get_messages()` | Paginated message retrieval | LIMIT/OFFSET with proper indexing |
| `get_user_chats()` | User's chat list with previews | View-based aggregation |

### Chat Summaries View
**View**: `chat_summaries_view`

**Aggregated Data Points:**
- **Participant Information**: Username, full name, profile picture
- **Last Message Preview**: Smart content display (text vs. "sent attachment")
- **Activity Timestamp**: Most recent message time
- **User Perspective**: Customized view per user

**Smart Content Preview Logic:**
```
IF message has attachment:
    Display: "{username} sent an attachment"
ELSE:
    Display: actual message content
```

**Performance Optimizations:**
- **LATERAL JOINs**: Efficient participant and message lookup
- **Limited Queries**: Single latest message per chat
- **Index Utilization**: Optimized for chat list queries

## System Architecture Benefits

### Scalability Features
- **UUID-Based Design**: Supports distributed systems and microservices
- **Indexed Relationships**: Efficient queries even with millions of records
- **View Abstractions**: Optimized read operations for common use cases
- **Pagination Support**: Prevents memory issues with large chat histories

### Data Integrity Assurance
- **Cascading Relationships**: Automatic cleanup maintains consistency
- **Constraint Enforcement**: Database-level validation prevents corruption
- **Atomic Operations**: Transactional safety for complex operations
- **Trigger Automation**: Consistent state maintenance without manual intervention

### Security & Privacy
- **Multi-Layer Validation**: Defense in depth for all operations
- **Real-Time Blocking**: Dynamic privacy enforcement
- **Audit Trails**: Complete timestamp tracking for all activities
- **Content Validation**: Quality control for message content

### Developer Experience
- **Clear Error Messages**: Specific failure reasons for debugging
- **Consistent Patterns**: Uniform function signatures and return types
- **Comprehensive Documentation**: Self-documenting database design
- **Flexible Architecture**: Easy to extend for new features

## Future Extensibility

The current architecture provides excellent foundations for:

### Enhanced Features
- **Group Chat Support**: Existing participant structure ready for multi-user chats
- **Message Reactions**: Additional tables can reference message_id
- **Message Threading**: Reply relationships through self-referencing
- **Advanced Search**: Full-text search on message content
- **Message Encryption**: Additional security columns

### Advanced Functionality
- **Chat Archiving**: Status flags and archive tables
- **Message Scheduling**: Delivery timestamp management
- **File Sharing Controls**: Attachment permissions and expiration
- **Integration Hooks**: Webhook support for external systems
- **Analytics**: Usage tracking and reporting capabilities

This architecture demonstrates enterprise-grade database design that balances functionality, performance, security, and maintainability while providing a robust foundation for modern messaging applications.