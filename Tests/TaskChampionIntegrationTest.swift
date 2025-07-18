import XCTest
@testable import taskchampShared
import Taskchampion

/// Tests to validate TaskChampion Swift-Rust integration
class TaskChampionIntegrationTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Initialize TaskchampionService with in-memory database
        TaskchampionService.shared.setDbUrl("test-db-path")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testReplicaCreation() {
        print("🧪 Testing replica creation...")
        
        // Test creating an in-memory replica
        do {
            let replica = try Taskchampion.new_replica_in_memory()
            XCTAssertNotNil(replica)
            print("✅ In-memory replica created successfully")
        } catch {
            XCTFail("Failed to create in-memory replica: \(error)")
        }
    }
    
    func testUuidGeneration() {
        print("🧪 Testing UUID generation...")
        
        let uuid1 = Taskchampion.uuid_v4()
        let uuid2 = Taskchampion.uuid_v4()
        
        XCTAssertNotEqual(uuid1.to_string().toString(), uuid2.to_string().toString())
        print("✅ UUIDs generated: \(uuid1.to_string().toString()) and \(uuid2.to_string().toString())")
    }
    
    func testTaskCreation() {
        print("🧪 Testing task creation...")
        
        do {
            let replica = try Taskchampion.new_replica_in_memory()
            let uuid = Taskchampion.uuid_v4()
            let uuidString = uuid.to_string().toString()
            
            let task = try replica.create_task(uuidString)
            XCTAssertEqual(task.get_uuid().toString(), uuidString)
            
            print("✅ Task created with UUID: \(uuidString)")
        } catch {
            XCTFail("Failed to create task: \(error)")
        }
    }
    
    func testTaskProperties() {
        print("🧪 Testing task properties...")
        
        do {
            let replica = try Taskchampion.new_replica_in_memory()
            let uuid = Taskchampion.uuid_v4()
            let uuidString = uuid.to_string().toString()
            
            let task = try replica.create_task(uuidString)
            
            // Set a property
            let ops = task.set_property("description", "Test task description")
            try replica.commit_operations(ops)
            
            // Retrieve the task again to verify property was set
            let retrievedTask = try replica.get_task_by_uuid(uuidString)
            if let description = retrievedTask.get_property("description") {
                XCTAssertEqual(description.toString(), "Test task description")
                print("✅ Task property set and retrieved: \(description.toString())")
            } else {
                XCTFail("Property not found")
            }
        } catch {
            XCTFail("Failed to set/get task properties: \(error)")
        }
    }
    
    func testTaskList() {
        print("🧪 Testing task list...")
        
        do {
            let replica = try Taskchampion.new_replica_in_memory()
            
            // Create multiple tasks
            var taskUuids: [String] = []
            for i in 1...3 {
                let uuid = Taskchampion.uuid_v4()
                let uuidString = uuid.to_string().toString()
                taskUuids.append(uuidString)
                
                let task = try replica.create_task(uuidString)
                let ops = task.set_property("description", "Test task \(i)")
                try replica.commit_operations(ops)
            }
            
            // Get all tasks
            let tasks = try replica.get_all_tasks()
            XCTAssertEqual(tasks.len(), 3)
            print("✅ Created and retrieved \(tasks.len()) tasks")
            
            // Verify task contents
            for i in 0..<tasks.len() {
                if let task = tasks.get(index: UInt(i)) {
                    let uuid = task.get_uuid().toString()
                    XCTAssertTrue(taskUuids.contains(uuid))
                    
                    if let description = task.get_property("description") {
                        print("   Task \(uuid): \(description.toString())")
                    }
                }
            }
        } catch {
            XCTFail("Failed to create/list tasks: \(error)")
        }
    }
    
    func testLocalOperations() {
        print("🧪 Testing local operations count...")
        
        do {
            let replica = try Taskchampion.new_replica_in_memory()
            
            // Initially should have 0 operations
            let initialCount = try replica.num_local_operations()
            XCTAssertEqual(initialCount, 0)
            print("✅ Initial operations count: \(initialCount)")
            
            // Create a task (should increase operations)
            let uuid = Taskchampion.uuid_v4()
            let task = try replica.create_task(uuid.to_string().toString())
            let ops = task.set_property("description", "Test task")
            try replica.commit_operations(ops)
            
            // Now should have more operations
            let newCount = try replica.num_local_operations()
            XCTAssertGreaterThan(newCount, initialCount)
            print("✅ Operations count after creating task: \(newCount)")
            
        } catch {
            XCTFail("Failed to test local operations: \(error)")
        }
    }
    
    func testTaskchampionService() {
        print("🧪 Testing TaskchampionService integration...")
        
        do {
            // Test local operations count via service
            let count = try TaskchampionService.shared.getLocalOperationsCount()
            print("✅ Local operations count via service: \(count)")
            
            // Test sync status
            let needsSync = try TaskchampionService.shared.needsSync()
            print("✅ Sync needed: \(needsSync)")
            
            // Test getTasks (should return empty array but not fail)
            let tasks = try TaskchampionService.shared.getTasks()
            XCTAssertEqual(tasks.count, 0)
            print("✅ getTasks() returned \(tasks.count) tasks")
            
        } catch {
            XCTFail("TaskchampionService integration failed: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        print("🧪 Testing error handling...")
        
        do {
            let replica = try Taskchampion.new_replica_in_memory()
            
            // Try to get a non-existent task
            do {
                let _ = try replica.get_task_by_uuid("non-existent-uuid")
                XCTFail("Should have thrown error for non-existent task")
            } catch {
                print("✅ Correctly threw error for non-existent task: \(error)")
            }
            
        } catch {
            XCTFail("Failed to set up error handling test: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformance() {
        print("🧪 Testing performance...")
        
        measure {
            do {
                let replica = try Taskchampion.new_replica_in_memory()
                
                // Create 100 tasks
                for i in 1...100 {
                    let uuid = Taskchampion.uuid_v4()
                    let task = try replica.create_task(uuid.to_string().toString())
                    let ops = task.set_property("description", "Performance test task \(i)")
                    try replica.commit_operations(ops)
                }
                
                // Retrieve all tasks
                let tasks = try replica.get_all_tasks()
                XCTAssertEqual(tasks.len(), 100)
                
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
        
        print("✅ Performance test completed")
    }
    
    func testCompleteWorkflow() {
        print("🧪 Testing complete workflow...")
        
        do {
            let replica = try Taskchampion.new_replica_in_memory()
            
            // Step 1: Create a task
            let uuid = Taskchampion.uuid_v4()
            let uuidString = uuid.to_string().toString()
            let task = try replica.create_task(uuidString)
            
            // Step 2: Set properties
            var ops = task.set_property("description", "Complete workflow test")
            try replica.commit_operations(ops)
            
            ops = task.set_property("project", "test-project")
            try replica.commit_operations(ops)
            
            ops = task.set_property("priority", "high")
            try replica.commit_operations(ops)
            
            // Step 3: Verify properties
            let retrievedTask = try replica.get_task_by_uuid(uuidString)
            XCTAssertEqual(retrievedTask.get_property("description")?.toString(), "Complete workflow test")
            XCTAssertEqual(retrievedTask.get_property("project")?.toString(), "test-project")
            XCTAssertEqual(retrievedTask.get_property("priority")?.toString(), "high")
            
            // Step 4: List all properties
            let allProperties = retrievedTask.get_all_properties()
            XCTAssertGreaterThan(allProperties.len(), 0)
            
            print("✅ Task properties:")
            for i in 0..<allProperties.len() {
                if let prop = allProperties.get(index: UInt(i)) {
                    print("   \(prop.as_str().toString())")
                }
            }
            
            // Step 5: Check operations count
            let operationsCount = try replica.num_local_operations()
            XCTAssertGreaterThan(operationsCount, 0)
            
            print("✅ Complete workflow test passed with \(operationsCount) operations")
            
        } catch {
            XCTFail("Complete workflow test failed: \(error)")
        }
    }
}
