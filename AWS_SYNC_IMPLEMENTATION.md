# AWS Sync Implementation for Taskchamp

## Overview

This implementation adds AWS S3 sync support to Taskchamp, providing compatibility with Taskwarrior 3.3.0's AWS sync feature. Users can now sync their tasks to Amazon S3 buckets using multiple authentication methods.

## Features Implemented

### 1. AWS Configuration Model (`AWSConfig.swift`)
- **AWSConfig**: For access key authentication
- **AWSProfileConfig**: For AWS profile authentication  
- **UserDefaults Extensions**: Secure storage of AWS configuration
- **AWSAuthMethod Enum**: Support for Access Key, Profile, and Default Credentials

### 2. AWS Sync Service (`TaskchampionService.swift`)
- `syncToAWS(config: AWSConfig)`: Sync with access key credentials
- `syncToAWS(profileConfig: AWSProfileConfig)`: Sync with AWS profile
- `syncToAWSWithDefaultCredentials()`: Sync with default credentials
- `syncToAWSFromUserDefaults()`: Sync using saved configuration
- `needsSync()`: Check if sync is needed
- `getLocalOperationsCount()`: Get count of local operations

### 3. AWS Settings View (`AWSSettingsView.swift`)
- Configuration interface for AWS settings
- Support for all three authentication methods
- Built-in configuration validation
- Test sync functionality
- Comprehensive help documentation

### 4. Integration with TaskListView
- Added AWS settings menu option
- Manual sync trigger button
- Sync status indicators
- Error handling and feedback

## Usage

### Configuration

1. **Open AWS Settings**: Go to the Options menu in TaskListView → "AWS Sync Settings"

2. **Choose Authentication Method**:
   - **Access Key**: Direct AWS access key and secret
   - **AWS Profile**: Uses credentials from `~/.aws/credentials`
   - **Default Credentials**: Uses environment variables or IAM roles

3. **Configure Basic Settings**:
   - **AWS Region**: e.g., `us-west-2`
   - **S3 Bucket Name**: Your S3 bucket for task storage
   - **Encryption Secret**: Secret for encrypting task data

4. **Authentication-specific Settings**:
   - For Access Key: Enter Access Key ID and Secret Access Key
   - For AWS Profile: Enter profile name
   - For Default Credentials: No additional configuration needed

### Syncing

1. **Manual Sync**: Options menu → "Sync to AWS"
2. **Test Configuration**: Use "Test Sync" button in AWS Settings
3. **Automatic Sync**: Can be triggered programmatically

## Taskwarrior 3.3.0 Compatibility

This implementation is equivalent to the following Taskwarrior configuration:

```bash
$ task config sync.aws.region              us-west-2
$ task config sync.aws.bucket              my-taskwarrior-bucket
$ task config sync.aws.access_key_id       AKIAIOSFODNN7EXAMPLE
$ task config sync.aws.secret_access_key   wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

## Security

- AWS credentials are stored securely using iOS UserDefaults
- Encryption secret is used to encrypt task data before uploading to S3
- No credentials are logged or exposed in error messages

## Error Handling

- Comprehensive error messages for sync failures
- Configuration validation before sync attempts
- User-friendly error reporting in the UI
- Graceful handling of network issues

## API Reference

### AWSConfig
```swift
public struct AWSConfig: Codable {
    public let region: String
    public let bucket: String
    public let accessKeyId: String
    public let secretAccessKey: String
    public let encryptionSecret: String
    public let avoidSnapshots: Bool
}
```

### AWSProfileConfig
```swift
public struct AWSProfileConfig: Codable {
    public let region: String
    public let bucket: String
    public let profileName: String
    public let encryptionSecret: String
    public let avoidSnapshots: Bool
}
```

### UserDefaults Extensions
```swift
extension UserDefaults {
    public var awsRegion: String { get set }
    public var awsBucket: String { get set }
    public var awsAccessKeyId: String { get set }
    public var awsSecretAccessKey: String { get set }
    public var awsEncryptionSecret: String { get set }
    public var awsProfileName: String { get set }
    public var awsAuthMethod: AWSAuthMethod { get set }
    public var isAWSConfigured: Bool { get set }
    
    public func getAWSConfig() -> AWSConfig?
    public func getAWSProfileConfig() -> AWSProfileConfig?
    public func validateAWSConfig() -> Bool
    public func clearAWSConfig()
}
```

### TaskchampionService Methods
```swift
public func syncToAWS(config: AWSConfig) throws
public func syncToAWS(profileConfig: AWSProfileConfig) throws
public func syncToAWSWithDefaultCredentials(region: String, bucket: String, encryptionSecret: String, avoidSnapshots: Bool = false) throws
public func syncToAWSFromUserDefaults() throws
public func needsSync() throws -> Bool
public func getLocalOperationsCount() throws -> UInt32
```

## Testing

A comprehensive test suite is included (`AWSConfigTests.swift`) that covers:

- Configuration model creation and validation
- UserDefaults storage and retrieval
- All authentication methods
- Invalid configuration handling
- Configuration clearing

## Prerequisites

- AWS account with S3 access
- S3 bucket for storing tasks
- AWS credentials configured (varies by authentication method)
- iOS 17.0+
- Taskchampion library dependency

## Installation

1. The implementation is already integrated into the project
2. AWS configuration is accessible through the TaskListView options menu
3. No additional dependencies required beyond existing Taskchampion library

## Future Enhancements

- Automatic sync intervals
- Sync conflict resolution
- Sync status indicators in the UI
- Background sync support
- Multiple bucket support
- Sync history and logs

## Troubleshooting

### Common Issues

1. **"AWS sync is not configured"**
   - Ensure all required fields are filled in AWS Settings
   - Check that "Save" was clicked after configuration

2. **"AWS configuration is invalid"**
   - Verify AWS credentials are correct
   - Check that S3 bucket exists and is accessible
   - Ensure encryption secret is not empty

3. **"No replica available"**
   - Task database may not be initialized
   - Try refreshing the task list

4. **Network-related errors**
   - Check internet connection
   - Verify AWS service availability
   - Check firewall/proxy settings

### AWS Permission Requirements

Your AWS credentials need the following S3 permissions:
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:ListBucket`

## Contributing

When contributing to this implementation:

1. Follow existing code patterns and naming conventions
2. Add appropriate error handling and logging
3. Update tests for any new functionality
4. Ensure backward compatibility with existing configurations
5. Update documentation for any API changes

## License

This implementation follows the same license as the main Taskchamp project.
