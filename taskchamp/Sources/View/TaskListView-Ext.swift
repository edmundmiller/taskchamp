import SwiftUI
import taskchampShared
import UIKit

extension TaskListView {
    var searchedTasks: [TCTask] {
        if searchText.isEmpty {
            return tasks
        }
        return tasks.filter { $0.description.localizedCaseInsensitiveContains(searchText) ||
            $0.project?.localizedCaseInsensitiveContains(searchText) ?? false ||
            $0.priority?.rawValue.localizedCaseInsensitiveContains(searchText) ?? false ||
            $0.localDate.localizedCaseInsensitiveContains(searchText)
            || $0.status.rawValue.localizedCaseInsensitiveContains(searchText)
            || $0.project?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    var isEditModeActive: Bool {
        return editMode.isEditing == true
    }

    func setDbUrl() throws {
        guard let path = taskChampionFileUrlString else {
            throw TCError.genericError("No access or path")
        }
        try DBService.shared.setDbUrl(path)
    }

    func updateTasks(_ uuids: Set<String>, withStatus newStatus: TCTask.Status) {
        do {
            try setDbUrl()
            try DBService.shared.updatePendingTasks(uuids, withStatus: newStatus)
            NotificationService.shared.removeNotifications(for: Array(uuids))
            updateTasks()
        } catch {
            print(error)
        }
    }

    func updateTasks() {
        do {
            try setDbUrl()
            let newTasks = try DBService.shared.getTasks(
                sortType: sortType,
                filter: selectedFilter
            )
            if newTasks == tasks {
                return
            }
            withAnimation {
                tasks = newTasks
            }
        } catch {
            print("Error updating tasks: \(error)")
            // Note: Now using fallback to local documents directory when iCloud unavailable
        }
    }

    func copyDatabaseIfNeeded() {
        do {
            if taskChampionFileUrlString != nil {
                updateTasks()
                return
            }
            taskChampionFileUrlString = try FileService.shared.copyDatabaseIfNeededAndGetDestinationPath()
            updateTasks()
            
            // Create sample tasks if this is the first launch (no tasks exist)
            createSampleTasksIfNeeded()
            
            NotificationService.shared.requestAuthorization { success, error in
                if success {
                    print("Notification Authorization granted")
                    Task {
                        let pending = try DBService.shared.getTasks(
                            sortType: sortType,
                            filter: .defaultFilter
                        )
                        await NotificationService.shared.createReminderForTasks(tasks: pending)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
            return
        } catch {
            print(error)
        }
    }
    
    private func createSampleTasksIfNeeded() {
        print("🔥🔥🔥 CREATESAMPLCTASKSIFNEEDED CALLED - THIS PROVES THE FILE IS UPDATED!")
        Task {
            do {
                // Check if we have any tasks already using TaskChampion
                let existingTasks = try DBService.shared.getTasks()
                
                // Only create sample tasks if none exist
                if existingTasks.isEmpty {
                    print("🚀 No tasks found - creating sample tasks to verify TaskChampion integration")
                    
                    // Try creating just one simple task first to debug the issue
                    let simpleTask = TCTask(
                        uuid: UUID().uuidString.uppercased(), // Ensure UUID is uppercase
                        description: "Welcome to TaskChamp! This is a sample task.",
                        status: .pending
                    )
                    
                    print("📝 Creating simple sample task: '\(simpleTask.description)' (uuid: \(simpleTask.uuid))")
                    print("🔍 Task details: project=\(simpleTask.project ?? "nil"), priority=\(simpleTask.priority?.rawValue ?? "nil")")
                    
                    // COMPLETELY BYPASS DBService - DO NOT USE IT
                    print("🔥 BYPASSING DBService COMPLETELY!")
                    print("🔥 This should NOT call DBService.createTask!")
                    
                    print("🔥 About to call TaskchampionService.shared directly...")
                    let taskchampionService = TaskchampionService.shared
                    print("🔥 Got TaskchampionService instance successfully")
                    
                    print("🔥 About to test createTask on TaskchampionService directly...")
                    try taskchampionService.createTask(task: simpleTask)
                    print("🔥 Direct TaskchampionService.createTask worked!")
                print("✅ Simple sample task created successfully")
                
                // If that works, create the rest
                let remainingTasks = [
                    TCTask(
                        uuid: UUID().uuidString.uppercased(),
                        project: "Getting Started", 
                        description: "Complete this task to test the TaskChampion integration",
                        status: .pending,
                        priority: .high
                    ),
                    TCTask(
                        uuid: UUID().uuidString.uppercased(),
                        description: "Add your own tasks and start organizing your workflow",
                        status: .pending,
                        priority: .low
                    )
                ]
                
                    for task in remainingTasks {
                        print("📝 Creating additional sample task: '\(task.description)' (uuid: \(task.uuid))")
                        try setDbUrl()
                        try DBService.shared.createTask(task: task)
                        print("✅ Additional sample task created successfully")
                    }
                    
                    print("🎉 Sample tasks created successfully! TaskChampion integration is working.")
                    
                    // Refresh the task list to show the new sample tasks
                    await MainActor.run {
                        updateTasks()
                    }
                } else {
                    print("📋 Found \(existingTasks.count) existing tasks - skipping sample task creation")
                }
            } catch {
                print("❌ Failed to create sample tasks: \(error)")
                print("🔍 Error type: \(type(of: error))")
                print("🔍 Error description: \(error.localizedDescription)")
                print("💡 This suggests there may be an issue with the TaskChampion integration")
            }
        }
    }

    func handleDeepLink(url: URL) {
        Task {
            guard url.scheme == "taskchamp", url.host == "task" else {
                return
            }

            let uuidString = url.pathComponents[1]

            if uuidString == "new" {
                isShowingCreateTaskView = true
                return
            }

            do {
                try setDbUrl()
                let task = try DBService.shared.getTask(uuid: uuidString)
                pathStore.path.append(task)
            } catch {
                print(error)
            }
        }
    }

    // MARK: - AWS Sync Functions

    func performAWSSync() {
        guard !isSyncInProgress else { return }

        isSyncInProgress = true

        Task {
            do {
                // Initialize the replica if needed
                if let path = taskChampionFileUrlString {
                    TaskchampionService.shared.setDbUrl(path)
                }

                try await TaskchampionService.shared.syncToAWSFromUserDefaults()

                await MainActor.run {
                    syncMessage = "✅ AWS sync completed successfully!"
                    showSyncAlert = true
                    isSyncInProgress = false

                    // Refresh tasks after sync
                    updateTasks()
                }
            } catch {
                await MainActor.run {
                    syncMessage = "❌ AWS sync failed: \(error.localizedDescription)"
                    showSyncAlert = true
                    isSyncInProgress = false
                }
            }
        }
    }
}
