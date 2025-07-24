import Foundation
import SwiftUI
import taskchampShared

struct AWSSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var region: String
    @State private var bucket: String
    @State private var accessKeyId: String
    @State private var secretAccessKey: String
    @State private var encryptionSecret: String
    @State private var avoidSnapshots: Bool
    @State private var showAWSInfoPopover = false
    @State private var showTestSyncAlert = false
    @State private var testSyncMessage = ""
    @State private var isTestingSyncInProgress = false
    
    init() {
        let defaults = UserDefaults.standard
        
        #if targetEnvironment(simulator)
        // Pre-populate with test values when running in simulator
        self._region = State(initialValue: defaults.awsRegion.isEmpty ? "us-east-1" : defaults.awsRegion)
        self._bucket = State(initialValue: defaults.awsBucket.isEmpty ? "taskchamp-test-bucket" : defaults.awsBucket)
        self._encryptionSecret = State(initialValue: defaults.awsEncryptionSecret.isEmpty ? "test-encryption-secret-simulator" : defaults.awsEncryptionSecret)
        self._accessKeyId = State(initialValue: defaults.awsAccessKeyId)
        self._secretAccessKey = State(initialValue: defaults.awsSecretAccessKey)
        self._avoidSnapshots = State(initialValue: defaults.awsAvoidSnapshots)
        #else
        // Production - use saved values or empty
        self._region = State(initialValue: defaults.awsRegion)
        self._bucket = State(initialValue: defaults.awsBucket)
        self._accessKeyId = State(initialValue: defaults.awsAccessKeyId)
        self._secretAccessKey = State(initialValue: defaults.awsSecretAccessKey)
        self._encryptionSecret = State(initialValue: defaults.awsEncryptionSecret)
        self._avoidSnapshots = State(initialValue: defaults.awsAvoidSnapshots)
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                // Information Section
                Section {
                    Text(
                        "Configure AWS S3 sync for Taskwarrior 3.3.0 compatibility." +
                            "\n\nThis allows you to sync your tasks with an Amazon S3 bucket, " +
                            "just like the native Taskwarrior AWS sync feature."
                    )
                    .foregroundStyle(.secondary)

                    Button {
                        showAWSInfoPopover.toggle()
                    } label: {
                        Label("Help", systemImage: SFSymbols.questionmarkCircle.rawValue)
                            .labelStyle(.titleAndIcon)
                    }
                    .popover(isPresented: $showAWSInfoPopover, attachmentAnchor: .point(.bottom)) {
                        AWSHelpView()
                    }
                }

                // Basic Configuration Section
                Section("Basic Configuration") {
                    TextField("AWS Region (e.g., us-west-2)", text: $region)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("S3 Bucket Name", text: $bucket)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("Encryption Secret", text: $encryptionSecret)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                // Access Key Configuration
                Section("Access Key Configuration") {
                    TextField("Access Key ID", text: $accessKeyId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Secret Access Key", text: $secretAccessKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                // Advanced Options Section
                Section("Advanced Options") {
                    Toggle("Avoid Snapshots", isOn: $avoidSnapshots)

                    Text("Improves performance by avoiding snapshot operations during sync")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Test Sync Section
                Section("Test Configuration") {
                    Button("Test Sync") {
                        testAWSSync()
                    }
                    .disabled(!isConfigurationValid || isTestingSyncInProgress)

                    if isTestingSyncInProgress {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing sync...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                        dismiss()
                    }
                    .disabled(!isConfigurationValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("AWS Sync Settings")
            .alert("Sync Test Result", isPresented: $showTestSyncAlert) {
                Button("OK") {}
            } message: {
                Text(testSyncMessage)
            }
        }
    }

    private var isConfigurationValid: Bool {
        return !region.isEmpty && 
               !bucket.isEmpty && 
               !encryptionSecret.isEmpty && 
               !accessKeyId.isEmpty && 
               !secretAccessKey.isEmpty
    }

    private func saveConfiguration() {
        let userDefaults = UserDefaults.standard

        userDefaults.awsRegion = region
        userDefaults.awsBucket = bucket
        userDefaults.awsEncryptionSecret = encryptionSecret
        userDefaults.awsAvoidSnapshots = avoidSnapshots
        userDefaults.awsAccessKeyId = accessKeyId
        userDefaults.awsSecretAccessKey = secretAccessKey
        userDefaults.awsAuthMethod = .accessKey // Always use access key method
        
        // Clear deprecated profile name
        userDefaults.awsProfileName = ""
        
        userDefaults.isAWSConfigured = true
    }

    private func testAWSSync() {
        isTestingSyncInProgress = true

        // Save current configuration temporarily
        let tempDefaults = UserDefaults.standard
        let oldRegion = tempDefaults.awsRegion
        let oldBucket = tempDefaults.awsBucket
        let oldEncryptionSecret = tempDefaults.awsEncryptionSecret
        let oldAvoidSnapshots = tempDefaults.awsAvoidSnapshots
        let oldAccessKeyId = tempDefaults.awsAccessKeyId
        let oldSecretAccessKey = tempDefaults.awsSecretAccessKey
        let oldIsConfigured = tempDefaults.isAWSConfigured

        // Set temporary configuration
        saveConfiguration()

        // Test sync using async/await
        Task {
            do {
                try await TaskchampionService.shared.syncToAWSFromUserDefaults()

                await MainActor.run {
                    self.testSyncMessage = "✅ AWS sync test successful!"
                    self.showTestSyncAlert = true
                    self.isTestingSyncInProgress = false
                }
            } catch {
                await MainActor.run {
                    self.testSyncMessage = "❌ AWS sync test failed: \(error.localizedDescription)"
                    self.showTestSyncAlert = true
                    self.isTestingSyncInProgress = false
                }
            }

            // Restore original configuration after test
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                tempDefaults.awsRegion = oldRegion
                tempDefaults.awsBucket = oldBucket
                tempDefaults.awsEncryptionSecret = oldEncryptionSecret
                tempDefaults.awsAvoidSnapshots = oldAvoidSnapshots
                tempDefaults.awsAccessKeyId = oldAccessKeyId
                tempDefaults.awsSecretAccessKey = oldSecretAccessKey
                tempDefaults.isAWSConfigured = oldIsConfigured
            }
        }
    }
}

// MARK: - AWS Help View

struct AWSHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("AWS S3 Sync Setup")
                    .font(.title2)
                    .bold()
                    .padding(.bottom, 5)

                Group {
                    Text("Prerequisites:")
                        .font(.headline)

                    Text("1. An AWS account with S3 access")
                    Text("2. An S3 bucket for storing tasks")
                    Text("3. AWS credentials configured")

                    Text("Authentication:")
                        .font(.headline)
                        .padding(.top)

                    Text("Uses direct AWS access key and secret key authentication for secure access to your S3 bucket.")

                    Text("Equivalent Taskwarrior 3.3.0 Configuration:")
                        .font(.headline)
                        .padding(.top)

                    Text("""
                    $ task config sync.aws.region us-west-2
                    $ task config sync.aws.bucket my-bucket
                    $ task config sync.aws.access_key_id AKIAXXXXX
                    $ task config sync.aws.secret_access_key xxxxx
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    Text("Security Note:")
                        .font(.headline)
                        .padding(.top)

                    Text(
                        "Your AWS credentials are stored securely in the iOS Keychain. The encryption secret is used to encrypt your task data before uploading to S3."
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 500)
        .presentationCompactAdaptation(.popover)
    }
}

#Preview {
    AWSSettingsView()
}
