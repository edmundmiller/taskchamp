import XCTest
@testable import taskchampShared
import Taskchampion

/// Tests for TaskChampion CRUD operations - ensuring getAllTasks() and other operations work
class TaskChampionCRUDTests: XCTestCase {
    
    var tempDbPath: String!
    
    override func setUp() {
        super.setUp()
        // Create a temporary database file for testing
        let tempDir = NSTemporaryDirectory()
        tempDbPath = "\(tempDir)taskchampion_test_\(UUID().uuidString).db"
        print("🧪 Test DB path: \(tempDbPath)")
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up the temporary database file
        try? FileManager.default.removeItem(atPath: tempDbPath)
    }
    
    // MARK: - Test Get All Tasks
    
    func testGetAllTasksReturnsEmptyArrayForNewDatabase() throws {
        print("🧪 Testing getAllTasks() returns empty array for new database...")
        
        // Create a new replica
        let replica = new_replica_on_disk(tempDbPath)
        
        // Get all tasks - should be empty
        let tasks = try replica.getAllTasks()
        XCTAssertEqual(tasks.count, 0)
        print("✅ Empty database returns 0 tasks")
    }
    
    func testGetAllTasksReturnsCreatedTasks() throws {
        print("🧪 Testing getAllTasks() returns created tasks...")
        
        // Create a new replica
        let replica = new_replica_on_disk(tempDbPath)
        
        // Create multiple tasks using the low-level API
        let uuid1 = uuid_v4()
        let task1 = try replica.create_task(uuid1.to_string().toString())
        var ops = task1.set_property("description", "Test task 1")
        ops.append(contentsOf: task1.set_property("project", "TestProject"))
        ops.append(contentsOf: task1.set_property("priority", "high"))
        ops.append(contentsOf: task1.set_property("status", "pending"))
        try replica.commit_operations(ops)
        
        let uuid2 = uuid_v4()
        let task2 = try replica.create_task(uuid2.to_string().toString())
        ops = task2.set_property("description", "Test task 2")
        ops.append(contentsOf: task2.set_property("status", "pending"))
        try replica.commit_operations(ops)
        
        let uuid3 = uuid_v4()
        let task3 = try replica.create_task(uuid3.to_string().toString())
        ops = task3.set_property("description", "Completed task")
        ops.append(contentsOf: task3.set_property("status", "completed"))
        try replica.commit_operations(ops)
        
        // Get all tasks
        let tasks = try replica.getAllTasks()
        XCTAssertEqual(tasks.count, 3)
        print("✅ Created 3 tasks, getAllTasks() returned \(tasks.count) tasks")
        
        // Verify task contents
        let descriptions = tasks.map { $0.description }
        XCTAssertTrue(descriptions.contains("Test task 1"))
        XCTAssertTrue(descriptions.contains("Test task 2"))
        XCTAssertTrue(descriptions.contains("Completed task"))
        
        // Verify task with project and priority
        if let task1Data = tasks.first(where: { $0.description == "Test task 1" }) {
            XCTAssertEqual(task1Data.project, "TestProject")
            XCTAssertEqual(task1Data.priority, "high")
            XCTAssertEqual(task1Data.status, "pending")
        } else {
            XCTFail("Could not find task 1")
        }
        
        print("✅ Task properties verified successfully")
    }
    
    func testGetAllTasksFiltersDeletedTasks() throws {
        print("🧪 Testing getAllTasks() handles deleted tasks...")
        
        // Create a new replica
        let replica = new_replica_on_disk(tempDbPath)
        
        // Create a task
        let uuid = uuid_v4()
        let task = try replica.create_task(uuid.to_string().toString())
        var ops = task.set_property("description", "Task to be deleted")
        ops.append(contentsOf: task.set_property("status", "pending"))
        try replica.commit_operations(ops)
        
        // Verify task exists
        var tasks = try replica.getAllTasks()
        XCTAssertEqual(tasks.count, 1)
        
        // Mark task as deleted
        ops = task.set_property("status", "deleted")
        try replica.commit_operations(ops)
        
        // Get all tasks - deleted tasks should still be returned
        tasks = try replica.getAllTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.status, "deleted")
        print("✅ Deleted task is included in getAllTasks() result")
    }
    
    // MARK: - Test Create Task
    
    func testCreateTaskWithAllProperties() throws {
        print("🧪 Testing createTask() with all properties...")
        
        // Create a new replica
        let replica = new_replica_on_disk(tempDbPath)
        
        // Create task with all properties
        let uuid = UUID().uuidString
        let description = "Complete task with all properties"
        let project = "TestProject"
        let priority = "medium"
        let due = "2024-12-31T23:59:59Z"
        let obsidianNote = "[[TaskNote]]"
        
        try replica.createTask(
            uuid: uuid,
            description: description,
            project: project,
            priority: priority,
            due: due,
            obsidianNote: obsidianNote
        )
        
        // Verify task was created
        let tasks = try replica.getAllTasks()
        XCTAssertEqual(tasks.count, 1)
        
        let createdTask = tasks.first!
        XCTAssertEqual(createdTask.uuid, uuid)
        XCTAssertEqual(createdTask.description, description)
        XCTAssertEqual(createdTask.project, project)
        XCTAssertEqual(createdTask.priority, priority)
        XCTAssertEqual(createdTask.due, due)
        XCTAssertEqual(createdTask.obsidianNote, obsidianNote)
        XCTAssertEqual(createdTask.status, "pending")
        
        print("✅ Task created with all properties successfully")
    }
    
    // MARK: - Test Update Task
    
    func testUpdateTaskModifiesExistingTask() throws {
        print("🧪 Testing updateTask() modifies existing task...")
        
        // Create a new replica
        let replica = new_replica_on_disk(tempDbPath)
        
        // Create initial task
        let uuid = UUID().uuidString
        try replica.createTask(
            uuid: uuid,
            description: "Initial description"
        )
        
        // Update the task
        try replica.updateTask(
            uuid: uuid,
            description: "Updated description",
            status: "completed",
            project: "UpdatedProject",
            priority: "low"
        )
        
        // Verify task was updated
        let tasks = try replica.getAllTasks()
        XCTAssertEqual(tasks.count, 1)
        
        let updatedTask = tasks.first!
        XCTAssertEqual(updatedTask.uuid, uuid)
        XCTAssertEqual(updatedTask.description, "Updated description")
        XCTAssertEqual(updatedTask.status, "completed")
        XCTAssertEqual(updatedTask.project, "UpdatedProject")
        XCTAssertEqual(updatedTask.priority, "low")
        
        print("✅ Task updated successfully")
    }
    
    // MARK: - Test Get Task
    
    func testGetTaskReturnsSpecificTask() throws {
        print("🧪 Testing getTask() returns specific task...")
        
        // Create a new replica
        let replica = new_replica_on_disk(tempDbPath)
        
        // Create multiple tasks
        let uuid1 = UUID().uuidString
        try replica.createTask(uuid: uuid1, description: "Task 1")
        
        let uuid2 = UUID().uuidString
        try replica.createTask(uuid: uuid2, description: "Task 2")
        
        // Get specific task
        let task = try replica.getTask(uuid: uuid2)
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.uuid, uuid2)
        XCTAssertEqual(task?.description, "Task 2")
        
        print("✅ getTask() returned correct task")
    }
    
    func testGetTaskReturnsNilForNonExistentTask() throws {
        print("🧪 Testing getTask() returns nil for non-existent task...")
        
        // Create a new replica
        let replica = new_replica_on_disk(tempDbPath)
        
        // Try to get non-existent task
        let task = try replica.getTask(uuid: "non-existent-uuid")
        XCTAssertNil(task)
        
        print("✅ getTask() returned nil for non-existent task")
    }
    
    // MARK: - Integration Tests
    
    func testTaskchampionServiceGetTasksIntegration() throws {
        print("🧪 Testing TaskchampionService.getTasks() integration...")
        
        // Initialize service with test database
        TaskchampionService.shared.setDbUrl(tempDbPath)
        
        // Create tasks using low-level API
        let replica = new_replica_on_disk(tempDbPath)
        
        // Create pending task
        let uuid1 = uuid_v4()
        let task1 = try replica.create_task(uuid1.to_string().toString())
        var ops = task1.set_property("description", "Pending task")
        ops.append(contentsOf: task1.set_property("status", "pending"))
        ops.append(contentsOf: task1.set_property("project", "Work"))
        try replica.commit_operations(ops)
        
        // Create completed task
        let uuid2 = uuid_v4()
        let task2 = try replica.create_task(uuid2.to_string().toString())
        ops = task2.set_property("description", "Completed task")
        ops.append(contentsOf: task2.set_property("status", "completed"))
        try replica.commit_operations(ops)
        
        // Get tasks via service
        let allTasks = try TaskchampionService.shared.getTasks()
        XCTAssertEqual(allTasks.count, 2)
        
        // Test filtering
        let filter = TCFilter()
        filter.status = .pending
        filter.didSetStatus = true
        
        let pendingTasks = try TaskchampionService.shared.getTasks(filter: filter)
        XCTAssertEqual(pendingTasks.count, 1)
        XCTAssertEqual(pendingTasks.first?.description, "Pending task")
        
        print("✅ TaskchampionService integration test passed")
    }
    
    func testRoundTripPersistence() throws {
        print("🧪 Testing round-trip persistence...")
        
        // Create tasks with first replica
        var replica = new_replica_on_disk(tempDbPath)
        try replica.createTask(uuid: UUID().uuidString, description: "Persistent task 1")
        try replica.createTask(uuid: UUID().uuidString, description: "Persistent task 2")
        
        // Create new replica pointing to same database
        replica = new_replica_on_disk(tempDbPath)
        
        // Verify tasks persist
        let tasks = try replica.getAllTasks()
        XCTAssertEqual(tasks.count, 2)
        
        let descriptions = tasks.map { $0.description }
        XCTAssertTrue(descriptions.contains("Persistent task 1"))
        XCTAssertTrue(descriptions.contains("Persistent task 2"))
        
        print("✅ Tasks persist across replica instances")
    }
}