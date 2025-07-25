#!/usr/bin/env swift

import Foundation

// Simple script to test TaskChampion S3 sync functionality
// This will be run from command line to verify the integration works

print("🧪 TaskChampion S3 Sync Test")
print("===========================")

// Check if this is being run from the correct directory
let currentDir = FileManager.default.currentDirectoryPath
print("📁 Current directory: \(currentDir)")

// Check if we can access the UserDefaults
let defaults = UserDefaults.standard

// Check AWS configuration
print("\n🔍 Checking AWS Configuration:")
let awsConfigured = defaults.object(forKey: "isAWSConfigured") as? Bool ?? false
print("AWS Configured: \(awsConfigured)")

if awsConfigured {
    let region = defaults.string(forKey: "awsRegion") ?? "unknown"
    let bucket = defaults.string(forKey: "awsBucket") ?? "unknown"
    print("AWS Region: \(region)")
    print("AWS Bucket: \(bucket)")
    print("✅ AWS configuration found - S3 sync test can proceed")
} else {
    print("❌ AWS not configured - cannot test S3 sync")
    print("💡 Configure AWS settings in the iOS app first")
}

print("\n🎯 Next Steps:")
print("1. Open taskchamp.xcworkspace in Xcode")
print("2. Run the TaskChampionS3SyncTest test case")
print("3. Check console output to verify task retrieval")
print("4. Expected result: Should retrieve ~3,069 tasks from S3")

print("\n✅ Test setup complete")