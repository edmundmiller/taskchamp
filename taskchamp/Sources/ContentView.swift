import os.log
import SwiftUI
import taskchampShared

public struct ContentView: View {
    @State private var pathStore = PathStore()
    @State private var isShowingAlert = false
    @State private var selectedFilter: TCFilter = .defaultFilter

    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "ContentView")

    private func getSelectedFilter() -> TCFilter {
        do {
            if let data = UserDefaults.standard.data(forKey: "selectedFilter") {
                let res = try JSONDecoder().decode(TCFilter.self, from: data)
                return res
            } else {
                return .defaultFilter
            }
        } catch {
            return .defaultFilter
        }
    }
    
    private func createSampleTasksIfNeeded() {
        let taskService = TaskchampionService.shared
        
        // Check if we already have tasks
        Task {
            let existingTasks = await taskService.getTasks()
            if !existingTasks.isEmpty {
                logger.info("Tasks already exist, skipping sample data creation")
                return
            }
            
            // Check if we've already created sample tasks before
            let hasSampleTasks = UserDefaults.standard.bool(forKey: "hasCreatedSampleTasks")
            if hasSampleTasks {
                logger.info("Sample tasks already created before, skipping")
                return
            }
            
            logger.info("Creating sample tasks for testing")
            
            // Create sample tasks with all required parameters
            let sampleTasks = [
                TCTask(
                    uuid: UUID().uuidString,
                    project: "Development",
                    description: "Test TaskChampion integration",
                    status: .pending,
                    priority: .high,
                    due: nil,
                    obsidianNote: nil,
                    noteAnnotationKey: nil
                ),
                TCTask(
                    uuid: UUID().uuidString,
                    project: "Testing",
                    description: "Verify task persistence",
                    status: .pending,
                    priority: .medium,
                    due: nil,
                    obsidianNote: nil,
                    noteAnnotationKey: nil
                ),
                TCTask(
                    uuid: UUID().uuidString,
                    project: "Testing",
                    description: "Check S3 sync functionality",
                    status: .pending,
                    priority: .low,
                    due: nil,
                    obsidianNote: nil,
                    noteAnnotationKey: nil
                )
            ]
            
            for task in sampleTasks {
                do {
                    try await taskService.createTask(task)
                    logger.info("Created sample task: \(task.description)")
                } catch {
                    logger.error("Failed to create sample task: \(error)")
                }
            }
            
            // Mark that we've created sample tasks
            UserDefaults.standard.set(true, forKey: "hasCreatedSampleTasks")
            logger.info("Sample tasks creation completed")
        }
    }

    public var body: some View {
        TabView {
            NavigationStack(path: $pathStore.path) {
                TaskListView(isShowingICloudAlert: $isShowingAlert, selectedFilter: $selectedFilter)
            }
            .tabItem {
                Label("Tasks", systemImage: "list.bullet")
            }
            .environment(pathStore)

            CalendarView(selectedFilter: $selectedFilter)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .environment(pathStore)
        }
        .onAppear {
            selectedFilter = getSelectedFilter()
            if FileService.shared.isICloudAvailable() {
                logger.info("iCloud is available")
                // Create sample tasks if none exist
                createSampleTasksIfNeeded()
            } else {
                logger.warning("iCloud is unavailable")
                isShowingAlert = true
            }
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(
                title: Text("iCloud Required"),
                message: Text(
                    "In order to use Taskchamp, you require to have an iCloud account and iCloud Drive enabled"
                ),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
