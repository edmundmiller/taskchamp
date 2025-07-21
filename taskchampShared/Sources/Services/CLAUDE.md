# Service Layer Architecture Guide

This document provides comprehensive guidance for AI agents working with the business logic layer in the taskchamp iOS app. Follow these patterns and conventions when implementing features that interact with the service layer.

## Architecture Overview

The service layer follows a **singleton pattern** with dependency injection through static `shared` instances. All services are designed as lightweight facades that handle specific domains of functionality while maintaining clean separation of concerns.

### Core Design Principles

1. **Single Responsibility**: Each service handles one specific domain
2. **Singleton Pattern**: All services use `Service.shared` for global access
3. **Error Handling**: Consistent error propagation using `TCError`
4. **Logging**: Structured logging with `os.log` and service-specific categories
5. **Async/Await**: Progressive migration to async patterns where appropriate

## Migration Status: CRITICAL INFORMATION

⚠️ **The codebase is currently in migration from legacy SQLite to TaskChampion Rust library**

### Services to MODIFY (Stable):
- ✅ **NotificationService**: Local notifications - fully stable
- ✅ **NLPService**: Natural language processing - fully stable  
- ✅ **FileService**: iCloud Drive operations - fully stable

### Services to AVOID MODIFYING (Under Migration):
- 🚫 **DBServiceDEPRECATED**: Legacy SQLite service (lines 7-301 are commented out)
- ⚠️ **TaskchampionService**: New Rust-based service (incomplete async API)
- ⚠️ **DBService**: Unified facade (calls non-existent async methods)

### Current State Issues:
The unified `DBService` class (lines 303-377) calls async methods on `TaskchampionService.shared` that don't exist yet:
```swift
// These methods are called but not implemented:
TaskchampionService.shared.getTasks(filters:) async throws -> [TCTask]
TaskchampionService.shared.getTask(uuid:) async throws -> TCTask
TaskchampionService.shared.updateTask(_:) async throws
TaskchampionService.shared.createTask(task:) async throws
```

## Service Architecture Details

### 1. NotificationService 🟢 STABLE

**File**: `NotificationService.swift`  
**Purpose**: Handles local notifications for task reminders  
**Pattern**: Singleton with UNUserNotificationCenter delegate

```swift
public class NotificationService: NSObject {
    public static let shared = NotificationService()
    let center = UNUserNotificationCenter.current()
}
```

#### Key Responsibilities:
- **Authorization**: Request notification permissions
- **Scheduling**: Create calendar-based task reminders  
- **Management**: Remove/update existing notifications
- **Deep Linking**: Handle notification taps with custom URL schemes

#### Public API:
```swift
// Authorization
func requestAuthorization(completionHandler: @escaping (Bool, Error?) -> Void)

// Notification Management
func removeAllNotifications()
func removeNotifications(for uuids: [String])
func deleteReminderForTask(task: TCTask)

// Task Integration
func createReminderForTasks(tasks: [TCTask]) async
func createReminderForTask(task: TCTask)
```

#### Integration Patterns:
```swift
// Deep link handling through NotificationCenter
NotificationCenter.default.post(name: .TCTappedDeepLinkNotification, object: viewURL)

// Task URL scheme: "taskchamp://task/{uuid}"
content.userInfo = ["deepLink": task.url.description]
```

### 2. NLPService 🟢 STABLE

**File**: `NLPService.swift`  
**Purpose**: Natural language processing for task creation and filtering  
**Dependencies**: SoulverCore for date parsing

```swift
public class NLPService {
    public static let shared = NLPService()
}
```

#### Key Responsibilities:
- **Task Parsing**: Extract structured data from natural language input
- **Filter Creation**: Build `TCFilter` objects from search strings
- **Property Extraction**: Parse `prio:`, `project:`, `due:`, `status:` tags

#### Public API:
```swift
func createTask(from input: String) -> TCTask
func createFilter(from input: String) -> TCFilter
```

#### Parsing Patterns:
The service uses regex-based extraction with a common pattern:
```swift
func extractValue(after tag: String, from input: inout String, isFilter: Bool = false) -> String?
```

**Supported Tags**:
- `prio:high|medium|low` → TCTask.Priority
- `project:ProjectName` → String  
- `due:tomorrow|2023-12-25|next week` → Date (via SoulverCore)
- `status:pending|completed|deleted` → TCTask.Status (filters only)

#### Usage Examples:
```swift
// Creates task with extracted metadata
let task = NLPService.shared.createTask(from: "Buy groceries prio:high project:Shopping due:tomorrow")

// Creates filter for search/display
let filter = NLPService.shared.createFilter(from: "status:pending project:Work")
```

### 3. FileService 🟢 STABLE

**File**: `FileService.swift`  
**Purpose**: iCloud Drive database file management  
**Integration**: Works with TaskChampion database files

```swift
public class FileService {
    public static let shared = FileService()
}
```

#### Key Responsibilities:
- **iCloud Integration**: Check iCloud availability and access container
- **Database Location**: Manage TaskChampion database file location
- **File Operations**: Copy initial database, create directories

#### Public API:
```swift
func isICloudAvailable() -> Bool
func getDestinationPath() throws -> String  
func copyDatabaseIfNeededAndGetDestinationPath() throws -> String
```

#### File Structure:
```
iCloud Container/
├── Documents/
│   └── task/
│       └── taskchampion.sqlite3
```

#### Integration Pattern:
```swift
// Typical usage in app initialization
do {
    let dbPath = try FileService.shared.copyDatabaseIfNeededAndGetDestinationPath()
    DBService.shared.setDbUrl(dbPath)
} catch {
    // Handle file system errors
}
```

### 4. DBServiceDEPRECATED 🚫 DO NOT MODIFY

**File**: `DBService.swift` (lines 7-301, commented out)  
**Status**: Completely disabled due to SQLite.swift dependency issues  
**Migration**: Being replaced by TaskchampionService

**Original Responsibilities** (now deprecated):
- SQLite database operations
- Task CRUD operations  
- SQL filter generation
- Widget timeline updates

### 5. TaskchampionService ⚠️ MIGRATION IN PROGRESS

**File**: `TaskchampionService.swift`  
**Purpose**: Interface to TaskChampion Rust library  
**Status**: Synchronous API complete, async API missing

```swift
public class TaskchampionService {
    public static let shared = TaskchampionService()
    private var replica: Replica?  // From Taskchampion import
}
```

#### Current Implementation (Synchronous):
```swift
// Database Setup
func setDbUrl(_ dbUrl: String)

// Task Operations  
func getTasks(sortType: TasksHelper.TCSortType, filter: TCFilter) throws -> [TCTask]
func getTask(uuid: String) throws -> TCTask
func updateTask(_ task: TCTask) throws
func createTask(task: TCTask) throws

// Batch Operations
func togglePendingTasksStatus(uuids: Set<String>) throws
func updatePendingTasks(_ uuids: Set<String>, withStatus: TCTask.Status) throws

// AWS Sync
func syncToAWS(config: AWSConfig) throws
func syncToAWS(profileConfig: AWSProfileConfig) throws  
func syncToAWSWithDefaultCredentials(...) throws
func syncToAWSFromUserDefaults() throws

// Sync Status
func getLocalOperationsCount() throws -> UInt32
func needsSync() throws -> Bool
```

#### Missing Async API:
The unified `DBService` expects these async methods that don't exist:
```swift
// ❌ NOT IMPLEMENTED - DO NOT CALL DIRECTLY
func getTasks(filters: [String]) async throws -> [TCTask]
func getTask(uuid: String) async throws -> TCTask  
func updateTask(_ task: TCTask) async throws
func createTask(task: TCTask) async throws
```

#### TaskChampion Integration Patterns:
```swift
// Operations are batched and committed atomically
var operations = new_operations()
let statusOps = taskData.set_property("status", newStatus)
operations.append_vec(statusOps)
try replica.commit_operations(operations)

// TaskChampion properties map to TCTask fields
taskData.set_property("description", task.description)
taskData.set_property("project", task.project ?? "")
taskData.set_property("priority", task.priority?.rawValue ?? "")
taskData.set_property("due", String(Int(due.timeIntervalSince1970)))
```

### 6. DBService (Unified Facade) ⚠️ INCOMPLETE

**File**: `DBService.swift` (lines 303-377)  
**Purpose**: Provides unified interface during migration  
**Status**: Calls non-existent async methods - DO NOT USE

```swift
public class DBService {
    public static let shared = DBService()
}
```

**Current Issues**:
- Calls `async` methods on TaskchampionService that don't exist
- Will cause runtime crashes if used
- Intended as migration compatibility layer

## Data Models Integration

### TCTask Structure
```swift
public struct TCTask: Codable, Hashable, Identifiable {
    public let uuid: String
    public var project: String?
    public var description: String  
    public var status: Status        // .pending, .completed, .deleted
    public var priority: Priority?   // .none, .low, .medium, .high
    public var due: Date?
    public var obsidianNote: String?
    public var noteAnnotationKey: String?
}
```

### TCFilter Structure  
```swift
public class TCFilter: Codable {
    public var project: String = ""
    public var status = TCTask.Status.deleted
    public var priority = TCTask.Priority.none  
    public var due = Date(timeIntervalSince1970: 0)
    
    // State tracking
    public var didSetPrio: Bool = false
    public var didSetProject: Bool = false
    public var didSetDue: Bool = false
    public var didSetStatus: Bool = false
}
```

## Common Patterns

### Error Handling
All services use consistent error propagation:
```swift
public enum TCError: Error {
    case genericError(String)
}

// Usage pattern
throw TCError.genericError("Descriptive error message")
```

### Logging Pattern
```swift
private let logger = Logger(subsystem: "com.mav.taskchamp", category: "ServiceName")

// Usage
logger.info("Operation completed successfully")
logger.error("Operation failed: \(error.localizedDescription)")
logger.debug("Debug information: \(details)")
```

### Widget Integration
Services that modify tasks should update widgets:
```swift
import WidgetKit

// After task modifications
WidgetCenter.shared.reloadAllTimelines()
```

## AWS Sync Configuration

TaskchampionService integrates with AWS S3 for sync using multiple auth methods:

### AWSConfig Models
```swift
public struct AWSConfig: Codable {
    public let region: String
    public let bucket: String  
    public let accessKeyId: String
    public let secretAccessKey: String
    public let encryptionSecret: String
    public let avoidSnapshots: Bool
}

public struct AWSProfileConfig: Codable {
    public let region: String
    public let bucket: String
    public let profileName: String
    public let encryptionSecret: String  
    public let avoidSnapshots: Bool
}
```

### UserDefaults Integration
UserDefaults extensions provide configuration management:
```swift
public extension UserDefaults {
    enum AWSAuthMethod: String, CaseIterable {
        case accessKey, profile, defaultCredentials
    }
    
    var isAWSConfigured: Bool { get set }
    var awsAuthMethod: AWSAuthMethod { get set }
    
    func getAWSConfig() -> AWSConfig?
    func getAWSProfileConfig() -> AWSProfileConfig?
    func validateAWSConfig() -> Bool
    func clearAWSConfig()
}
```

## Helper Utilities

### TasksHelper
```swift
public enum TasksHelper {
    public enum TCSortType: String {
        case date, priority, defaultSort
    }
    
    public static func sortTasksWithSortType(_ tasks: inout [TCTask], sortType: TCSortType)
}
```

### SFSymbols  
Centralized SF Symbols constants for UI consistency:
```swift
public enum SFSymbols: String {
    case plusCircleFill = "plus.circle.fill"
    case checkmarkCircleFill = "checkmark.circle.fill"
    case obsidian = "suit.diamond.fill"
    // ... etc
}
```

## Development Guidelines

### DO:
1. ✅ Use stable services (NotificationService, NLPService, FileService)
2. ✅ Follow singleton pattern with `.shared` instances
3. ✅ Use consistent error handling with TCError
4. ✅ Add structured logging with os.log
5. ✅ Call `WidgetCenter.shared.reloadAllTimelines()` after task changes
6. ✅ Reference existing model patterns (TCTask, TCFilter)

### DON'T:
1. 🚫 Modify DBServiceDEPRECATED (commented out/deprecated)
2. 🚫 Use the unified DBService (calls non-existent methods)  
3. 🚫 Add async methods to TaskchampionService without careful planning
4. 🚫 Create new service singletons without following established patterns
5. 🚫 Bypass error handling or logging conventions

### Migration Strategy:
If you need async database operations:
1. Implement missing async methods in TaskchampionService  
2. Ensure they properly wrap existing synchronous methods
3. Test unified DBService integration
4. Consider using synchronous TaskchampionService methods directly instead

### Example Implementation Pattern:
```swift
// New service following established patterns
public class MyNewService {
    public static let shared = MyNewService()
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "MyNewService")
    
    private init() {}
    
    public func performOperation() throws -> Result {
        do {
            logger.info("Starting operation")
            let result = // ... implementation
            logger.debug("Operation completed successfully")
            return result
        } catch {
            logger.error("Operation failed: \(error.localizedDescription)")
            throw TCError.genericError("Operation failed: \(error.localizedDescription)")
        }
    }
}
```

This architecture provides a solid foundation for task management while maintaining clean separation of concerns during the ongoing migration from SQLite to TaskChampion.