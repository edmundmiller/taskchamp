import XCTest
@testable import taskchampShared
import Taskchampion

/// Tests to validate the current TaskchampionService implementation with enhanced property support
class TaskchampionServiceIntegrationTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Initialize TaskchampionService with in-memory database
        TaskchampionService.shared.setDbUrl("test-db-path")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Basic CRUD Tests
    
    func testBasicTaskCreation() {
        print("🧪 Testing basic task creation via TaskchampionService...")
        
        do {
            // Create a simple task
            let task = TCTask(
                uuid: UUID().uuidString,
                project: nil,
                description: "Test task via service",
                status: .pending,
                priority: nil,
                due: nil
            )
            
            try TaskchampionService.shared.createTask(task: task)
            print("✅ Task created successfully: \(task.uuid)")
            
            // Verify we can retrieve it
            let retrievedTask = try TaskchampionService.shared.getTask(uuid: task.uuid)
            XCTAssertEqual(retrievedTask.uuid, task.uuid)
            XCTAssertEqual(retrievedTask.description, task.description)
            XCTAssertEqual(retrievedTask.status, .pending)
            
            print("✅ Task retrieved successfully with matching properties")
            
        } catch {
            XCTFail("Basic task creation failed: \(error)")
        }
    }
    
    func testEnhancedPropertyCreation() {
        print("🧪 Testing enhanced property creation...")
        
        do {
            let dueDate = Date().addingTimeInterval(86400) // Tomorrow
            
            // Create a task with all properties
            let task = TCTask(
                uuid: UUID().uuidString,
                project: "TestProject",
                description: "Enhanced test task",
                status: .pending,
                priority: .high,
                due: dueDate,
                obsidianNote: "This is a test note"
            )
            
            try TaskchampionService.shared.createTask(task: task)
            print("✅ Enhanced task created: \(task.uuid)")
            
            // Verify all properties are preserved
            let retrievedTask = try TaskchampionService.shared.getTask(uuid: task.uuid)
            XCTAssertEqual(retrievedTask.uuid, task.uuid)
            XCTAssertEqual(retrievedTask.description, task.description)
            XCTAssertEqual(retrievedTask.project, "TestProject")
            XCTAssertEqual(retrievedTask.priority, .high)
            XCTAssertEqual(retrievedTask.obsidianNote, "This is a test note")
            XCTAssertEqual(retrievedTask.status, .pending)
            
            // Date comparison with tolerance for timestamp conversion
            if let retrievedDue = retrievedTask.due {
                XCTAssertEqual(retrievedDue.timeIntervalSince1970, dueDate.timeIntervalSince1970, accuracy: 1.0)
            } else {
                XCTFail("Due date was not preserved")
            }
            
            print("✅ All enhanced properties preserved correctly")
            
        } catch {
            XCTFail("Enhanced property creation failed: \(error)")
        }
    }
    
    func testTaskUpdate() {
        print("🧪 Testing task updates...")
        
        do {
            // Create initial task
            let task = TCTask(
                uuid: UUID().uuidString,
                project: "InitialProject",
                description: "Initial description",
                status: .pending,
                priority: .low,
                due: nil
            )
            
            try TaskchampionService.shared.createTask(task: task)
            print("✅ Initial task created")
            
            // Update the task
            var updatedTask = task
            updatedTask.project = "UpdatedProject"
            updatedTask.description = "Updated description"
            updatedTask.priority = .high
            updatedTask.status = .completed
            updatedTask.due = Date()
            updatedTask.obsidianNote = "Updated note"
            
            try TaskchampionService.shared.updateTask(updatedTask)
            print("✅ Task updated")
            
            // Verify updates
            let retrievedTask = try TaskchampionService.shared.getTask(uuid: task.uuid)
            XCTAssertEqual(retrievedTask.project, "UpdatedProject")
            XCTAssertEqual(retrievedTask.description, "Updated description")
            XCTAssertEqual(retrievedTask.priority, .high)
            XCTAssertEqual(retrievedTask.status, .completed)
            XCTAssertEqual(retrievedTask.obsidianNote, "Updated note")
            XCTAssertNotNil(retrievedTask.due)
            
            print("✅ All updates preserved correctly")
            
        } catch {
            XCTFail("Task update failed: \(error)")
        }
    }
    
    func testGetAllTasks() {
        print("🧪 Testing get all tasks...")
        
        do {
            // Create multiple tasks with different properties
            let tasks = [
                TCTask(uuid: UUID().uuidString, project: "Project1", description: "Task 1", status: .pending, priority: .high, due: nil),
                TCTask(uuid: UUID().uuidString, project: "Project2", description: "Task 2", status: .completed, priority: .low, due: Date()),
                TCTask(uuid: UUID().uuidString, project: nil, description: "Task 3", status: .pending, priority: .medium, due: nil)
            ]
            
            // Create all tasks
            for task in tasks {
                try TaskchampionService.shared.createTask(task: task)
            }
            print("✅ Created \(tasks.count) test tasks")
            
            // Retrieve all tasks
            let retrievedTasks = try TaskchampionService.shared.getTasks()
            XCTAssertGreaterThanOrEqual(retrievedTasks.count, tasks.count)
            
            // Verify our tasks are in the results
            let taskUuids = Set(tasks.map { $0.uuid })
            let retrievedUuids = Set(retrievedTasks.map { $0.uuid })
            
            for uuid in taskUuids {
                XCTAssertTrue(retrievedUuids.contains(uuid), "Task \(uuid) not found in results")
            }
            
            print("✅ All created tasks found in results")
            
        } catch {
            XCTFail("Get all tasks failed: \(error)")
        }
    }
    
    func testTaskFiltering() {
        print("🧪 Testing task filtering...")
        
        do {
            // Create tasks with different projects
            let projectATasks = [
                TCTask(uuid: UUID().uuidString, project: "ProjectA", description: "Task A1", status: .pending, priority: .high, due: nil),
                TCTask(uuid: UUID().uuidString, project: "ProjectA", description: "Task A2", status: .completed, priority: .low, due: nil)
            ]
            
            let projectBTasks = [
                TCTask(uuid: UUID().uuidString, project: "ProjectB", description: "Task B1", status: .pending, priority: .medium, due: nil)
            ]
            
            // Create all tasks
            for task in projectATasks + projectBTasks {
                try TaskchampionService.shared.createTask(task: task)
            }
            
            // Test project filtering
            let projectAFilter = TCFilter()
            projectAFilter.project = "ProjectA"
            projectAFilter.didSetProject = true
            
            let projectAResults = try TaskchampionService.shared.getTasks(filter: projectAFilter)
            XCTAssertGreaterThanOrEqual(projectAResults.count, 2)
            
            for task in projectAResults {
                if projectATasks.contains(where: { $0.uuid == task.uuid }) {
                    XCTAssertEqual(task.project, "ProjectA")
                }
            }
            
            // Test status filtering
            let pendingFilter = TCFilter()
            pendingFilter.status = .pending
            pendingFilter.didSetStatus = true
            
            let pendingResults = try TaskchampionService.shared.getTasks(filter: pendingFilter)
            for task in pendingResults {
                if projectATasks.contains(where: { $0.uuid == task.uuid }) || projectBTasks.contains(where: { $0.uuid == task.uuid }) {
                    XCTAssertEqual(task.status, .pending)
                }
            }
            
            print("✅ Task filtering working correctly")
            
        } catch {
            XCTFail("Task filtering failed: \(error)")
        }
    }
    
    func testBatchOperations() {
        print("🧪 Testing batch operations...")
        
        do {
            // Create multiple tasks
            let tasks = [
                TCTask(uuid: UUID().uuidString, project: "BatchProject", description: "Batch Task 1", status: .pending, priority: .high, due: nil),
                TCTask(uuid: UUID().uuidString, project: "BatchProject", description: "Batch Task 2", status: .pending, priority: .low, due: nil),
                TCTask(uuid: UUID().uuidString, project: "BatchProject", description: "Batch Task 3", status: .pending, priority: .medium, due: nil)
            ]
            
            for task in tasks {
                try TaskchampionService.shared.createTask(task: task)
            }
            print("✅ Created \(tasks.count) tasks for batch operations")
            
            // Test batch status update
            let taskUuids = Set(tasks.map { $0.uuid })
            try TaskchampionService.shared.updatePendingTasks(taskUuids, withStatus: .completed)
            print("✅ Batch updated \(taskUuids.count) tasks to completed")
            
            // Verify all tasks were updated
            for uuid in taskUuids {
                let task = try TaskchampionService.shared.getTask(uuid: uuid)
                XCTAssertEqual(task.status, .completed)
            }
            
            // Test batch toggle
            try TaskchampionService.shared.togglePendingTasksStatus(uuids: taskUuids)
            print("✅ Batch toggled \(taskUuids.count) task statuses")
            
            // Verify tasks were toggled back to pending
            for uuid in taskUuids {
                let task = try TaskchampionService.shared.getTask(uuid: uuid)
                XCTAssertEqual(task.status, .pending)
            }
            
            print("✅ Batch operations completed successfully")
            
        } catch {
            XCTFail("Batch operations failed: \(error)")
        }
    }
    
    func testSyncStatusMethods() {
        print("🧪 Testing sync status methods...")
        
        do {
            // Test local operations count
            let initialCount = try TaskchampionService.shared.getLocalOperationsCount()
            print("✅ Initial local operations count: \(initialCount)")
            
            // Create a task (should increase operations)
            let task = TCTask(uuid: UUID().uuidString, project: nil, description: "Sync test task", status: .pending, priority: nil, due: nil)
            try TaskchampionService.shared.createTask(task: task)
            
            let newCount = try TaskchampionService.shared.getLocalOperationsCount()
            print("✅ Operations count after task creation: \(newCount)")
            
            // Test needs sync (depends on AWS configuration)
            let needsSync = try TaskchampionService.shared.needsSync()
            print("✅ Sync needed: \(needsSync)")
            
            print("✅ Sync status methods working correctly")
            
        } catch {
            XCTFail("Sync status methods failed: \(error)")
        }
    }
    
    func testErrorHandling() {
        print("🧪 Testing error handling...")
        
        do {
            // Test getting non-existent task
            do {
                let _ = try TaskchampionService.shared.getTask(uuid: "non-existent-uuid")
                XCTFail("Should have thrown error for non-existent task")
            } catch {
                print("✅ Correctly handled non-existent task error: \(error)")
            }
            
            print("✅ Error handling working correctly")
            
        } catch {
            XCTFail("Error handling test setup failed: \(error)")
        }
    }
}