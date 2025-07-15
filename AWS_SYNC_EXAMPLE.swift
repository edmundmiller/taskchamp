import Foundation
import taskchampShared

// MARK: - AWS Sync Usage Examples

class AWSyncExamples {
    
    // MARK: - Configuration Examples
    
    func configureAWSWithAccessKey() {
        let userDefaults = UserDefaults.standard
        
        // Configure AWS with access key
        userDefaults.awsRegion = "us-west-2"
        userDefaults.awsBucket = "my-taskwarrior-bucket"
        userDefaults.awsAccessKeyId = "AKIAIOSFODNN7EXAMPLE"
        userDefaults.awsSecretAccessKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        userDefaults.awsEncryptionSecret = "my-secure-encryption-secret"
        userDefaults.awsAuthMethod = .accessKey
        userDefaults.isAWSConfigured = true
        
        print("AWS access key configuration saved")
    }
    
    func configureAWSWithProfile() {
        let userDefaults = UserDefaults.standard
        
        // Configure AWS with profile
        userDefaults.awsRegion = "us-east-1"
        userDefaults.awsBucket = "my-taskwarrior-bucket"
        userDefaults.awsProfileName = "my-aws-profile"
        userDefaults.awsEncryptionSecret = "my-secure-encryption-secret"
        userDefaults.awsAuthMethod = .profile
        userDefaults.isAWSConfigured = true
        
        print("AWS profile configuration saved")
    }
    
    func configureAWSWithDefaultCredentials() {
        let userDefaults = UserDefaults.standard
        
        // Configure AWS with default credentials
        userDefaults.awsRegion = "us-west-2"
        userDefaults.awsBucket = "my-taskwarrior-bucket"
        userDefaults.awsEncryptionSecret = "my-secure-encryption-secret"
        userDefaults.awsAuthMethod = .defaultCredentials
        userDefaults.isAWSConfigured = true
        
        print("AWS default credentials configuration saved")
    }
    
    // MARK: - Sync Examples
    
    func syncWithAccessKey() {
        let config = AWSConfig(
            region: "us-west-2",
            bucket: "my-taskwarrior-bucket",
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            encryptionSecret: "my-secure-encryption-secret"
        )
        
        do {
            try TaskchampionService.shared.syncToAWS(config: config)
            print("✅ Sync with access key successful")
        } catch {
            print("❌ Sync with access key failed: \(error.localizedDescription)")
        }
    }
    
    func syncWithProfile() {
        let config = AWSProfileConfig(
            region: "us-east-1",
            bucket: "my-taskwarrior-bucket",
            profileName: "my-aws-profile",
            encryptionSecret: "my-secure-encryption-secret"
        )
        
        do {
            try TaskchampionService.shared.syncToAWS(profileConfig: config)
            print("✅ Sync with profile successful")
        } catch {
            print("❌ Sync with profile failed: \(error.localizedDescription)")
        }
    }
    
    func syncWithDefaultCredentials() {
        do {
            try TaskchampionService.shared.syncToAWSWithDefaultCredentials(
                region: "us-west-2",
                bucket: "my-taskwarrior-bucket",
                encryptionSecret: "my-secure-encryption-secret"
            )
            print("✅ Sync with default credentials successful")
        } catch {
            print("❌ Sync with default credentials failed: \(error.localizedDescription)")
        }
    }
    
    func syncFromUserDefaults() {
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ Sync from user defaults successful")
        } catch {
            print("❌ Sync from user defaults failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Examples
    
    func checkIfSyncIsNeeded() {
        do {
            let needsSync = try TaskchampionService.shared.needsSync()
            if needsSync {
                print("📤 Sync is needed - there are local changes")
                let count = try TaskchampionService.shared.getLocalOperationsCount()
                print("📊 Local operations count: \(count)")
            } else {
                print("✅ No sync needed - everything is up to date")
            }
        } catch {
            print("❌ Error checking sync status: \(error.localizedDescription)")
        }
    }
    
    func validateCurrentConfiguration() {
        let userDefaults = UserDefaults.standard
        
        if userDefaults.isAWSConfigured {
            if userDefaults.validateAWSConfig() {
                print("✅ AWS configuration is valid")
                print("🔧 Auth method: \(userDefaults.awsAuthMethod.displayName)")
                print("🌍 Region: \(userDefaults.awsRegion)")
                print("🪣 Bucket: \(userDefaults.awsBucket)")
            } else {
                print("❌ AWS configuration is invalid")
            }
        } else {
            print("⚠️ AWS is not configured")
        }
    }
    
    func clearConfiguration() {
        UserDefaults.standard.clearAWSConfig()
        print("🗑️ AWS configuration cleared")
    }
    
    // MARK: - Complete Workflow Example
    
    func completeWorkflowExample() {
        print("🚀 Starting complete AWS sync workflow example")
        
        // 1. Configure AWS
        configureAWSWithAccessKey()
        
        // 2. Validate configuration
        validateCurrentConfiguration()
        
        // 3. Check if sync is needed
        checkIfSyncIsNeeded()
        
        // 4. Perform sync
        syncFromUserDefaults()
        
        // 5. Check sync status again
        checkIfSyncIsNeeded()
        
        print("✅ Complete workflow example finished")
    }
    
    // MARK: - Error Handling Example
    
    func errorHandlingExample() {
        do {
            try TaskchampionService.shared.syncToAWSFromUserDefaults()
            print("✅ Sync successful")
        } catch {
            handleSyncError(error)
        }
    }
    
    private func handleSyncError(_ error: Error) {
        let errorMessage = error.localizedDescription
        
        if errorMessage.contains("not configured") {
            print("⚠️ AWS sync is not configured. Please configure AWS settings first.")
        } else if errorMessage.contains("invalid") {
            print("❌ AWS configuration is invalid. Please check your settings.")
        } else if errorMessage.contains("No replica available") {
            print("🔄 Task database not initialized. Please refresh the task list.")
        } else if errorMessage.contains("network") || errorMessage.contains("connection") {
            print("🌐 Network error. Please check your internet connection.")
        } else if errorMessage.contains("credentials") {
            print("🔐 Authentication error. Please check your AWS credentials.")
        } else if errorMessage.contains("bucket") {
            print("🪣 S3 bucket error. Please check if the bucket exists and is accessible.")
        } else {
            print("❌ Sync failed: \(errorMessage)")
        }
    }
}

// MARK: - TaskListView Integration Example

extension TaskListView {
    
    // Example of how the AWS sync is integrated into TaskListView
    func exampleAWSIntegration() {
        // This shows how the AWS sync functionality is integrated
        // into the main TaskListView (already implemented above)
        
        // 1. AWS Settings button in menu opens AWSSettingsView
        // 2. Manual sync button triggers performAWSSync()
        // 3. Sync status is shown in UI
        // 4. Error handling with user-friendly messages
    }
    
    // Example of how to add automatic sync on app launch
    func syncOnAppLaunch() {
        guard UserDefaults.standard.isAWSConfigured else {
            print("AWS sync not configured")
            return
        }
        
        Task {
            do {
                let needsSync = try TaskchampionService.shared.needsSync()
                if needsSync {
                    try TaskchampionService.shared.syncToAWSFromUserDefaults()
                    print("✅ Automatic sync completed")
                }
            } catch {
                print("❌ Automatic sync failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - SwiftUI Integration Example

import SwiftUI

struct AWSyncStatusView: View {
    @State private var syncStatus: String = "Ready"
    @State private var isConfigured: Bool = false
    
    var body: some View {
        VStack {
            Text("AWS Sync Status: \(syncStatus)")
                .padding()
            
            if isConfigured {
                Button("Sync Now") {
                    performSync()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("AWS not configured")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            checkConfiguration()
        }
    }
    
    private func checkConfiguration() {
        isConfigured = UserDefaults.standard.isAWSConfigured
    }
    
    private func performSync() {
        syncStatus = "Syncing..."
        
        Task {
            do {
                try TaskchampionService.shared.syncToAWSFromUserDefaults()
                await MainActor.run {
                    syncStatus = "Sync completed"
                }
            } catch {
                await MainActor.run {
                    syncStatus = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
