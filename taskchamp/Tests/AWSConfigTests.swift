import XCTest
@testable import taskchampShared

class AWSConfigTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear any existing AWS config
        UserDefaults.standard.clearAWSConfig()
    }
    
    override func tearDown() {
        // Clean up after each test
        UserDefaults.standard.clearAWSConfig()
        super.tearDown()
    }
    
    func testAWSConfigCreation() {
        // Test AWSConfig creation
        let config = AWSConfig(
            region: "us-west-2",
            bucket: "test-bucket",
            accessKeyId: "AKIATEST",
            secretAccessKey: "testsecret",
            encryptionSecret: "encryptionsecret"
        )
        
        XCTAssertEqual(config.region, "us-west-2")
        XCTAssertEqual(config.bucket, "test-bucket")
        XCTAssertEqual(config.accessKeyId, "AKIATEST")
        XCTAssertEqual(config.secretAccessKey, "testsecret")
        XCTAssertEqual(config.encryptionSecret, "encryptionsecret")
        XCTAssertFalse(config.avoidSnapshots)
    }
    
    func testAWSProfileConfigCreation() {
        // Test AWSProfileConfig creation
        let config = AWSProfileConfig(
            region: "us-east-1",
            bucket: "profile-bucket",
            profileName: "myprofile",
            encryptionSecret: "encryptionsecret"
        )
        
        XCTAssertEqual(config.region, "us-east-1")
        XCTAssertEqual(config.bucket, "profile-bucket")
        XCTAssertEqual(config.profileName, "myprofile")
        XCTAssertEqual(config.encryptionSecret, "encryptionsecret")
        XCTAssertFalse(config.avoidSnapshots)
    }
    
    func testUserDefaultsAWSConfig() {
        let userDefaults = UserDefaults.standard
        
        // Test initial state
        XCTAssertFalse(userDefaults.isAWSConfigured)
        XCTAssertFalse(userDefaults.validateAWSConfig())
        
        // Set configuration
        userDefaults.awsRegion = "us-west-2"
        userDefaults.awsBucket = "test-bucket"
        userDefaults.awsEncryptionSecret = "encryptionsecret"
        userDefaults.awsAuthMethod = .accessKey
        userDefaults.awsAccessKeyId = "AKIATEST"
        userDefaults.awsSecretAccessKey = "testsecret"
        userDefaults.isAWSConfigured = true
        
        // Test validation
        XCTAssertTrue(userDefaults.validateAWSConfig())
        
        // Test configuration retrieval
        let config = userDefaults.getAWSConfig()
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.region, "us-west-2")
        XCTAssertEqual(config?.bucket, "test-bucket")
        XCTAssertEqual(config?.accessKeyId, "AKIATEST")
        XCTAssertEqual(config?.secretAccessKey, "testsecret")
        XCTAssertEqual(config?.encryptionSecret, "encryptionsecret")
    }
    
    func testUserDefaultsAWSProfileConfig() {
        let userDefaults = UserDefaults.standard
        
        // Set profile configuration
        userDefaults.awsRegion = "us-east-1"
        userDefaults.awsBucket = "profile-bucket"
        userDefaults.awsEncryptionSecret = "encryptionsecret"
        userDefaults.awsAuthMethod = .profile
        userDefaults.awsProfileName = "myprofile"
        userDefaults.isAWSConfigured = true
        
        // Test validation
        XCTAssertTrue(userDefaults.validateAWSConfig())
        
        // Test profile configuration retrieval
        let config = userDefaults.getAWSProfileConfig()
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.region, "us-east-1")
        XCTAssertEqual(config?.bucket, "profile-bucket")
        XCTAssertEqual(config?.profileName, "myprofile")
        XCTAssertEqual(config?.encryptionSecret, "encryptionsecret")
    }
    
    func testUserDefaultsDefaultCredentialsConfig() {
        let userDefaults = UserDefaults.standard
        
        // Set default credentials configuration
        userDefaults.awsRegion = "us-central-1"
        userDefaults.awsBucket = "default-bucket"
        userDefaults.awsEncryptionSecret = "encryptionsecret"
        userDefaults.awsAuthMethod = .defaultCredentials
        userDefaults.isAWSConfigured = true
        
        // Test validation
        XCTAssertTrue(userDefaults.validateAWSConfig())
        
        // Test that both specific configs return nil for default credentials
        XCTAssertNil(userDefaults.getAWSConfig())
        XCTAssertNil(userDefaults.getAWSProfileConfig())
    }
    
    func testInvalidConfigurations() {
        let userDefaults = UserDefaults.standard
        
        // Test empty region
        userDefaults.awsRegion = ""
        userDefaults.awsBucket = "test-bucket"
        userDefaults.awsEncryptionSecret = "encryptionsecret"
        userDefaults.awsAuthMethod = .accessKey
        userDefaults.awsAccessKeyId = "AKIATEST"
        userDefaults.awsSecretAccessKey = "testsecret"
        XCTAssertFalse(userDefaults.validateAWSConfig())
        
        // Test empty bucket
        userDefaults.awsRegion = "us-west-2"
        userDefaults.awsBucket = ""
        XCTAssertFalse(userDefaults.validateAWSConfig())
        
        // Test empty encryption secret
        userDefaults.awsBucket = "test-bucket"
        userDefaults.awsEncryptionSecret = ""
        XCTAssertFalse(userDefaults.validateAWSConfig())
        
        // Test empty access key for access key method
        userDefaults.awsEncryptionSecret = "encryptionsecret"
        userDefaults.awsAccessKeyId = ""
        XCTAssertFalse(userDefaults.validateAWSConfig())
        
        // Test empty secret access key for access key method
        userDefaults.awsAccessKeyId = "AKIATEST"
        userDefaults.awsSecretAccessKey = ""
        XCTAssertFalse(userDefaults.validateAWSConfig())
    }
    
    func testClearAWSConfig() {
        let userDefaults = UserDefaults.standard
        
        // Set configuration
        userDefaults.awsRegion = "us-west-2"
        userDefaults.awsBucket = "test-bucket"
        userDefaults.awsEncryptionSecret = "encryptionsecret"
        userDefaults.awsAuthMethod = .accessKey
        userDefaults.awsAccessKeyId = "AKIATEST"
        userDefaults.awsSecretAccessKey = "testsecret"
        userDefaults.isAWSConfigured = true
        
        // Verify configuration is set
        XCTAssertTrue(userDefaults.isAWSConfigured)
        XCTAssertTrue(userDefaults.validateAWSConfig())
        
        // Clear configuration
        userDefaults.clearAWSConfig()
        
        // Verify configuration is cleared
        XCTAssertFalse(userDefaults.isAWSConfigured)
        XCTAssertFalse(userDefaults.validateAWSConfig())
        XCTAssertEqual(userDefaults.awsRegion, "")
        XCTAssertEqual(userDefaults.awsBucket, "")
        XCTAssertEqual(userDefaults.awsEncryptionSecret, "")
        XCTAssertEqual(userDefaults.awsAccessKeyId, "")
        XCTAssertEqual(userDefaults.awsSecretAccessKey, "")
        XCTAssertEqual(userDefaults.awsProfileName, "")
    }
    
    func testAWSAuthMethodDisplayNames() {
        XCTAssertEqual(UserDefaults.AWSAuthMethod.accessKey.displayName, "Access Key")
        XCTAssertEqual(UserDefaults.AWSAuthMethod.profile.displayName, "AWS Profile")
        XCTAssertEqual(UserDefaults.AWSAuthMethod.defaultCredentials.displayName, "Default Credentials")
    }
}
