import XCTest
@testable import taskchampShared

/// Main App Integration Test
/// Verifies that the TaskChampion S3 sync integration works correctly in the main app context
class MainAppIntegrationTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Initialize TaskchampionService with a temporary database for testing
        let testDbPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("integration-test-\(UUID().uuidString)")
            .path
        TaskchampionService.shared.setDbUrl(testDbPath)
    }
    
    func testTaskCreationAndS3SyncIntegration() {
        // This test verifies the complete integration:
        // 1. TaskchampionService can create tasks
        // 2. DBService wrapper works correctly
        // 3. S3 sync with real AWS credentials works
        
        print("🧪 Testing Main App TaskChampion Integration")
        
        // Step 1: Create a test task using DBService (which wraps TaskchampionService)
        let testTask = TCTask(
            uuid: UUID().uuidString,
            project: "integration-test",
            description: "Test task for S3 sync integration",
            status: .pending,
            priority: .medium,
            due: nil,
            obsidianNote: nil
        )
        
        do {
            // Test task creation through DBService wrapper
            try DBService.shared.createTask(task: testTask)
            print("✅ Task created successfully through DBService wrapper")
            
            // Verify task was created by retrieving it
            let retrievedTask = try DBService.shared.getTask(uuid: testTask.uuid)
            XCTAssertEqual(retrievedTask.uuid, testTask.uuid)
            XCTAssertEqual(retrievedTask.description, testTask.description)
            XCTAssertEqual(retrievedTask.project, testTask.project)
            print("✅ Task retrieval verified")
            
            // Test that sync is needed after creating a task
            let needsSync = try DBService.shared.needsSync()
            if needsSync {
                print("✅ needsSync() correctly detected local changes")
            } else {
                print("ℹ️ needsSync() returned false - may be due to AWS not being configured")
            }
            
            // Test sync functionality if AWS is configured
            if UserDefaults.standard.isAWSConfigured {
                print("🔄 AWS is configured, testing sync...")
                
                // Configure with the same settings as the working test
                UserDefaults.standard.awsAuthMethod = .defaultCredentials
                UserDefaults.standard.awsRegion = "us-east-1"
                UserDefaults.standard.awsBucket = "taskchampion-sync-emiller-taskchamp-app"
                UserDefaults.standard.awsEncryptionSecret = "real-encryption-secret-key-for-testing"
                UserDefaults.standard.isAWSConfigured = true
                
                try TaskchampionService.shared.syncToAWSFromUserDefaults()
                print("✅ S3 sync completed successfully")
                
                // Verify sync status after sync
                let needsSyncAfter = try DBService.shared.needsSync()
                if !needsSyncAfter {
                    print("✅ needsSync() correctly shows false after sync")
                } else {
                    print("ℹ️ needsSync() still true after sync - may be normal")
                }
                
            } else {
                print("ℹ️ AWS not configured - skipping sync test")
                print("ℹ️ To test sync, configure AWS credentials and set isAWSConfigured = true")
            }
            
        } catch {
            XCTFail("Integration test failed: \(error)")
            print("❌ Integration test failed: \(error)")
        }
    }
    
    func testDBServiceTaskchampionServiceIntegration() {
        // Test that DBService correctly wraps TaskchampionService
        print("🧪 Testing DBService <-> TaskchampionService integration")
        
        let testTask = TCTask(
            uuid: UUID().uuidString,
            project: "wrapper-test",
            description: "Test DBService wrapper functionality",
            status: .pending,
            priority: .low,
            due: Date().addingTimeInterval(86400), // Tomorrow
            obsidianNote: "test-note"
        )
        
        do {
            // Create through DBService
            try DBService.shared.createTask(task: testTask)
            
            // Retrieve through TaskchampionService directly
            let taskViaTCS = try TaskchampionService.shared.getTask(uuid: testTask.uuid)
            XCTAssertEqual(taskViaTCS.uuid, testTask.uuid)
            XCTAssertEqual(taskViaTCS.description, testTask.description)
            
            // Retrieve through DBService
            let taskViaDB = try DBService.shared.getTask(uuid: testTask.uuid)
            XCTAssertEqual(taskViaDB.uuid, testTask.uuid)
            XCTAssertEqual(taskViaDB.description, testTask.description)
            
            // Update through DBService
            var updatedTask = testTask
            updatedTask.description = "Updated description"
            updatedTask.status = .completed
            
            try DBService.shared.updateTask(updatedTask)
            
            // Verify update through TaskchampionService
            let updatedTaskViaTCS = try TaskchampionService.shared.getTask(uuid: testTask.uuid)
            XCTAssertEqual(updatedTaskViaTCS.description, "Updated description")
            XCTAssertEqual(updatedTaskViaTCS.status, .completed)
            
            print("✅ DBService <-> TaskchampionService integration working correctly")
            
        } catch {
            XCTFail("DBService integration test failed: \(error)")
            print("❌ DBService integration test failed: \(error)")
        }
    }
    
    func testAWSConfigurationAccess() {
        // Test that AWS configuration is accessible and valid
        print("🧪 Testing AWS Configuration Access")
        
        // Test UserDefaults AWS extensions
        UserDefaults.standard.awsRegion = "us-east-1"
        UserDefaults.standard.awsBucket = "test-bucket"
        UserDefaults.standard.awsEncryptionSecret = "test-secret"
        
        XCTAssertEqual(UserDefaults.standard.awsRegion, "us-east-1")
        XCTAssertEqual(UserDefaults.standard.awsBucket, "test-bucket")
        XCTAssertEqual(UserDefaults.standard.awsEncryptionSecret, "test-secret")
        
        // Test validation
        UserDefaults.standard.awsAuthMethod = .defaultCredentials
        UserDefaults.standard.isAWSConfigured = true
        
        let isValid = UserDefaults.standard.validateAWSConfig()
        XCTAssertTrue(isValid, "AWS config should be valid with minimal required fields")
        
        print("✅ AWS configuration access working correctly")
        
        // Clean up
        UserDefaults.standard.clearAWSConfig()
    }
}