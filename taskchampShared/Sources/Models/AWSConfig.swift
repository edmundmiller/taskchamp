import Foundation

public struct AWSConfig: Codable {
    public let region: String
    public let bucket: String
    public let accessKeyId: String
    public let secretAccessKey: String
    public let encryptionSecret: String
    public let avoidSnapshots: Bool

    public init(
        region: String,
        bucket: String,
        accessKeyId: String,
        secretAccessKey: String,
        encryptionSecret: String,
        avoidSnapshots: Bool = false
    ) {
        self.region = region
        self.bucket = bucket
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.encryptionSecret = encryptionSecret
        self.avoidSnapshots = avoidSnapshots
    }
}

public struct AWSProfileConfig: Codable {
    public let region: String
    public let bucket: String
    public let profileName: String
    public let encryptionSecret: String
    public let avoidSnapshots: Bool

    public init(
        region: String,
        bucket: String,
        profileName: String,
        encryptionSecret: String,
        avoidSnapshots: Bool = false
    ) {
        self.region = region
        self.bucket = bucket
        self.profileName = profileName
        self.encryptionSecret = encryptionSecret
        self.avoidSnapshots = avoidSnapshots
    }
}

// MARK: - UserDefaults Extensions for AWS Config

public extension UserDefaults {
    private enum AWSConfigKeys {
        static let region = "aws.region"
        static let bucket = "aws.bucket"
        static let accessKeyId = "aws.accessKeyId"
        static let secretAccessKey = "aws.secretAccessKey"
        static let encryptionSecret = "aws.encryptionSecret"
        static let avoidSnapshots = "aws.avoidSnapshots"
        static let profileName = "aws.profileName"
        static let authMethod = "aws.authMethod"
        static let isConfigured = "aws.isConfigured"
    }

    enum AWSAuthMethod: String, CaseIterable {
        case accessKey
        case profile
        case defaultCredentials

        public var displayName: String {
            switch self {
            case .accessKey:
                return "Access Key"
            case .profile:
                return "AWS Profile"
            case .defaultCredentials:
                return "Default Credentials"
            }
        }
    }

    // MARK: - Getters

    var awsRegion: String {
        get { string(forKey: AWSConfigKeys.region) ?? "" }
        set { set(newValue, forKey: AWSConfigKeys.region) }
    }

    var awsBucket: String {
        get { string(forKey: AWSConfigKeys.bucket) ?? "" }
        set { set(newValue, forKey: AWSConfigKeys.bucket) }
    }

    var awsAccessKeyId: String {
        get { string(forKey: AWSConfigKeys.accessKeyId) ?? "" }
        set { set(newValue, forKey: AWSConfigKeys.accessKeyId) }
    }

    var awsSecretAccessKey: String {
        get { string(forKey: AWSConfigKeys.secretAccessKey) ?? "" }
        set { set(newValue, forKey: AWSConfigKeys.secretAccessKey) }
    }

    var awsEncryptionSecret: String {
        get { string(forKey: AWSConfigKeys.encryptionSecret) ?? "" }
        set { set(newValue, forKey: AWSConfigKeys.encryptionSecret) }
    }

    var awsAvoidSnapshots: Bool {
        get { bool(forKey: AWSConfigKeys.avoidSnapshots) }
        set { set(newValue, forKey: AWSConfigKeys.avoidSnapshots) }
    }

    var awsProfileName: String {
        get { string(forKey: AWSConfigKeys.profileName) ?? "" }
        set { set(newValue, forKey: AWSConfigKeys.profileName) }
    }

    var awsAuthMethod: AWSAuthMethod {
        get {
            guard let rawValue = string(forKey: AWSConfigKeys.authMethod),
                  let method = AWSAuthMethod(rawValue: rawValue) else
            {
                return .accessKey
            }
            return method
        }
        set { set(newValue.rawValue, forKey: AWSConfigKeys.authMethod) }
    }

    var isAWSConfigured: Bool {
        get { bool(forKey: AWSConfigKeys.isConfigured) }
        set { set(newValue, forKey: AWSConfigKeys.isConfigured) }
    }

    // MARK: - Helper Methods

    func getAWSConfig() -> AWSConfig? {
        guard isAWSConfigured,
              awsAuthMethod == .accessKey,
              !awsRegion.isEmpty,
              !awsBucket.isEmpty,
              !awsAccessKeyId.isEmpty,
              !awsSecretAccessKey.isEmpty,
              !awsEncryptionSecret.isEmpty else
        {
            return nil
        }

        return AWSConfig(
            region: awsRegion,
            bucket: awsBucket,
            accessKeyId: awsAccessKeyId,
            secretAccessKey: awsSecretAccessKey,
            encryptionSecret: awsEncryptionSecret,
            avoidSnapshots: awsAvoidSnapshots
        )
    }

    func getAWSProfileConfig() -> AWSProfileConfig? {
        guard isAWSConfigured,
              awsAuthMethod == .profile,
              !awsRegion.isEmpty,
              !awsBucket.isEmpty,
              !awsProfileName.isEmpty,
              !awsEncryptionSecret.isEmpty else
        {
            return nil
        }

        return AWSProfileConfig(
            region: awsRegion,
            bucket: awsBucket,
            profileName: awsProfileName,
            encryptionSecret: awsEncryptionSecret,
            avoidSnapshots: awsAvoidSnapshots
        )
    }

    func validateAWSConfig() -> Bool {
        guard !awsRegion.isEmpty,
              !awsBucket.isEmpty,
              !awsEncryptionSecret.isEmpty else
        {
            return false
        }

        switch awsAuthMethod {
        case .accessKey:
            return !awsAccessKeyId.isEmpty && !awsSecretAccessKey.isEmpty
        case .profile:
            return !awsProfileName.isEmpty
        case .defaultCredentials:
            return true
        }
    }

    func clearAWSConfig() {
        removeObject(forKey: AWSConfigKeys.region)
        removeObject(forKey: AWSConfigKeys.bucket)
        removeObject(forKey: AWSConfigKeys.accessKeyId)
        removeObject(forKey: AWSConfigKeys.secretAccessKey)
        removeObject(forKey: AWSConfigKeys.encryptionSecret)
        removeObject(forKey: AWSConfigKeys.avoidSnapshots)
        removeObject(forKey: AWSConfigKeys.profileName)
        removeObject(forKey: AWSConfigKeys.authMethod)
        removeObject(forKey: AWSConfigKeys.isConfigured)
    }
}
