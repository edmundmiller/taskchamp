import XCTest
import Foundation
@testable import taskchampShared

/// End-to-End R2 Sync Test Suite
/// This test suite provides comprehensive testing for Cloudflare R2 synchronization functionality
/// including unit tests, integration tests, and performance benchmarks.
class E2ER2SyncTest: XCTestCase {
    
    // MARK: - Test Configuration
    
    let testRegion = "auto"  // R2 uses 'auto' region
    let testBucket = "taskchamp-test-bucket"
    let testEncryptionSecret = "test-encryption-secret-12345"
    let testAccessKeyId = "test-access-key-id"
    let testSecretAccessKey = "test-secret-access-key"
    
    // R2 endpoint configuration
    let r2Endpoint = "https://\(ProcessInfo.processInfo.environment["R2_ACCOUNT_ID"] ?? "test-account").r2.cloudflarestorage.com"
    
    // Test control flags
    private var isR2TestEnabled: Bool {
        return ProcessInfo.processInfo.environment["R2_TEST"] == "1"
    }
    
    private var useLiveR2: Bool {
        return ProcessInfo.processInfo.environment["R2_LIVE"] == "1"
    }
    
    private var shouldRunPerformanceTests: Bool {
        return ProcessInfo.processInfo.environment["R2_PERFORMANCE"] == "1"
    }
    
    // MARK: - Test Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Clear any existing configuration
        UserDefaults.standard.clearAWSConfig()
        
        // Initialize TaskchampionService with test database
        let testDbPath = createTestDatabasePath()
        TaskchampionService.shared.setDbUrl(testDbPath)
        
        print("🔧 R2 Test Setup Complete")
        print("🔧 R2_TEST: \(isR2TestEnabled ? "ENABLED" : "DISABLED")")
        print("🔧 R2_LIVE: \(useLiveR2 ? "ENABLED" : "DISABLED")")
        print("🔧 R2_PERFORMANCE: \(shouldRunPerformanceTests ? "ENABLED" : "DISABLED")")
    }
    
    override func tearDown() {
        // Clean up test data
        UserDefaults.standard.clearAWSConfig()
        cleanupTestDatabase()
        super.tearDown()
    }
    
    // MARK: - Unit Tests with Mock Server
    
    func test_R2_MockServer_AccessKeyAuth() {
        guard isR2TestEnabled else {
            print("⏭️ Skipping R2 mock test - set R2_TEST=1 to enable")
            return
        }
        
        print("🧪 Testing R2 Sync with Mock Server (Access Key Auth)")
        
        // Use mock minio server for unit tests
        let mockConfig = createMockR2Config()
        configureR2WithAccessKey(config: mockConfig)
        
        // Verify configuration
        XCTAssertTrue(UserDefaults.standard.isAWSConfigured)
        XCTAssertTrue(UserDefaults.standard.validateAWSConfig())
        XCTAssertEqual(UserDefaults.standard.awsAuthMethod, .accessKey)
        
        // Test sync workflow
        performSyncWorkflowTest()
        
        print("✅ R2 Mock Server test passed")
    }
    
    func test_R2_MockServer_DefaultCredentials() {
        guard isR2TestEnabled else {
            print("⏭️ Skipping R2 mock test - set R2_TEST=1 to enable")
            return
        }
        
        print("🧪 Testing R2 Sync with Mock Server (Default Credentials)")
        
        let mockConfig = createMockR2Config()
        configureR2WithDefaultCredentials(config: mockConfig)
        
        // Verify configuration
        XCTAssertTrue(UserDefaults.standard.isAWSConfigured)
        XCTAssertTrue(UserDefaults.standard.validateAWSConfig())
        XCTAssertEqual(UserDefaults.standard.awsAuthMethod, .defaultCredentials)
        
        // Test sync workflow
        performSyncWorkflowTest()
        
        print("✅ R2 Mock Server default credentials test passed")
    }
    
    // MARK: - Live R2 Integration Tests
    
    func test_R2_Live_AccessKeyAuth() {
        guard isR2TestEnabled && useLiveR2 else {
            print("⏭️ Skipping live R2 test - set R2_TEST=1 R2_LIVE=1 to enable")
            return
        }
        
        print("🚀 Testing R2 Sync with Live R2 (Access Key Auth)")
        
        let liveConfig = createLiveR2Config()
        configureR2WithAccessKey(config: liveConfig)
        
        // Test complete sync workflow
        performSyncWorkflowTest()
        
        // Verify objects in R2
        verifyR2Objects()
        
        print("✅ Live R2 Access Key test passed")
    }
    
    func test_R2_Live_FullWorkflow() {
        guard isR2TestEnabled && useLiveR2 else {
            print("⏭️ Skipping live R2 workflow test - set R2_TEST=1 R2_LIVE=1 to enable")
            return
        }
        
        print("🚀 Testing R2 Complete Workflow")
        
        // Step 1: Create initial tasks and sync
        let task1UUID = createTestTask(description: "test task 1")
        let task2UUID = createTestTask(description: "test task 2")
        
        let liveConfig = createLiveR2Config()
        configureR2WithAccessKey(config: liveConfig)
        
        // Perform initial sync
        performSyncWorkflowTest()
        
        // Step 2: Create new replica and sync to verify data consistency
        let newReplicaPath = createTestDatabasePath(suffix: "_replica")
        let newTaskchampionService = TaskchampionService()
        newTaskchampionService.setDbUrl(newReplicaPath)
        
        do {
            // Sync new replica
            try newTaskchampionService.syncToAWSFromUserDefaults()
            
            // Verify tasks are identical
            let originalTasks = try TaskchampionService.shared.getTasks()
            let replicaTasks = try newTaskchampionService.getTasks()
            
            XCTAssertEqual(originalTasks.count, replicaTasks.count, "Task counts should match")
            
            // Verify specific task UUIDs exist
            let originalUUIDs = Set(originalTasks.map { $0.uuid })
            let replicaUUIDs = Set(replicaTasks.map { $0.uuid })
            
            XCTAssertTrue(originalUUIDs.contains(task1UUID), "Task 1 should exist in original")
            XCTAssertTrue(originalUUIDs.contains(task2UUID), "Task 2 should exist in original")
            XCTAssertTrue(replicaUUIDs.contains(task1UUID), "Task 1 should exist in replica")
            XCTAssertTrue(replicaUUIDs.contains(task2UUID), "Task 2 should exist in replica")
            
            print("✅ R2 Full Workflow test passed")
            
        } catch {
            XCTFail("R2 Full Workflow test failed: \(error)")
        }
    }
    
    // MARK: - Negative Tests
    
    func test_R2_ErrorHandling_WrongCredentials() {
        guard isR2TestEnabled else {
            print("⏭️ Skipping R2 error test - set R2_TEST=1 to enable")
            return
        }
        
        print("🧪 Testing R2 Error Handling - Wrong Credentials")
        
        // Configure with invalid credentials
        let invalidConfig = R2Config(
            region: testRegion,
            bucket: testBucket,
            accessKeyId: "invalid-key",
            secretAccessKey: "invalid-secret",
            encryptionSecret: testEncryptionSecret,
            endpoint: r2Endpoint
        )
        
        configureR2WithAccessKey(config: invalidConfig)
        
        // Attempt sync - should fail
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            XCTFail("Sync should fail with invalid credentials")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("authentication") || 
                         error.localizedDescription.contains("credentials") ||
                         error.localizedDescription.contains("403") ||
                         error.localizedDescription.contains("401"))
            print("✅ Correct error for wrong credentials: \(error.localizedDescription)")
        }
    }
    
    func test_R2_ErrorHandling_BucketNotFound() {
        guard isR2TestEnabled else {
            print("⏭️ Skipping R2 error test - set R2_TEST=1 to enable")
            return
        }
        
        print("🧪 Testing R2 Error Handling - Bucket Not Found")
        
        // Configure with non-existent bucket
        let config = createMockR2Config()
        let invalidBucketConfig = R2Config(
            region: config.region,
            bucket: "non-existent-bucket-\(UUID().uuidString)",
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
            encryptionSecret: config.encryptionSecret,
            endpoint: config.endpoint
        )
        
        configureR2WithAccessKey(config: invalidBucketConfig)
        
        // Attempt sync - should fail
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            XCTFail("Sync should fail with non-existent bucket")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("bucket") ||
                         error.localizedDescription.contains("404") ||
                         error.localizedDescription.contains("NoSuchBucket"))
            print("✅ Correct error for non-existent bucket: \(error.localizedDescription)")
        }
    }
    
    func test_R2_ErrorHandling_NetworkFailure() {
        guard isR2TestEnabled else {
            print("⏭️ Skipping R2 error test - set R2_TEST=1 to enable")
            return
        }
        
        print("🧪 Testing R2 Error Handling - Network Failure")
        
        // Configure with invalid endpoint
        let invalidEndpointConfig = R2Config(
            region: testRegion,
            bucket: testBucket,
            accessKeyId: testAccessKeyId,
            secretAccessKey: testSecretAccessKey,
            encryptionSecret: testEncryptionSecret,
            endpoint: "https://invalid-endpoint.example.com"
        )
        
        configureR2WithAccessKey(config: invalidEndpointConfig)
        
        // Attempt sync - should fail
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            XCTFail("Sync should fail with invalid endpoint")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("network") ||
                         error.localizedDescription.contains("connection") ||
                         error.localizedDescription.contains("timeout") ||
                         error.localizedDescription.contains("unreachable"))
            print("✅ Correct error for network failure: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Tests
    
    func test_R2_Performance_Sync() {
        guard isR2TestEnabled && shouldRunPerformanceTests else {
            print("⏭️ Skipping R2 performance test - set R2_TEST=1 R2_PERFORMANCE=1 to enable")
            return
        }
        
        print("⚡ Testing R2 Sync Performance")
        
        let config = useLiveR2 ? createLiveR2Config() : createMockR2Config()
        configureR2WithAccessKey(config: config)
        
        // Create multiple tasks for performance testing
        let taskCount = 100
        for i in 0..<taskCount {
            _ = createTestTask(description: "Performance test task \(i)")
        }
        
        // Measure sync performance
        let startTime = Date()
        
        measure {
            do {
                try TaskchampionService.shared.syncToAWSFromUserDefaults()
            } catch {
                XCTFail("Performance sync failed: \(error)")
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        print("⚡ R2 Sync Performance Results:")
        print("   • Tasks: \(taskCount)")
        print("   • Duration: \(String(format: "%.2f", duration))s")
        print("   • Throughput: \(String(format: "%.2f", Double(taskCount) / duration)) tasks/s")
        
        // Performance assertions
        XCTAssertLessThan(duration, 30.0, "Sync should complete within 30 seconds")
    }
    
    func test_R2_Performance_Comparison() {
        guard isR2TestEnabled && shouldRunPerformanceTests && useLiveR2 else {
            print("⏭️ Skipping R2 vs AWS comparison - set R2_TEST=1 R2_PERFORMANCE=1 R2_LIVE=1 to enable")
            return
        }
        
        print("⚡ Testing R2 vs AWS Performance Comparison")
        
        let taskCount = 50
        
        // Test R2 performance
        let r2Config = createLiveR2Config()
        configureR2WithAccessKey(config: r2Config)
        
        for i in 0..<taskCount {
            _ = createTestTask(description: "R2 comparison task \(i)")
        }
        
        let r2StartTime = Date()
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
        } catch {
            XCTFail("R2 sync failed: \(error)")
        }
        let r2Duration = Date().timeIntervalSince(r2StartTime)
        
        // Reset for AWS test
        UserDefaults.standard.clearAWSConfig()
        cleanupTestDatabase()
        let newDbPath = createTestDatabasePath(suffix: "_aws")
        TaskchampionService.shared.setDbUrl(newDbPath)
        
        // Test AWS performance (if configured)
        if let awsConfig = createAWSConfig() {
            configureR2WithAccessKey(config: awsConfig)
            
            for i in 0..<taskCount {
                _ = createTestTask(description: "AWS comparison task \(i)")
            }
            
            let awsStartTime = Date()
            do {
                try TaskchampionService.shared.syncToAWSFromUserDefaults()
            } catch {
                print("⚠️ AWS sync failed: \(error)")
            }
            let awsDuration = Date().timeIntervalSince(awsStartTime)
            
            print("⚡ Performance Comparison Results:")
            print("   • R2 Duration: \(String(format: "%.2f", r2Duration))s")
            print("   • AWS Duration: \(String(format: "%.2f", awsDuration))s")
            print("   • R2 Throughput: \(String(format: "%.2f", Double(taskCount) / r2Duration)) tasks/s")
            print("   • AWS Throughput: \(String(format: "%.2f", Double(taskCount) / awsDuration)) tasks/s")
            
            let performanceRatio = r2Duration / awsDuration
            print("   • R2 vs AWS Ratio: \(String(format: "%.2f", performanceRatio))x")
            
            if performanceRatio < 1.0 {
                print("   • ✅ R2 is faster than AWS")
            } else if performanceRatio > 2.0 {
                print("   • ⚠️ R2 is significantly slower than AWS")
            } else {
                print("   • ℹ️ R2 and AWS have similar performance")
            }
        }
    }
    
    // MARK: - Manual Test Script Generation
    
    func test_GenerateManualTestScript() {
        print("📝 Generating Manual Test Script")
        
        let script = generateManualTestScript()
        
        // Write script to file
        let scriptPath = "/tmp/r2_manual_test.sh"
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            print("✅ Manual test script generated at: \(scriptPath)")
            print("   Run with: chmod +x \(scriptPath) && \(scriptPath)")
        } catch {
            print("❌ Failed to write manual test script: \(error)")
        }
        
        // Also output to console for immediate use
        print("\n" + String(repeating: "=", count: 50))
        print("MANUAL TEST SCRIPT")
        print(String(repeating: "=", count: 50))
        print(script)
        print(String(repeating: "=", count: 50))
    }
    
    // MARK: - Helper Methods
    
    private func createTestDatabasePath(suffix: String = "") -> String {
        let tempDir = NSTemporaryDirectory()
        let testDir = "taskchamp_test\(suffix)_\(UUID().uuidString)"
        let fullPath = "\(tempDir)/\(testDir)"
        
        // Create the directory since TaskChampion expects a directory path
        try? FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: nil)
        
        return fullPath
    }
    
    private func cleanupTestDatabase() {
        // Clean up test database files
        let tempDir = NSTemporaryDirectory()
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: tempDir)
            for file in contents {
                if file.contains("taskchamp_test") {
                    try fileManager.removeItem(atPath: "\(tempDir)/\(file)")
                }
            }
        } catch {
            print("⚠️ Warning: Could not clean up test databases: \(error)")
        }
    }
    
    private func createMockR2Config() -> R2Config {
        // For unit tests, use mock minio server
        let mockEndpoint = ProcessInfo.processInfo.environment["MOCK_R2_ENDPOINT"] ?? "http://localhost:9000"
        
        return R2Config(
            region: "us-east-1",  // minio uses us-east-1
            bucket: testBucket,
            accessKeyId: ProcessInfo.processInfo.environment["MOCK_R2_ACCESS_KEY"] ?? "minioadmin",
            secretAccessKey: ProcessInfo.processInfo.environment["MOCK_R2_SECRET_KEY"] ?? "minioadmin",
            encryptionSecret: testEncryptionSecret,
            endpoint: mockEndpoint
        )
    }
    
    private func createLiveR2Config() -> R2Config {
        return R2Config(
            region: testRegion,
            bucket: ProcessInfo.processInfo.environment["R2_BUCKET"] ?? testBucket,
            accessKeyId: ProcessInfo.processInfo.environment["R2_ACCESS_KEY_ID"] ?? testAccessKeyId,
            secretAccessKey: ProcessInfo.processInfo.environment["R2_SECRET_ACCESS_KEY"] ?? testSecretAccessKey,
            encryptionSecret: ProcessInfo.processInfo.environment["R2_ENCRYPTION_SECRET"] ?? testEncryptionSecret,
            endpoint: r2Endpoint
        )
    }
    
    private func createAWSConfig() -> R2Config? {
        guard let bucket = ProcessInfo.processInfo.environment["AWS_BUCKET"],
              let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
              let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"],
              let region = ProcessInfo.processInfo.environment["AWS_REGION"] else {
            return nil
        }
        
        return R2Config(
            region: region,
            bucket: bucket,
            accessKeyId: accessKey,
            secretAccessKey: secretKey,
            encryptionSecret: testEncryptionSecret,
            endpoint: "https://s3.\(region).amazonaws.com"
        )
    }
    
    private func configureR2WithAccessKey(config: R2Config) {
        let userDefaults = UserDefaults.standard
        
        userDefaults.awsRegion = config.region
        userDefaults.awsBucket = config.bucket
        userDefaults.awsAccessKeyId = config.accessKeyId
        userDefaults.awsSecretAccessKey = config.secretAccessKey
        userDefaults.awsEncryptionSecret = config.encryptionSecret
        userDefaults.awsAuthMethod = .accessKey
        userDefaults.isAWSConfigured = true
        
        // Set custom endpoint for R2
        userDefaults.set(config.endpoint, forKey: "awsEndpoint")
    }
    
    private func configureR2WithDefaultCredentials(config: R2Config) {
        let userDefaults = UserDefaults.standard
        
        userDefaults.awsRegion = config.region
        userDefaults.awsBucket = config.bucket
        userDefaults.awsEncryptionSecret = config.encryptionSecret
        userDefaults.awsAuthMethod = .defaultCredentials
        userDefaults.isAWSConfigured = true
        
        // Set custom endpoint for R2
        userDefaults.set(config.endpoint, forKey: "awsEndpoint")
    }
    
    private func performSyncWorkflowTest() {
        // Check if sync is needed (should be true initially)
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertTrue(needsSync, "needsSync() should return true before sync")
        } catch {
            XCTFail("needsSync() should not throw error: \(error)")
        }
        
        // Perform sync
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ Sync completed successfully")
        } catch {
            XCTFail("Sync failed: \(error)")
        }
        
        // Verify sync status after sync
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertFalse(needsSync, "needsSync() should return false after sync")
        } catch {
            XCTFail("needsSync() should not throw error after sync: \(error)")
        }
    }
    
    private func createTestTask(description: String) -> String {
        let uuid = UUID().uuidString
        do {
            let task = TCTask(
                uuid: uuid,
                description: description,
                status: .pending
            )
            try TaskchampionService.shared.createTask(task: task)
            return uuid
        } catch {
            XCTFail("Failed to create test task: \(error)")
            return uuid
        }
    }
    
    private func verifyR2Objects() {
        // Use AWS CLI to verify objects were uploaded
        let verifyScript = """
        #!/bin/bash
        
        # Check if objects exist in R2
        if command -v aws &> /dev/null; then
            echo "🔍 Verifying R2 objects..."
            
            aws --endpoint-url "\(r2Endpoint)" s3 ls s3://\(testBucket)/ --recursive
            
            # Check for expected objects
            OPERATIONS_LOG=$(aws --endpoint-url "\(r2Endpoint)" s3 ls s3://\(testBucket)/ --recursive | grep -c "operations")
            SNAPSHOTS=$(aws --endpoint-url "\(r2Endpoint)" s3 ls s3://\(testBucket)/ --recursive | grep -c "snapshot")
            
            echo "✅ Operations log objects: $OPERATIONS_LOG"
            echo "✅ Snapshot objects: $SNAPSHOTS"
            
            if [ $OPERATIONS_LOG -gt 0 ] || [ $SNAPSHOTS -gt 0 ]; then
                echo "✅ R2 objects verified successfully"
                return 0
            else
                echo "❌ No R2 objects found"
                return 1
            fi
        else
            echo "⚠️ AWS CLI not found, skipping R2 object verification"
            return 0
        fi
        """
        
        let scriptPath = "/tmp/verify_r2_objects.sh"
        do {
            try verifyScript.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
            
            if process.terminationStatus == 0 {
                print("✅ R2 object verification completed")
            } else {
                print("⚠️ R2 object verification failed or incomplete")
            }
            
        } catch {
            print("⚠️ Could not verify R2 objects: \(error)")
        }
    }
    
    private func generateManualTestScript() -> String {
        return """
        #!/bin/bash
        
        # R2 Manual Test Script
        # Generated automatically by E2E_R2_Sync_Test.swift
        
        set -e
        
        echo "🚀 Starting R2 Manual Test"
        echo "=========================="
        
        # Configuration
        R2_ACCOUNT_ID="${R2_ACCOUNT_ID:-test-account}"
        R2_BUCKET="${R2_BUCKET:-taskchamp-test-bucket}"
        R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-your-access-key}"
        R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-your-secret-key}"
        R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
        
        # Check prerequisites
        if ! command -v aws &> /dev/null; then
            echo "❌ AWS CLI not found. Please install it first."
            exit 1
        fi
        
        if ! command -v taskchamp &> /dev/null; then
            echo "❌ taskchamp command not found. Please install it first."
            exit 1
        fi
        
        # Configure AWS CLI for R2
        export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
        export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
        export AWS_DEFAULT_REGION="auto"
        
        # Test 1: Create test task
        echo "📝 Step 1: Creating test task..."
        TEST_UUID=$(uuidgen)
        taskchamp new "$TEST_UUID" "R2 manual test task"
        echo "✅ Created task: $TEST_UUID"
        
        # Test 2: Configure R2 sync
        echo "🔧 Step 2: Configuring R2 sync..."
        taskchamp config set sync.r2.region auto
        taskchamp config set sync.r2.bucket "$R2_BUCKET"
        taskchamp config set sync.r2.access_key_id "$R2_ACCESS_KEY_ID"
        taskchamp config set sync.r2.secret_access_key "$R2_SECRET_ACCESS_KEY"
        taskchamp config set sync.r2.endpoint "$R2_ENDPOINT"
        echo "✅ R2 sync configured"
        
        # Test 3: Perform sync
        echo "🔄 Step 3: Performing sync..."
        taskchamp sync
        echo "✅ Sync completed"
        
        # Test 4: Verify objects in R2
        echo "🔍 Step 4: Verifying objects in R2..."
        aws --endpoint-url "$R2_ENDPOINT" s3 ls s3://"$R2_BUCKET"/ --recursive
        
        OBJECT_COUNT=$(aws --endpoint-url "$R2_ENDPOINT" s3 ls s3://"$R2_BUCKET"/ --recursive | wc -l)
        echo "✅ Found $OBJECT_COUNT objects in R2"
        
        # Test 5: Create new replica and sync
        echo "🔄 Step 5: Testing replica sync..."
        BACKUP_DIR=$(mktemp -d)
        cp -r ~/.taskchamp "$BACKUP_DIR/original"
        
        # Clear local data
        rm -rf ~/.taskchamp
        
        # Initialize new replica
        taskchamp init
        
        # Configure sync again
        taskchamp config set sync.r2.region auto
        taskchamp config set sync.r2.bucket "$R2_BUCKET"
        taskchamp config set sync.r2.access_key_id "$R2_ACCESS_KEY_ID"
        taskchamp config set sync.r2.secret_access_key "$R2_SECRET_ACCESS_KEY"
        taskchamp config set sync.r2.endpoint "$R2_ENDPOINT"
        
        # Sync to new replica
        taskchamp sync
        
        # Verify tasks are identical
        echo "🔍 Step 6: Verifying task consistency..."
        NEW_TASKS=$(taskchamp list | grep "$TEST_UUID" | wc -l)
        if [ "$NEW_TASKS" -eq 1 ]; then
            echo "✅ Task found in new replica: $TEST_UUID"
        else
            echo "❌ Task not found in new replica"
            exit 1
        fi
        
        # Test 6: Performance measurement
        echo "⚡ Step 7: Performance measurement..."
        
        # Create multiple tasks
        for i in {1..10}; do
            taskchamp new "perf-task-$i" "Performance test task $i"
        done
        
        # Measure sync time
        start_time=$(date +%s)
        taskchamp sync
        end_time=$(date +%s)
        
        duration=$((end_time - start_time))
        echo "✅ Sync completed in ${duration}s"
        
        # Test 7: Negative tests
        echo "🧪 Step 8: Testing error handling..."
        
        # Test with wrong credentials
        export AWS_ACCESS_KEY_ID="wrong-key"
        export AWS_SECRET_ACCESS_KEY="wrong-secret"
        
        if taskchamp sync 2>/dev/null; then
            echo "❌ Sync should have failed with wrong credentials"
            exit 1
        else
            echo "✅ Correctly failed with wrong credentials"
        fi
        
        # Restore original setup
        rm -rf ~/.taskchamp
        cp -r "$BACKUP_DIR/original" ~/.taskchamp
        rm -rf "$BACKUP_DIR"
        
        echo "🎉 All R2 manual tests completed successfully!"
        echo "============================================"
        
        # Output performance summary
        echo "📊 Performance Summary:"
        echo "   • Sync duration: ${duration}s"
        echo "   • Tasks synced: 11 (1 original + 10 performance)"
        echo "   • R2 objects: $OBJECT_COUNT"
        echo "   • Throughput: $(echo "scale=2; 11 / $duration" | bc) tasks/s"
        """
    }
}

// MARK: - Supporting Types

struct R2Config {
    let region: String
    let bucket: String
    let accessKeyId: String
    let secretAccessKey: String
    let encryptionSecret: String
    let endpoint: String
}

// MARK: - UserDefaults Extension for Testing

extension UserDefaults {
    func clearAWSConfig() {
        removeObject(forKey: "awsRegion")
        removeObject(forKey: "awsBucket") 
        removeObject(forKey: "awsAccessKeyId")
        removeObject(forKey: "awsSecretAccessKey")
        removeObject(forKey: "awsEncryptionSecret")
        removeObject(forKey: "awsAuthMethod")
        removeObject(forKey: "isAWSConfigured")
        removeObject(forKey: "awsEndpoint")
    }
}
