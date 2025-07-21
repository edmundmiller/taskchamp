# CLAUDE.md - Data Models

This file provides comprehensive guidance for AI agents working with the data models in the taskchamp iOS app. Understanding these models is crucial for implementing features that handle tasks, filtering, and AWS integration.

## Overview

The Models directory contains three core data structures that form the foundation of the taskchamp application:

- **TCTask**: The primary task model representing individual to-do items
- **TCFilter**: Task filtering and search functionality with SwiftData integration
- **AWSConfig**: Configuration models for AWS S3 synchronization

## Core Models

### TCTask (Primary Task Model)

`TCTask` is the central data model representing individual tasks. It provides comprehensive task management capabilities with external integrations.

#### Structure
```swift
public struct TCTask: Codable, Hashable, Identifiable {
    public let uuid: String           // Unique identifier (immutable)
    public var project: String?       // Optional project categorization
    public var description: String    // Task description (required)
    public var status: Status         // Current task state
    public var priority: Priority?    // Optional priority level
    public var due: Date?            // Optional due date
    public var obsidianNote: String? // Obsidian note integration
    public var noteAnnotationKey: String? // Internal annotation tracking
}
```

#### Enums

**Status Enum** - Represents task lifecycle:
```swift
public enum Status: String, Codable, CaseIterable {
    case pending    // Active tasks requiring attention
    case completed  // Finished tasks
    case deleted    // Soft-deleted tasks
}
```

**Priority Enum** - Task importance levels with comparison support:
```swift
public enum Priority: String, Codable, Comparable, CaseIterable {
    case none = "None"  // Default priority
    case high = "H"     // High priority tasks
    case medium = "M"   // Medium priority tasks
    case low = "L"      // Low priority tasks
}
```

Priority comparison: `high > medium > low > none`

#### Key Properties and Methods

**Computed Properties:**
- `isCompleted: Bool` - Quick status check for completed tasks
- `isDeleted: Bool` - Quick status check for deleted tasks
- `hasNote: Bool` - Indicates presence of Obsidian note
- `id: String` - Identifiable conformance returning uuid
- `localDate: String` - Formatted due date with relative formatting
- `localDateShort: String` - Shorter formatted due date
- `url: URL` - Deep link URL for task (`taskchamp://task/{uuid}`)

**Static Properties:**
- `newTaskUrl: URL` - Deep link for creating new tasks (`taskchamp://task/new`)

#### Serialization Patterns

TCTask implements complex Codable serialization with dynamic annotation support:

**Key Features:**
- Custom encoding/decoding for date handling (TimeInterval conversion)
- Dynamic annotation keys for Obsidian note integration
- Automatic annotation key generation with timestamps
- Prefix-based annotation parsing (`"task-note: "`)

**Usage Example:**
```swift
// Creating a new task
let task = TCTask(
    uuid: UUID().uuidString,
    description: "Complete project documentation",
    status: .pending,
    priority: .high,
    due: Date().addingTimeInterval(86400), // Tomorrow
    obsidianNote: "project-notes"
)

// Checking task properties
if task.isCompleted {
    print("Task completed: \(task.description)")
}

// URL schemes
let taskURL = task.url // taskchamp://task/{uuid}
```

#### Obsidian Integration

TCTask provides deep integration with Obsidian notes:
- `obsidianNote` property stores note reference
- `noteAnnotationKey` tracks internal annotation metadata
- Automatic encoding as `"task-note: {noteReference}"` in annotations
- Dynamic annotation key generation during encoding

### TCFilter (Task Filtering and Search)

`TCFilter` is a SwiftData model that manages task filtering and search functionality with sophisticated state tracking.

#### Structure
```swift
@Model
public class TCFilter: Codable {
    public var id = UUID()
    public var fullDescription: String = ""     // Human-readable filter description
    public var project: String = ""             // Project filter
    public var status = TCTask.Status.deleted   // Status filter
    public var priority = TCTask.Priority.none  // Priority filter
    public var due = Date(timeIntervalSince1970: 0) // Due date filter
    
    // State tracking - determines which filters are active
    public var didSetPrio: Bool = false
    public var didSetProject: Bool = false
    public var didSetDue: Bool = false
    public var didSetStatus: Bool = false
}
```

#### Key Methods and Properties

**Validation:**
- `isValidFilter: Bool` - Returns true if any filter criteria is set
- `realDue: Date?` - Returns actual due date only if due filter is active

**Filter Configuration:**
```swift
public func setPrio(_ prio: TCTask.Priority?)    // Sets priority filter
public func setDue(_ date: Date?)                // Sets due date filter (TODO: implementation pending)
public func setProject(_ project: String?)       // Sets project filter
public func setStatus(_ status: TCTask.Status?)  // Sets status filter
```

**SQL Integration:**
```swift
public func convertToSqlFilters() -> [String]    // Converts to SQL LIKE patterns
```

#### Default Filter

```swift
public static var defaultFilter: TCFilter {
    let filter = TCFilter(
        fullDescription: "My tasks",
        project: "",
        status: .pending,
        priority: .none,
        due: Date(timeIntervalSince1970: 0)
    )
    filter.didSetStatus = true  // Default shows pending tasks only
    return filter
}
```

#### Usage Patterns

```swift
// Creating a custom filter
let projectFilter = TCFilter()
projectFilter.setProject("mobile-app")
projectFilter.setStatus(.pending)
projectFilter.setPrio(.high)

// Checking filter validity
if projectFilter.isValidFilter {
    let sqlFilters = projectFilter.convertToSqlFilters()
    // Use sqlFilters for database queries
}
```

#### SwiftData Integration

TCFilter uses SwiftData's `@Model` macro for persistence:
- Automatic Core Data integration
- SwiftUI compatibility
- Relationship management with other models

**Important Note:** Due date filtering is partially implemented (marked with TODO comments).

### AWSConfig (Cloud Synchronization)

The AWSConfig models handle AWS S3 configuration for task synchronization across devices.

#### Core Structures

**AWSConfig** - Direct credential configuration:
```swift
public struct AWSConfig: Codable {
    public let region: String
    public let bucket: String
    public let accessKeyId: String
    public let secretAccessKey: String
    public let encryptionSecret: String
    public let avoidSnapshots: Bool
}
```

**AWSProfileConfig** - AWS profile-based configuration:
```swift
public struct AWSProfileConfig: Codable {
    public let region: String
    public let bucket: String
    public let profileName: String
    public let encryptionSecret: String
    public let avoidSnapshots: Bool
}
```

#### UserDefaults Integration

Extensive UserDefaults extension provides persistent configuration storage:

**Authentication Methods:**
```swift
enum AWSAuthMethod: String, CaseIterable {
    case accessKey          // Direct access key authentication
    case profile           // AWS profile-based authentication
    case defaultCredentials // Default AWS credentials
}
```

**Key Properties:**
- `awsRegion: String` - AWS region configuration
- `awsBucket: String` - S3 bucket name
- `awsAccessKeyId: String` - Access key for direct auth
- `awsSecretAccessKey: String` - Secret key for direct auth
- `awsEncryptionSecret: String` - Task data encryption key
- `awsAvoidSnapshots: Bool` - Snapshot optimization flag
- `awsProfileName: String` - AWS profile name
- `awsAuthMethod: AWSAuthMethod` - Selected authentication method
- `isAWSConfigured: Bool` - Configuration status flag

**Helper Methods:**
```swift
func getAWSConfig() -> AWSConfig?              // Returns config for access key auth
func getAWSProfileConfig() -> AWSProfileConfig? // Returns config for profile auth
func validateAWSConfig() -> Bool               // Validates current configuration
func clearAWSConfig()                          // Resets all AWS configuration
```

#### Usage Example

```swift
// Configure AWS with access keys
UserDefaults.standard.awsRegion = "us-west-2"
UserDefaults.standard.awsBucket = "my-tasks-bucket"
UserDefaults.standard.awsAccessKeyId = "AKIAEXAMPLE"
UserDefaults.standard.awsSecretAccessKey = "secret"
UserDefaults.standard.awsEncryptionSecret = "encryption-key"
UserDefaults.standard.awsAuthMethod = .accessKey
UserDefaults.standard.isAWSConfigured = true

// Retrieve configuration
if let config = UserDefaults.standard.getAWSConfig() {
    // Use config for S3 operations
}
```

## Supporting Utilities

### TasksHelper (Sorting and Organization)

Located in `Utilities/TasksHelper.swift`, this enum provides task collection management:

```swift
public enum TCSortType: String {
    case date        // Sort by due date
    case priority    // Sort by priority level
    case defaultSort // Multi-criteria default sorting
}
```

**Sorting Methods:**
- `sortTasksWithSortType(_:sortType:)` - Main sorting dispatcher
- `sortTasksByDefault(_:)` - Complex multi-criteria sorting
- `sortTasksByDate(_:)` - Due date-based sorting
- `sortTasksByPriority(_:)` - Priority-based sorting

**Default Sort Logic:**
1. Status priority: pending > completed > deleted
2. Within same status: due date (earliest first)
3. No due date: priority (highest first)
4. No priority: end of list

### TCError (Error Handling)

Simple error enum for model-related errors:
```swift
public enum TCError: Error {
    case genericError(String)
}
```

## Data Relationships and Usage Patterns

### Model Interactions

1. **TCTask ↔ TCFilter**: Filters are applied to task collections for searching and organization
2. **TCTask ↔ AWSConfig**: Tasks are synchronized to AWS S3 using configuration
3. **TCTask ↔ TasksHelper**: Tasks are sorted and organized using helper methods

### Common Usage Patterns

**Task Creation and Management:**
```swift
// Create new task
let task = TCTask(
    uuid: UUID().uuidString,
    description: "Review pull request",
    status: .pending,
    priority: .high,
    due: Calendar.current.date(byAdding: .day, value: 1, to: Date())
)

// Update task status
var updatedTask = task
updatedTask.status = .completed
```

**Task Filtering:**
```swift
// Create project filter
let filter = TCFilter()
filter.setProject("ios-development")
filter.setStatus(.pending)

// Apply to task collection
let filteredTasks = tasks.filter { task in
    // Apply filter logic based on filter.convertToSqlFilters()
}
```

**Task Organization:**
```swift
var tasks = [TCTask]()
TasksHelper.sortTasksWithSortType(&tasks, sortType: .defaultSort)
```

## Best Practices for AI Agents

### When Working with TCTask:
1. **Always use UUID for task identification** - Don't create custom ID schemes
2. **Preserve existing status workflow** - Follow pending → completed/deleted lifecycle
3. **Handle optional properties carefully** - project, priority, due, and obsidianNote are all optional
4. **Respect Obsidian integration** - Use proper annotation formatting for notes
5. **Use computed properties** - Leverage isCompleted, hasNote, etc. for clarity

### When Working with TCFilter:
1. **Check state flags** - Use didSet* properties to determine active filters
2. **Validate filters** - Always check isValidFilter before applying
3. **Handle SwiftData carefully** - TCFilter is a class, not a struct
4. **SQL pattern awareness** - convertToSqlFilters() returns SQL LIKE patterns

### When Working with AWSConfig:
1. **Use UserDefaults extension** - Don't create custom persistence
2. **Validate configuration** - Always use validateAWSConfig() before operations  
3. **Handle multiple auth methods** - Support accessKey, profile, and defaultCredentials
4. **Secure credential handling** - Be aware these contain sensitive data

### Integration Points:
1. **Follow existing patterns** - Reference TasksHelper for collection operations
2. **Use proper error handling** - Leverage TCError for model-related errors
3. **Maintain consistency** - Follow established naming and structure conventions
4. **Respect architecture** - Models should remain pure data structures without business logic

This documentation provides the foundation for understanding and working with taskchamp's data models. Always reference existing implementations in services and views for usage examples and integration patterns.