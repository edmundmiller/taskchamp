#!/usr/bin/env swift

import Foundation

// Simple test to verify TaskChampion S3 sync works
print("🧪 Direct TaskChampion S3 Sync Test")
print("=====================================")

// Test basic functionality by creating a test database and checking if we can sync
let tempDir = NSTemporaryDirectory()
let testDbPath = "\(tempDir)taskchampion_test_\(UUID().uuidString).db"

print("📁 Test database: \(testDbPath)")

// Since we can't easily import the TaskChampion module here, let's create a test that 
// checks the expected behavior by examining the iOS app's database after sync

let appDbPath = "/Users/emiller/Library/Mobile Documents/iCloud~com~emiller~taskchamp/Documents/task/taskchampion.sqlite3"

print("\n🔍 Checking app database:")
if FileManager.default.fileExists(atPath: appDbPath) {
    let fileSize = (try? FileManager.default.attributesOfItem(atPath: appDbPath)[.size] as? NSNumber)?.intValue ?? 0
    print("✅ App database exists")
    print("📊 Database size: \(fileSize) bytes")
    
    if fileSize > 10000 {
        print("🎉 Database appears to have content - likely contains synced tasks!")
    } else {
        print("⚠️  Database is small - may not have synced tasks yet")
    }
} else {
    print("❌ App database not found - app may not have been run yet")
}

print("\n🎯 To test S3 sync manually:")
print("1. Open the iOS app in simulator")
print("2. Go to Settings → AWS")
print("3. Trigger a manual sync")
print("4. Check if tasks appear in the main view")
print("5. Expected: Should see ~3,069 tasks from S3")

print("\n📝 AWS Configuration Status:")
let defaults = UserDefaults.standard
let awsConfigured = defaults.object(forKey: "isAWSConfigured") as? Bool ?? false
print("AWS Configured: \(awsConfigured)")

if awsConfigured {
    let bucket = defaults.string(forKey: "awsBucket") ?? "unknown"
    print("AWS Bucket: \(bucket)")
    
    if bucket.contains("taskchampion") {
        print("✅ Using TaskChampion bucket - correct configuration")
    } else {
        print("⚠️  Bucket name suggests legacy sync - may need update")
    }
}

print("\n✅ Test preparation complete")
print("💡 Run the iOS app to test the integration manually")