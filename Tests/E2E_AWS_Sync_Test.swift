import XCTest
@testable import taskchampShared

/// End-to-End AWS Sync Smoke Test
/// This test simulates the complete AWS sync workflow for all authentication methods
class E2EAWSSyncTest: XCTestCase {
    
    let testRegion = "us-west-2"
    let testBucket = "taskchamp-test-bucket"
    let testEncryptionSecret = "test-encryption-secret-12345"
    let testAccessKeyId = "AKIAIOSFODNN7EXAMPLE"
    let testSecretAccessKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    let testProfileName = "test-profile"
    
    override func setUp() {
        super.setUp()
        // Clear any existing AWS configuration
        UserDefaults.standard.clearAWSConfig()
        
        // Initialize TaskchampionService with a mock database
        TaskchampionService.shared.setDbUrl("test-db-path")
    }
    
    override func tearDown() {
        // Clean up after each test
        UserDefaults.standard.clearAWSConfig()
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testAccessKeyAuthMethod() {
        print("🧪 Testing AWS Sync with Access Key Authentication")
        
        // Step 1: Configure AWS with Access Key
        configureAWSWithAccessKey()
        
        // Step 2: Verify configuration
        XCTAssertTrue(UserDefaults.standard.isAWSConfigured)
        XCTAssertTrue(UserDefaults.standard.validateAWSConfig())
        XCTAssertEqual(UserDefaults.standard.awsAuthMethod, .accessKey)
        
        // Step 3: Check if sync is needed (should be true initially)
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertTrue(needsSync, "needsSync() should return true before sync")
        } catch {
            XCTFail("needsSync() should not throw error: \(error)")
        }
        
        // Step 4: Perform sync
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ Access Key sync completed successfully")
        } catch {
            XCTFail("Access Key sync failed: \(error)")
        }
        
        // Step 5: Verify sync status after sync
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertFalse(needsSync, "needsSync() should return false after sync")
        } catch {
            XCTFail("needsSync() should not throw error after sync: \(error)")
        }
        
        print("✅ Access Key authentication test passed")
    }
    
    func testProfileAuthMethod() {
        print("🧪 Testing AWS Sync with Profile Authentication")
        
        // Step 1: Configure AWS with Profile
        configureAWSWithProfile()
        
        // Step 2: Verify configuration
        XCTAssertTrue(UserDefaults.standard.isAWSConfigured)
        XCTAssertTrue(UserDefaults.standard.validateAWSConfig())
        XCTAssertEqual(UserDefaults.standard.awsAuthMethod, .profile)
        
        // Step 3: Check if sync is needed (should be true initially)
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertTrue(needsSync, "needsSync() should return true before sync")
        } catch {
            XCTFail("needsSync() should not throw error: \(error)")
        }
        
        // Step 4: Perform sync
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ Profile sync completed successfully")
        } catch {
            XCTFail("Profile sync failed: \(error)")
        }
        
        // Step 5: Verify sync status after sync
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertFalse(needsSync, "needsSync() should return false after sync")
        } catch {
            XCTFail("needsSync() should not throw error after sync: \(error)")
        }
        
        print("✅ Profile authentication test passed")
    }
    
    func testDefaultCredentialsAuthMethod() {
        print("🧪 Testing AWS Sync with Default Credentials Authentication")
        
        // Step 1: Configure AWS with Default Credentials
        configureAWSWithDefaultCredentials()
        
        // Step 2: Verify configuration
        XCTAssertTrue(UserDefaults.standard.isAWSConfigured)
        XCTAssertTrue(UserDefaults.standard.validateAWSConfig())
        XCTAssertEqual(UserDefaults.standard.awsAuthMethod, .defaultCredentials)
        
        // Step 3: Check if sync is needed (should be true initially)
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertTrue(needsSync, "needsSync() should return true before sync")
        } catch {
            XCTFail("needsSync() should not throw error: \(error)")
        }
        
        // Step 4: Perform sync
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ Default Credentials sync completed successfully")
        } catch {
            XCTFail("Default Credentials sync failed: \(error)")
        }
        
        // Step 5: Verify sync status after sync
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            XCTAssertFalse(needsSync, "needsSync() should return false after sync")
        } catch {
            XCTFail("needsSync() should not throw error after sync: \(error)")
        }
        
        print("✅ Default Credentials authentication test passed")
    }
    
    func testErrorHandling() {
        print("🧪 Testing Error Handling")
        
        // Test sync without configuration
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            XCTFail("Should throw error when not configured")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("not configured"))
        }
        
        // Test with invalid configuration
        configureInvalidAWSConfig()
        
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            XCTFail("Should throw error with invalid configuration")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("invalid"))
        }
        
        print("✅ Error handling test passed")
    }
    
    func testCompleteWorkflow() {
        print("🧪 Testing Complete Workflow")
        
        // Test all authentication methods in sequence
        testAccessKeyAuthMethod()
        UserDefaults.standard.clearAWSConfig()
        
        testProfileAuthMethod()
        UserDefaults.standard.clearAWSConfig()
        
        testDefaultCredentialsAuthMethod()
        UserDefaults.standard.clearAWSConfig()
        
        print("✅ Complete workflow test passed")
    }
    
    // MARK: - Helper Methods
    
    private func configureAWSWithAccessKey() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.awsRegion = testRegion
        userDefaults.awsBucket = testBucket
        userDefaults.awsAccessKeyId = testAccessKeyId
        userDefaults.awsSecretAccessKey = testSecretAccessKey
        userDefaults.awsEncryptionSecret = testEncryptionSecret
        userDefaults.awsAuthMethod = .accessKey
        userDefaults.isAWSConfigured = true
    }
    
    private func configureAWSWithProfile() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.awsRegion = testRegion
        userDefaults.awsBucket = testBucket
        userDefaults.awsProfileName = testProfileName
        userDefaults.awsEncryptionSecret = testEncryptionSecret
        userDefaults.awsAuthMethod = .profile
        userDefaults.isAWSConfigured = true
    }
    
    private func configureAWSWithDefaultCredentials() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.awsRegion = testRegion
        userDefaults.awsBucket = testBucket
        userDefaults.awsEncryptionSecret = testEncryptionSecret
        userDefaults.awsAuthMethod = .defaultCredentials
        userDefaults.isAWSConfigured = true
    }
    
    private func configureInvalidAWSConfig() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.awsRegion = "" // Invalid empty region
        userDefaults.awsBucket = testBucket
        userDefaults.awsEncryptionSecret = testEncryptionSecret
        userDefaults.awsAuthMethod = .accessKey
        userDefaults.awsAccessKeyId = ""
        userDefaults.awsSecretAccessKey = ""
        userDefaults.isAWSConfigured = true
    }
}

// MARK: - Manual Test Instructions

/*
 
 # Manual E2E AWS Sync Smoke Test Instructions
 
 ## Prerequisites
 1. Launch the app on a device/simulator
 2. Ensure you have AWS S3 credentials for testing
 3. Create a test S3 bucket for the test
 
 ## Test Steps
 
 ### 1. Access Key Authentication Test
 
 1. Open the app and navigate to Settings → AWS Sync Settings
 2. Set Authentication Method to "Access Key"
 3. Configure:
    - AWS Region: us-west-2
    - S3 Bucket Name: your-test-bucket
    - Access Key ID: your-access-key-id
    - Secret Access Key: your-secret-access-key
    - Encryption Secret: your-encryption-secret
 4. Tap "Test Sync" to verify configuration
 5. Tap "Save" to save the configuration
 6. Create or modify a task locally
 7. Go to the main task list and tap the menu (⋯) → "Sync to AWS"
 8. Verify:
    - No runtime errors occur
    - Sync completes successfully
    - Check S3 bucket for replica objects
 
 ### 2. Profile Authentication Test
 
 1. Clear existing AWS configuration
 2. Set Authentication Method to "AWS Profile"
 3. Configure:
    - AWS Region: us-west-2
    - S3 Bucket Name: your-test-bucket
    - Profile Name: your-aws-profile
    - Encryption Secret: your-encryption-secret
 4. Ensure ~/.aws/credentials file exists with your profile
 5. Repeat steps 4-8 from Access Key test
 
 ### 3. Default Credentials Authentication Test
 
 1. Clear existing AWS configuration
 2. Set Authentication Method to "Default Credentials"
 3. Configure:
    - AWS Region: us-west-2
    - S3 Bucket Name: your-test-bucket
    - Encryption Secret: your-encryption-secret
 4. Ensure AWS credentials are available via environment variables or IAM roles
 5. Repeat steps 4-8 from Access Key test
 
 ## Expected Results
 
 For each authentication method:
 - ✅ Configuration saves successfully
 - ✅ Test sync completes without errors
 - ✅ needsSync() returns true before sync
 - ✅ Sync to AWS completes successfully
 - ✅ needsSync() returns false after sync
 - ✅ S3 bucket contains replica objects
 - ✅ No runtime errors in console
 
 ## Error Scenarios to Test
 
 1. Invalid credentials - should show authentication error
 2. Non-existent bucket - should show bucket access error
 3. Invalid region - should show region error
 4. Network connectivity issues - should show network error
 5. Empty configuration - should show validation error
 
 */
