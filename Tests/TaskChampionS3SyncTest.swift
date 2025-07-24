import XCTest
@testable import taskchampShared
import Taskchampion

/// Test real S3 sync to verify we can retrieve the 3,069 tasks
class TaskChampionS3SyncTest: XCTestCase {
    
    var tempDbPath: String!
    
    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        tempDbPath = "\(tempDir)taskchampion_s3_test_\(UUID().uuidString).db"
        print("🧪 S3 Test DB path: \(tempDbPath!)")
    }
    
    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(atPath: tempDbPath)
    }
    
    func testS3SyncAndTaskRetrieval() async throws {
        print("🔍 Testing real S3 sync and task retrieval")
        
        // Check if AWS is configured
        guard UserDefaults.standard.isAWSConfigured else {
            print("⏭️  Skipping S3 sync test - AWS not configured in UserDefaults")
            return
        }
        
        print("✅ AWS is configured, proceeding with S3 sync test")
        
        // Initialize TaskchampionService with fresh database
        TaskchampionService.shared.setDbUrl(tempDbPath)
        
        // Step 1: Verify we start with empty database
        do {
            let initialTasks = try TaskchampionService.shared.getTasks()
            print("📊 Initial task count: \(initialTasks.count)")
            XCTAssertEqual(initialTasks.count, 0, "Fresh database should have no tasks")
        }
        
        // Step 2: Perform S3 sync
        print("🔄 Starting S3 sync...")
        do {
            try await TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ S3 sync completed successfully")
        } catch {
            print("❌ S3 sync failed: \(error)")
            XCTFail("S3 sync failed: \(error)")
            return
        }
        
        // Step 3: Retrieve tasks after sync
        do {
            let syncedTasks = try TaskchampionService.shared.getTasks()
            print("📊 Tasks after S3 sync: \(syncedTasks.count)")
            
            if syncedTasks.count > 0 {
                print("🎉 SUCCESS! TaskChampion S3 sync working - retrieved \(syncedTasks.count) tasks")
                
                // Log first 5 tasks for verification
                print("📝 First few tasks:")
                for (index, task) in syncedTasks.prefix(5).enumerated() {
                    print("  [\(index+1)] '\(task.description)' (project: \(task.project ?? "nil"), status: \(task.status.rawValue), priority: \(task.priority?.rawValue ?? "nil"))")
                }
                
                // Verify we got close to the expected 3,069 tasks
                if syncedTasks.count > 3000 {
                    print("🎯 Task count (\(syncedTasks.count)) is close to expected 3,069 - integration working correctly!")
                } else {
                    print("⚠️  Task count (\(syncedTasks.count)) is lower than expected 3,069 - might be filtering or conversion issue")
                }
                
                XCTAssertGreaterThan(syncedTasks.count, 0, "Should have retrieved tasks from S3")
                
            } else {
                print("❌ S3 sync completed but retrieved 0 tasks")
                print("   This suggests:")
                print("   1. S3 bucket is empty (unlikely)")
                print("   2. TaskData conversion is failing")
                print("   3. Bridge methods are not working properly")
                
                XCTFail("S3 sync retrieved 0 tasks - integration not working")
            }
        } catch {
            print("❌ Failed to retrieve tasks after sync: \(error)")
            XCTFail("Task retrieval failed after sync: \(error)")
        }
    }
    
    func testDirectBridgeAfterS3Sync() async throws {
        print("🔍 Testing direct bridge access after S3 sync")
        
        guard UserDefaults.standard.isAWSConfigured else {
            print("⏭️  Skipping direct bridge test - AWS not configured")
            return
        }
        
        // Initialize fresh database and sync
        TaskchampionService.shared.setDbUrl(tempDbPath)
        try await TaskchampionService.shared.syncToAWSFromUserDefaults()
        
        // Get replica directly
        let replica = new_replica_on_disk(tempDbPath)
        
        // Test direct bridge access
        let tasksVec = replica.get_all_tasks()
        print("📊 Direct bridge get_all_tasks() returned: \(tasksVec.len()) tasks")
        
        if tasksVec.len() > 0 {
            print("✅ Direct bridge working - tasks exist in database")
            
            // Test conversion of first task
            if let firstTaskRef = tasksVec.get(index: 0) {
                let uuid = firstTaskRef.get_uuid().to_string().toString()
                let fields = firstTaskRef.get_fields()
                
                print("📝 First task UUID: \(uuid)")
                print("📝 First task has \(fields.len()) fields:")
                
                for i in 0..<min(fields.len(), 10) {
                    if let field = fields.get(index: UInt(i)) {
                        let key = field.get_key().toString()
                        let value = field.get_value().toString()
                        print("    \(key): '\(value)'")
                    }
                }
            }
            
            XCTAssertGreaterThan(tasksVec.len(), 0, "Direct bridge should show tasks")
            
        } else {
            print("❌ Direct bridge shows 0 tasks after S3 sync")
            print("   This suggests S3 sync didn't actually download tasks to local database")
            
            XCTFail("Direct bridge access shows 0 tasks after sync")
        }
    }
    
    func testWrappedBridgeAfterS3Sync() async throws {
        print("🔍 Testing wrapped bridge access after S3 sync")
        
        guard UserDefaults.standard.isAWSConfigured else {
            print("⏭️  Skipping wrapped bridge test - AWS not configured")
            return
        }
        
        // Initialize and sync
        TaskchampionService.shared.setDbUrl(tempDbPath)
        try await TaskchampionService.shared.syncToAWSFromUserDefaults()
        
        // Test wrapped bridge access
        let replica = new_replica_on_disk(tempDbPath)
        
        do {
            let taskDataList = try replica.getAllTasks()
            print("📊 Wrapped getAllTasks() returned: \(taskDataList.count) tasks")
            
            if taskDataList.count > 0 {
                print("✅ Wrapped bridge working - TaskData conversion successful")
                
                let firstTask = taskDataList[0]
                print("📝 First converted task:")
                print("    UUID: \(firstTask.uuid)")
                print("    Description: '\(firstTask.description)'")
                print("    Status: \(firstTask.status)")
                print("    Project: \(firstTask.project ?? "nil")")
                print("    Priority: \(firstTask.priority ?? "nil")")
                
                XCTAssertGreaterThan(taskDataList.count, 0, "Wrapped bridge should convert tasks")
                
            } else {
                print("❌ Wrapped bridge converted 0 tasks")
                print("   This suggests TaskData conversion is failing")
                
                XCTFail("Wrapped bridge conversion produced 0 tasks")
            }
        } catch {
            print("❌ Wrapped bridge failed: \(error)")
            XCTFail("Wrapped bridge threw error: \(error)")
        }
    }
}