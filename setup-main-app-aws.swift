#!/usr/bin/env swift

import Foundation

print("🔧 Setting up AWS S3 credentials for TaskChampion main app...")

// AWS configuration that matches our working test
let awsConfig = [
    "awsRegion": "us-east-1",
    "awsBucket": "taskchampion-sync-emiller-taskchamp-app", 
    "awsEncryptionSecret": "real-encryption-secret-key-for-testing",
    "awsAuthMethod": "defaultCredentials", // Uses the same credentials as our working test
    "awsAvoidSnapshots": false,
    "isAWSConfigured": true
] as [String: Any]

// Set up UserDefaults for the main app to use
for (key, value) in awsConfig {
    UserDefaults.standard.set(value, forKey: key)
    print("✅ Set \(key) = \(value)")
}

// Sync to disk
UserDefaults.standard.synchronize()

print("🎉 AWS S3 credentials configured for main app!")
print("")
print("Configuration:")
print("  Region: us-east-1")
print("  Bucket: taskchampion-sync-emiller-taskchamp-app")
print("  Auth Method: Default Credentials (uses AWS CLI credentials)")
print("  Encryption: PBKDF2 + ChaCha20-Poly1305 AEAD")
print("")
print("The app will now use the same AWS credentials as our working S3 sync test.")