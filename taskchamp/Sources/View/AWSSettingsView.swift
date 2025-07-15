import Foundation
import SwiftUI
import taskchampShared

struct AWSSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var region = UserDefaults.standard.awsRegion
    @State private var bucket = UserDefaults.standard.awsBucket
    @State private var accessKeyId = UserDefaults.standard.awsAccessKeyId
    @State private var secretAccessKey = UserDefaults.standard.awsSecretAccessKey
    @State private var encryptionSecret = UserDefaults.standard.awsEncryptionSecret
    @State private var profileName = UserDefaults.standard.awsProfileName
    @State private var avoidSnapshots = UserDefaults.standard.awsAvoidSnapshots
    @State private var authMethod = UserDefaults.standard.awsAuthMethod
    @State private var showAWSInfoPopover = false
    @State private var showTestSyncAlert = false
    @State private var testSyncMessage = ""
    @State private var isTestingSyncInProgress = false

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

                // Authentication Method Section
                Section("Authentication Method") {
                    Picker("Auth Method", selection: $authMethod) {
                        ForEach(UserDefaults.AWSAuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
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

                // Authentication-specific Configuration
                switch authMethod {
                case .accessKey:
                    Section("Access Key Configuration") {
                        TextField("Access Key ID", text: $accessKeyId)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        SecureField("Secret Access Key", text: $secretAccessKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                case .profile:
                    Section("AWS Profile Configuration") {
                        TextField("Profile Name", text: $profileName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        Text("Uses AWS credentials from ~/.aws/credentials")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                case .defaultCredentials:
                    Section("Default Credentials") {
                        Text(
                            "Uses default AWS credentials from environment variables, IAM roles, or other default sources"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
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
        guard !region.isEmpty, !bucket.isEmpty, !encryptionSecret.isEmpty else {
            return false
        }

        switch authMethod {
        case .accessKey:
            return !accessKeyId.isEmpty && !secretAccessKey.isEmpty
        case .profile:
            return !profileName.isEmpty
        case .defaultCredentials:
            return true
        }
    }

    private func saveConfiguration() {
        let userDefaults = UserDefaults.standard

        userDefaults.awsRegion = region
        userDefaults.awsBucket = bucket
        userDefaults.awsEncryptionSecret = encryptionSecret
        userDefaults.awsAvoidSnapshots = avoidSnapshots
        userDefaults.awsAuthMethod = authMethod

        switch authMethod {
        case .accessKey:
            userDefaults.awsAccessKeyId = accessKeyId
            userDefaults.awsSecretAccessKey = secretAccessKey
            userDefaults.awsProfileName = "" // Clear profile name

        case .profile:
            userDefaults.awsProfileName = profileName
            userDefaults.awsAccessKeyId = "" // Clear access keys
            userDefaults.awsSecretAccessKey = ""

        case .defaultCredentials:
            userDefaults.awsAccessKeyId = "" // Clear both
            userDefaults.awsSecretAccessKey = ""
            userDefaults.awsProfileName = ""
        }

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
        let oldAuthMethod = tempDefaults.awsAuthMethod
        let oldAccessKeyId = tempDefaults.awsAccessKeyId
        let oldSecretAccessKey = tempDefaults.awsSecretAccessKey
        let oldProfileName = tempDefaults.awsProfileName
        let oldIsConfigured = tempDefaults.isAWSConfigured

        // Set temporary configuration
        saveConfiguration()

        // Test sync
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try TaskchampionService.shared.syncToAWSFromUserDefaults()

                DispatchQueue.main.async {
                    self.testSyncMessage = "✅ AWS sync test successful!"
                    self.showTestSyncAlert = true
                    self.isTestingSyncInProgress = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.testSyncMessage = "❌ AWS sync test failed: \(error.localizedDescription)"
                    self.showTestSyncAlert = true
                    self.isTestingSyncInProgress = false
                }
            }
        }

        // Restore original configuration after test
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tempDefaults.awsRegion = oldRegion
            tempDefaults.awsBucket = oldBucket
            tempDefaults.awsEncryptionSecret = oldEncryptionSecret
            tempDefaults.awsAvoidSnapshots = oldAvoidSnapshots
            tempDefaults.awsAuthMethod = oldAuthMethod
            tempDefaults.awsAccessKeyId = oldAccessKeyId
            tempDefaults.awsSecretAccessKey = oldSecretAccessKey
            tempDefaults.awsProfileName = oldProfileName
            tempDefaults.isAWSConfigured = oldIsConfigured
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

                    Text("Authentication Methods:")
                        .font(.headline)
                        .padding(.top)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Access Key**: Direct AWS access key and secret")
                        Text("**AWS Profile**: Uses credentials from ~/.aws/credentials")
                        Text("**Default Credentials**: Uses environment variables or IAM roles")
                    }

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
