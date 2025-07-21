# CLAUDE.md - taskchamp UI Layer Guide

This document provides comprehensive guidance for AI agents working with the taskchamp iOS app's SwiftUI user interface layer.

## Architecture Overview

The view layer follows a **MVVM-inspired architecture** using SwiftUI best practices with reactive patterns through Combine and SwiftUI's property wrappers.

### Key Architectural Principles

1. **State Management**: Heavy use of `@State`, `@Binding`, and `@Environment` for reactive UI updates
2. **Service Integration**: Views interact with business logic through `taskchampShared` services
3. **Navigation**: Uses `NavigationStack` and `PathStore` for programmatic navigation
4. **Modular Design**: Views are broken into logical components with extensions for large views

## Directory Structure

```
taskchamp/Sources/View/
├── TaskListView.swift              # Main task list view (primary screen)
├── TaskListView-Ext.swift          # TaskListView business logic extension
├── CreateTaskView.swift            # New task creation with NLP input
├── EditTaskView.swift              # Task editing interface
├── EditTaskView-Ext.swift          # EditTaskView business logic extension
├── AddFilterView.swift             # Filter creation and management
├── ObsidianSettingsView.swift      # Obsidian integration settings
├── AWSSettingsView.swift           # AWS sync configuration
├── Buttons/
│   └── FormDateToggleButton.swift  # Reusable date/time picker component
├── Cells/
│   └── TaskCellView.swift          # Individual task list item
└── Calendar/
    ├── CalendarView.swift          # Calendar main view with mode switching
    ├── DayCalendarView.swift       # Day view implementation
    ├── WeekCalendarView.swift      # Week view implementation
    └── MonthCalendarView.swift     # Month view implementation
```

## Core View Components

### 1. TaskListView (Primary Interface)

**File**: `/Users/emiller/src/personal/taskchamp/taskchamp/Sources/View/TaskListView.swift`

- **Purpose**: Main task management interface with list, search, and filtering
- **State Management**: 30+ @State properties for comprehensive UI state
- **Key Features**:
  - Pull-to-refresh functionality
  - Swipe actions for task completion/deletion  
  - Multi-select edit mode
  - Search functionality
  - Sorting options (default, date, priority)
  - Filter integration
  - Deep linking support
  - AWS sync integration

**Key Patterns**:
```swift
// State management example
@State var tasks: [TCTask] = []
@State var selection = Set<String>()
@State var editMode: EditMode = .inactive

// Environment dependencies
@Environment(PathStore.self) var pathStore: PathStore
@Environment(\.scenePhase) var scenePhase

// Reactive binding
@Binding var selectedFilter: TCFilter
```

**Common Operations**:
- Task status updates via `updateTasks(_:withStatus:)`
- Database interaction through `DBServiceDEPRECATED.shared`
- Notification management via `NotificationService.shared`

### 2. CreateTaskView & EditTaskView

**Files**: 
- `/Users/emiller/src/personal/taskchamp/taskchamp/Sources/View/CreateTaskView.swift`
- `/Users/emiller/src/personal/taskchamp/taskchamp/Sources/View/EditTaskView.swift`

Both views share similar patterns:

**Key Features**:
- **Natural Language Processing**: Command-line style input using `NLPService.shared`
- **Date/Time Management**: Custom `FormDateToggleButton` components
- **Focus Management**: `@FocusState` for keyboard handling
- **Form Validation**: Input validation with alert feedback
- **Obsidian Integration**: Note creation/opening functionality

**Common Pattern - Date Handling**:
```swift
@State private var didSetDate = false
@State private var didSetTime = false
@State private var isDateShowing = false
@State private var isTimeShowing = false
@State private var due: Date = .init()
@State private var time: Date = .init()

// Usage with FormDateToggleButton
FormDateToggleButton(
    isOnlyTime: false,
    date: $due,
    isSet: $didSetDate,
    isDateShowing: $isDateShowing
)
```

### 3. TaskCellView (List Item Component)

**File**: `/Users/emiller/src/personal/taskchamp/taskchamp/Sources/View/Cells/TaskCellView.swift`

- **Purpose**: Reusable component for displaying individual tasks
- **Features**: Status-aware styling, priority indicators, project display
- **Styling Patterns**:
  - Strikethrough for completed/deleted tasks
  - Color coding for task status (red for deleted, secondary for completed)
  - Priority-based color coding (red: high, orange: medium, green: low)

### 4. Calendar Views

**Base File**: `/Users/emiller/src/personal/taskchamp/taskchamp/Sources/View/Calendar/CalendarView.swift`

**Architecture**:
- **Mode Switching**: Day/Week/Month views with segmented picker
- **Drag & Drop**: Task rescheduling support in Day/Week views
- **Date Navigation**: Previous/next controls with animated transitions
- **Task Filtering**: Respects global filter settings

**Pattern - Mode-based View Switching**:
```swift
enum CalendarMode: String, CaseIterable {
    case day = "Day"
    case week = "Week" 
    case month = "Month"
    
    var icon: String { /* SF Symbols mapping */ }
}

// View switching in body
Group {
    switch calendarMode {
    case .day: DayCalendarView(...)
    case .week: WeekCalendarView(...)
    case .month: MonthCalendarView(...)
    }
}
```

## Common UI Patterns

### 1. State-Driven UI Updates

**Pattern**: Use `@State` with `withAnimation` for smooth transitions
```swift
@State var isShowingCreateTaskView = false

// Triggering with animation
Button("New task") {
    withAnimation {
        isShowingCreateTaskView.toggle()
    }
}
```

### 2. Sheet Presentations

**Standard Pattern**:
```swift
.sheet(isPresented: $isShowingCreateTaskView, onDismiss: {
    updateTasks() // Refresh data when dismissed
}) {
    CreateTaskView()
}
```

### 3. Navigation Integration

**PathStore Usage**:
```swift
@Environment(PathStore.self) var pathStore: PathStore

// Programmatic navigation
.navigationDestination(for: TCTask.self) { task in
    EditTaskView(task: task)
}

// Deep linking
pathStore.path.append(task)
```

### 4. Toolbar Customization

**Multi-placement Toolbar**:
```swift
.toolbar {
    ToolbarItemGroup(placement: .bottomBar) { /* Bottom content */ }
    ToolbarItemGroup(placement: .topBarTrailing) { /* Top right */ }
    ToolbarItemGroup(placement: .topBarLeading) { /* Top left */ }
    ToolbarItem(placement: .keyboard) { /* Keyboard accessory */ }
}
```

### 5. Swipe Actions

**Standard Implementation**:
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button { /* Complete action */ } label: {
        Label("Done", systemImage: SFSymbols.checkmark.rawValue)
    }
    .tint(.green)
}
.swipeActions(edge: .leading, allowsFullSwipe: true) {
    Button(role: .destructive) { /* Delete action */ } label: {
        Label("Delete", systemImage: SFSymbols.trash.rawValue)
    }
}
```

## Design System & Styling

### 1. SF Symbols Integration

**Usage**: Access through `SFSymbols` enum from `taskchampShared`
```swift
// Available symbols (partial list)
SFSymbols.plusCircleFill.rawValue    // "plus.circle.fill"
SFSymbols.checkmark.rawValue         // "checkmark"
SFSymbols.trash.rawValue             // "trash"
SFSymbols.ellipsisCircle.rawValue    // "ellipsis.circle"
SFSymbols.obsidian.rawValue          // "suit.diamond.fill"
```

### 2. Color Theming

**System Color Usage**:
- `.tint` for accent colors
- `.secondary` for subdued text
- `.red`, `.orange`, `.green` for priority indicators
- `Color(asset: TaskchampAsset.Assets.accentColor)` for branded colors

### 3. Typography Patterns

**Common Font Styles**:
- `.font(.system(.body, design: .monospaced))` for command-line inputs
- `.font(.subheadline.italic())` for project names
- `.font(.subheadline)` for metadata (dates, priorities)
- `.bold()` for emphasis

### 4. Layout Utilities

**Custom View Extension**: Available via `taskchamp/Sources/Extensions/View-Ext.swift`
```swift
extension View {
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View
}

// Usage example
.if(task.status != .deleted) {
    $0.swipeActions(edge: .trailing) { /* actions */ }
}
```

## Service Integration Patterns

### 1. Database Operations

**Legacy Service** (Current): `DBServiceDEPRECATED.shared`
- Used in TaskListView, CreateTaskView, EditTaskView
- **Migration Note**: Avoid modifying this service - prefer `TaskchampionService.shared` for new features

**New Service** (Future): `TaskchampionService.shared`
- Currently used for AWS sync operations only
- Preferred for new database features

### 2. Notification Management

**Pattern**:
```swift
// Request authorization
NotificationService.shared.requestAuthorization()

// Create task reminders
NotificationService.shared.createReminderForTask(task: task)

// Remove notifications
NotificationService.shared.removeNotifications(for: Array(uuids))
```

### 3. Natural Language Processing

**Usage in Create/Filter Views**:
```swift
let nlpTask = NLPService.shared.createTask(from: input)
let nlpFilter = NLPService.shared.createFilter(from: input)
```

### 4. External Integration

**Obsidian URL Schemes**:
```swift
// Open existing note
"obsidian://open?vault=\(vaultName)&file=\(notePath)"

// Create new note  
"obsidian://new?vault=\(vaultName)&file=\(notePath)"
```

## Data Flow Patterns

### 1. Task Updates

**Standard Flow**:
1. User interaction triggers action
2. Update database via service
3. Refresh UI via `updateTasks()`
4. Update notifications if needed

**Example**:
```swift
func updateTask() {
    let task = TCTask(/* updated properties */)
    do {
        try DBServiceDEPRECATED.shared.updateTask(task)
        NotificationService.shared.createReminderForTask(task: task)
        dismiss()
    } catch {
        // Show error alert
        isShowingAlert = true
        alertMessage = "Task failed to update. Please try again."
    }
}
```

### 2. Filter Management

**Pattern**: Filter changes trigger task list updates
```swift
.onChange(of: selectedFilter) {
    updateTasks()
}

// Save to UserDefaults for persistence
let res = try JSONEncoder().encode(selectedFilter)
UserDefaults.standard.set(res, forKey: "selectedFilter")
```

### 3. Deep Linking

**URL Scheme**: `taskchamp://task/{uuid}` or `taskchamp://task/new`
```swift
func handleDeepLink(url: URL) {
    guard url.scheme == "taskchamp", url.host == "task" else { return }
    
    let uuidString = url.pathComponents[1]
    if uuidString == "new" {
        isShowingCreateTaskView = true
    } else {
        let task = try DBServiceDEPRECATED.shared.getTask(uuid: uuidString)
        pathStore.path.append(task)
    }
}
```

## Form Patterns & Validation

### 1. Input Validation

**Common Pattern**:
```swift
@State private var isShowingAlert = false
@State private var alertTitle = ""
@State private var alertMessage = ""

func validateAndSave() {
    if description.isEmpty {
        isShowingAlert = true
        alertTitle = "Missing field"
        alertMessage = "Please enter a task name"
        return
    }
    // Process valid input
}

// Alert presentation
.alert(isPresented: $isShowingAlert) {
    Alert(title: Text(alertTitle), message: Text(alertMessage), 
          dismissButton: .default(Text("OK")))
}
```

### 2. Focus Management

**Keyboard Handling**:
```swift
@FocusState private var isFocused: Bool

// Keyboard toolbar
ToolbarItem(placement: .keyboard) {
    HStack {
        Spacer()
        Button("Done") { isFocused = false }
    }
}
```

### 3. Date Selection Components

**FormDateToggleButton Usage**:
```swift
// Date picker
FormDateToggleButton(
    isOnlyTime: false,
    date: $due,
    isSet: $didSetDate,
    isDateShowing: $isDateShowing
)

// Time picker  
FormDateToggleButton(
    isOnlyTime: true,
    date: $time,
    isSet: $didSetTime,
    isDateShowing: $isTimeShowing
)

// Logic for dependent state
.onChange(of: didSetTime) { _, newValue in
    if didSetTime {
        didSetDate = true // Time requires date
        withAnimation { isTimeShowing = newValue }
    }
}
```

## Performance & Animation Patterns

### 1. List Animations

**Smooth Updates**:
```swift
.animation(.default, value: sortType)
.animation(.default, value: searchText)

// Data updates
if newTasks == tasks { return } // Prevent unnecessary updates
withAnimation { tasks = newTasks }
```

### 2. Content States

**Empty State Handling**:
```swift
.overlay(
    Group {
        if tasks.isEmpty {
            ContentUnavailableView {
                Label("No new tasks", systemImage: "bolt.heart")
            } description: {
                Text("Use this time to relax or add new tasks!")
            } actions: {
                Button("New task") { isShowingCreateTaskView.toggle() }
                .buttonStyle(.borderedProminent)
            }
        }
    }
)
```

### 3. Async Operations

**Task Management**:
```swift
func performAWSSync() {
    guard !isSyncInProgress else { return }
    isSyncInProgress = true
    
    Task {
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            await MainActor.run {
                syncMessage = "✅ AWS sync completed successfully!"
                isSyncInProgress = false
                updateTasks()
            }
        } catch {
            await MainActor.run {
                syncMessage = "❌ AWS sync failed: \(error.localizedDescription)"
                isSyncInProgress = false
            }
        }
    }
}
```

## Testing & Debugging Patterns

### 1. SwiftUI Previews

**Standard Preview Setup**:
```swift
#Preview {
    CalendarView(selectedFilter: .constant(.defaultFilter))
}
```

### 2. Error Handling

**Consistent Error Pattern**:
```swift
do {
    try performOperation()
} catch {
    isShowingAlert = true
    alertTitle = "There was an error"
    alertMessage = "Operation failed. Please try again."
    print(error) // Debug logging
}
```

## Migration Guidelines

### Database Service Transition

**Current State**: Views primarily use `DBServiceDEPRECATED.shared`
**Future Direction**: Transition to `TaskchampionService.shared`

**Do**:
- Use `TaskchampionService.shared` for new features
- Reference existing patterns for consistency
- Maintain notification integration when updating tasks

**Don't**:
- Modify `DBServiceDEPRECATED` implementation
- Create new database service abstractions
- Break existing task update flows

### AWS Integration

**Current Implementation**: Fully integrated in TaskListView and AWSSettingsView
- Test functionality via AWSSettingsView
- Sync operations run asynchronously with progress indicators
- Error handling with user-friendly messages

## Best Practices for AI Development

### 1. Pattern Recognition

**Before implementing new views**:
1. Check existing views for similar functionality
2. Reuse established patterns for consistency
3. Follow the service integration approach
4. Maintain the established navigation patterns

### 2. State Management

**Guidelines**:
- Use `@State` for local view state
- Use `@Binding` for parent-child data flow
- Use `@Environment` for app-wide dependencies
- Group related state properties together

### 3. User Experience

**Key Principles**:
- Provide loading states for async operations
- Show meaningful error messages
- Use animations for state transitions
- Implement proper keyboard handling
- Support pull-to-refresh where appropriate

### 4. Code Organization

**File Structure**:
- Main view logic in primary `.swift` file
- Business logic in `-Ext.swift` extension files
- Reusable components in subdirectories (`Buttons/`, `Cells/`)
- Related views grouped in subdirectories (`Calendar/`)

### 5. Integration Points

**Service Dependencies** (from `taskchampShared`):
- `DBServiceDEPRECATED.shared` - Legacy database operations
- `TaskchampionService.shared` - New database service (AWS sync)
- `NotificationService.shared` - Local notifications
- `NLPService.shared` - Natural language processing
- `FileService.shared` - iCloud Drive operations

**Models**:
- `TCTask` - Core task model
- `TCFilter` - Task filtering model
- `PathStore` - Navigation state management

This comprehensive guide should enable AI agents to effectively work with the taskchamp UI layer while maintaining consistency with established patterns and architectural decisions.