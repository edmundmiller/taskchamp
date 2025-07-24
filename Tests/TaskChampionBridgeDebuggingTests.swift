import XCTest
@testable import taskchampShared
import Taskchampion

/// Tests to debug the actual state of TaskChampion bridge integration
class TaskChampionBridgeDebuggingTests: XCTestCase {
    
    var tempDbPath: String!
    
    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        tempDbPath = "\(tempDir)taskchampion_debug_test_\(UUID().uuidString).db"
        print("🧪 Debug Test DB path: \(tempDbPath!)")
    }
    
    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(atPath: tempDbPath)
    }
    
    func testDirectBridgeMethodsExist() throws {
        print("🔍 Testing if bridge methods are available")
        
        let replica = new_replica_on_disk(tempDbPath)
        
        // Test if basic bridge methods work
        let emptyTasks = replica.get_all_tasks() 
        print("📊 Direct bridge get_all_tasks() returned \(emptyTasks.len()) tasks")
        XCTAssertEqual(emptyTasks.len(), 0, "New replica should start with 0 tasks")
        
        // Test creating a task
        do {
            let taskUuid = UUID().uuidString
            let createdTask = try replica.create_task(taskUuid)
            print("✅ Successfully created task with UUID: \(taskUuid)")
            
            // Verify task was created
            let tasksAfterCreate = replica.get_all_tasks()
            print("📊 After creating task: \(tasksAfterCreate.len()) tasks")
            XCTAssertEqual(tasksAfterCreate.len(), 1, "Should have 1 task after creation")
            
            // Test getting task by UUID
            let retrievedTask = try replica.get_task_by_uuid(taskUuid)
            print("✅ Successfully retrieved task by UUID")
            
            // Check task properties
            let fields = retrievedTask.get_fields()
            print("📝 Task has \(fields.len()) properties:")
            for i in 0..<fields.len() {
                if let field = fields.get(index: UInt(i)) {
                    let key = field.get_key().toString()
                    let value = field.get_value().toString()
                    print("  - \(key): \(value)")
                }
            }
            
        } catch {
            XCTFail("Failed to create/retrieve task: \(error)")
        }
    }
    
    func testSwiftWrapperLayerIntegration() throws {
        print("🔍 Testing Swift wrapper layer integration")
        
        let replica = new_replica_on_disk(tempDbPath)
        
        // Test the high-level Swift wrapper methods
        do {
            let initialTasks = try replica.getAllTasks()
            print("📊 Wrapper getAllTasks() returned \(initialTasks.count) tasks")
            XCTAssertEqual(initialTasks.count, 0, "New replica should start with 0 tasks")
            
            // Test task creation through wrapper
            let taskUuid = UUID().uuidString
            try replica.createTask(
                uuid: taskUuid,
                description: "Test task description",
                project: "TestProject",
                priority: "high",
                due: nil,
                obsidianNote: "Test note"
            )
            print("✅ Successfully created task through wrapper")
            
            // Verify task through wrapper
            let tasksAfterCreate = try replica.getAllTasks()
            print("📊 Wrapper getAllTasks() after creation: \(tasksAfterCreate.count) tasks")
            
            if tasksAfterCreate.count > 0 {
                let task = tasksAfterCreate[0]
                print("📝 First task: uuid=\(task.uuid), desc='\(task.description)', project=\(task.project ?? "nil"), priority=\(task.priority ?? "nil")")
            }
            
            XCTAssertEqual(tasksAfterCreate.count, 1, "Should have 1 task after wrapper creation")
            
        } catch {
            print("❌ Wrapper test failed: \(error)")
            XCTFail("Wrapper integration failed: \(error)")
        }
    }
    
    func testTaskchampionServiceIntegration() throws {
        print("🔍 Testing TaskchampionService integration")
        
        // Initialize TaskchampionService 
        TaskchampionService.shared.setDbUrl(tempDbPath)
        
        do {
            // Test getting tasks through service
            let initialTasks = try TaskchampionService.shared.getTasks()
            print("📊 TaskchampionService getTasks() returned \(initialTasks.count) tasks")
            XCTAssertEqual(initialTasks.count, 0, "New replica should start with 0 tasks")
            
            // Test creating task through service
            let newTask = TCTask(
                uuid: UUID().uuidString,
                project: "ServiceTest",
                description: "Task created through TaskchampionService",
                status: .pending,
                priority: .high,
                due: nil,
                obsidianNote: "Service test note"
            )
            
            try TaskchampionService.shared.createTask(task: newTask)
            print("✅ Successfully created task through TaskchampionService")
            
            // Verify task through service
            let tasksAfterCreate = try TaskchampionService.shared.getTasks()
            print("📊 TaskchampionService getTasks() after creation: \(tasksAfterCreate.count) tasks")
            
            if tasksAfterCreate.count > 0 {
                let task = tasksAfterCreate[0]
                print("📝 Service task: uuid=\(task.uuid), desc='\(task.description)', project=\(task.project ?? "nil"), priority=\(task.priority?.rawValue ?? "nil")")
            }
            
            XCTAssertGreaterThan(tasksAfterCreate.count, 0, "Should have tasks after service creation")
            
        } catch {
            print("❌ TaskchampionService test failed: \(error)")
            XCTFail("TaskchampionService integration failed: \(error)")
        }
    }
    
    func testRealS3SyncIfConfigured() throws {
        print("🔍 Testing real S3 sync if AWS is configured")
        
        // Only run this test if AWS is configured
        guard UserDefaults.standard.isAWSConfigured else {
            print("⏭️  Skipping S3 sync test - AWS not configured")
            return
        }
        
        TaskchampionService.shared.setDbUrl(tempDbPath)
        
        do {
            // Perform S3 sync
            try await TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ S3 sync completed successfully")
            
            // Check if tasks were downloaded
            let syncedTasks = try TaskchampionService.shared.getTasks()
            print("📊 After S3 sync: \(syncedTasks.count) tasks")
            
            if syncedTasks.count > 0 {
                print("🎉 SUCCESS: TaskChampion is working! Retrieved \(syncedTasks.count) tasks from S3")
                
                // Log first few tasks for verification  
                for (index, task) in syncedTasks.prefix(5).enumerated() {
                    print("📝 Task[\(index)]: uuid=\(task.uuid), desc='\(task.description)', status=\(task.status.rawValue), project=\(task.project ?? "nil")")
                }
            } else {
                print("⚠️  S3 sync completed but no tasks retrieved - this suggests a conversion issue")
            }
            
        } catch {
            print("❌ S3 sync failed: \(error)")
            // Don't fail the test - just log the error for debugging
        }
    }
}