import Foundation
import os.log
import Taskchampion

// swiftlint:disable type_body_length file_length
public class TaskchampionService {
    public static let shared: TaskchampionService = {
        print("🔧 DEBUG: Creating TaskchampionService.shared singleton")
        let instance = TaskchampionService()
        print("✅ DEBUG: TaskchampionService.shared singleton created successfully")
        return instance
    }()
    
    private var replica: Taskchampion.Replica?
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "TaskchampionService")
    
    private init() {
        print("🔧 DEBUG: TaskchampionService init() called")
        logger.info("TaskchampionService initializing...")
        print("✅ DEBUG: TaskchampionService init() completed")
    }

    public func setDbUrl(_ dbUrl: String) {
        logger.info("🚀 Initializing TaskChampion replica with database: \(dbUrl)")
        
        // Validate and prepare the database path
        let databaseURL = URL(fileURLWithPath: dbUrl)
        let parentDirectory = databaseURL.deletingLastPathComponent()
        
        // Ensure parent directory exists
        do {
            if !FileManager.default.fileExists(atPath: parentDirectory.path) {
                logger.info("📁 Creating parent directory: \(parentDirectory.path)")
                try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Log database file status
            if FileManager.default.fileExists(atPath: dbUrl) {
                logger.info("📄 Using existing database file: \(dbUrl)")
            } else {
                logger.info("📄 TaskChampion will create new database file: \(dbUrl)")
            }
            
            // Initialize TaskChampion replica with proper error handling
            logger.debug("🔧 Calling new_replica_on_disk with path: \(dbUrl)")
            self.replica = new_replica_on_disk(dbUrl)
            logger.info("✅ TaskChampion replica initialized successfully")
            
            // Immediately test the replica by checking task count
            do {
                let testTasks = try self.replica?.getAllTasks() ?? []
                logger.info("🔍 Initial task count in replica: \(testTasks.count)")
            } catch {
                logger.error("❌ Failed to get initial task count: \(error)")
            }
            
        } catch {
            logger.error("❌ Failed to initialize TaskChampion replica: \(error)")
            logger.error("📂 Database path: \(dbUrl)")
            logger.error("📂 Parent directory: \(parentDirectory.path)")
            
            // Don't throw here - let the app continue but with no replica
            // The individual method calls will handle the nil replica case
            self.replica = nil
        }
    }

    public func getTasks(
        sortType: TasksHelper.TCSortType = .defaultSort,
        filter: TCFilter = TCFilter.defaultFilter
    ) throws -> [TCTask] {
        guard let replica = self.replica else {
            logger.error("❌ TaskChampion replica not initialized")
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("🔍 Fetching tasks from TaskChampion replica...")
        
        do {
            // Get all tasks from TaskChampion using real API
            logger.debug("📡 Calling replica.get_all_tasks()...")
            let taskDataList = replica.get_all_tasks()
            logger.info("📋 Raw TaskChampion returned \(taskDataList.count) tasks")
            
            // Log each task for debugging
            for (index, taskData) in taskDataList.enumerated() {
                logger.debug("📝 Task[\(index)]: uuid=\(taskData.task_data_get_uuid()), desc='\(taskData.task_data_get_description())', status=\(taskData.task_data_get_status()), project=\(taskData.task_data_get_project() ?? "nil"), priority=\(taskData.task_data_get_priority() ?? "nil")")
            }
            
            // Convert TaskChampion TaskData to TCTask
            let tasks = taskDataList.compactMap { taskData -> TCTask? in
                let convertedTask = convertTaskDataToTCTask(taskData)
                if convertedTask == nil {
                    logger.error("❌ Failed to convert TaskData to TCTask for uuid: \(taskData.uuid)")
                }
                return convertedTask
            }
            logger.info("🔄 Converted \(tasks.count)/\(taskDataList.count) tasks successfully")
            
            // Apply filtering
            var filteredTasks = tasks
            let originalCount = filteredTasks.count
            
            if filter.didSetStatus && filter.status != .deleted {
                filteredTasks = filteredTasks.filter { $0.status == filter.status }
                logger.debug("🔍 Status filter (\(filter.status.rawValue)): \(originalCount) -> \(filteredTasks.count) tasks")
            }
            if filter.didSetProject && !filter.project.isEmpty {
                let beforeProject = filteredTasks.count
                filteredTasks = filteredTasks.filter { $0.project == filter.project }
                logger.debug("🔍 Project filter ('\(filter.project)'): \(beforeProject) -> \(filteredTasks.count) tasks")
            }
            if filter.didSetPrio && filter.priority != .none {
                let beforePrio = filteredTasks.count
                filteredTasks = filteredTasks.filter { $0.priority == filter.priority }
                logger.debug("🔍 Priority filter (\(filter.priority.rawValue)): \(beforePrio) -> \(filteredTasks.count) tasks")
            }
            
            // Apply sorting
            TasksHelper.sortTasksWithSortType(&filteredTasks, sortType: sortType)
            logger.debug("🔄 Applied sorting: \(sortType.rawValue)")
            
            logger.info("✅ Final result: \(filteredTasks.count) tasks after filtering and sorting")
            return filteredTasks
        } catch {
            logger.error("❌ Failed to fetch tasks from TaskChampion: \(error)")
            throw TCError.genericError("Failed to fetch tasks: \(error.localizedDescription)")
        }
    }

    public func getTask(uuid: String) throws -> TCTask {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("Getting task from TaskChampion replica: \(uuid)")
        
        do {
            // Get task from TaskChampion using real API
            guard let taskData = replica.get_task(uuid) else {
                throw TCError.genericError("Task not found: \(uuid)")
            }
            
            // Convert TaskChampion TaskData to TCTask
            guard let tcTask = convertTaskDataToTCTask(taskData) else {
                throw TCError.genericError("Failed to convert task data for: \(uuid)")
            }
            
            return tcTask
        } catch {
            logger.error("Failed to get task \(uuid): \(error)")
            throw TCError.genericError("Task not found: \(uuid)")
        }
    }

    public func togglePendingTasksStatus(uuids: Set<String>) throws {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("Toggling status for \(uuids.count) tasks")
        
        do {
            // Toggle each task between pending and completed
            for uuid in uuids {
                do {
                    if let taskData = replica.get_task(uuid) {
                        let currentStatus = taskData.task_data_get_status()
                        let newStatus = currentStatus == "pending" ? "completed" : "pending"
                        
                        // Create new TaskData with updated status
                        let updatedTaskData = new_task_data(uuid, taskData.task_data_get_description())
                        updatedTaskData.task_data_set_status(newStatus)
                        if let project = taskData.task_data_get_project() {
                            updatedTaskData.task_data_set_project(project)
                        }
                        if let priority = taskData.task_data_get_priority() {
                            updatedTaskData.task_data_set_priority(priority)
                        }
                        if let due = taskData.task_data_get_due() {
                            updatedTaskData.task_data_set_due(due)
                        }
                        
                        try replica.update_task(uuid, updatedTaskData)
                        logger.debug("Toggled task \(uuid) to \(newStatus)")
                    }
                } catch {
                    logger.error("Failed to toggle task \(uuid): \(error)")
                    throw error
                }
            }
            
            logger.info("Successfully toggled \(uuids.count) tasks")
        } catch {
            logger.error("Failed to toggle tasks: \(error)")
            throw TCError.genericError("Failed to toggle tasks: \(error.localizedDescription)")
        }
    }

    public func updatePendingTasks(_ uuids: Set<String>, withStatus status: TCTask.Status) throws {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("Updating \(uuids.count) tasks to status: \(status.rawValue)")
        
        let statusString: String
        switch status {
        case .pending:
            statusString = "pending"
        case .completed:
            statusString = "completed"
        case .deleted:
            statusString = "deleted"
        }
        
        do {
            // Update each task with the new status using real TaskChampion API
            for uuid in uuids {
                do {
                    if let taskData = replica.get_task(uuid) {
                        // Create new TaskData with updated status
                        let updatedTaskData = new_task_data(uuid, taskData.task_data_get_description())
                        updatedTaskData.task_data_set_status(statusString)
                        if let project = taskData.task_data_get_project() {
                            updatedTaskData.task_data_set_project(project)
                        }
                        if let priority = taskData.task_data_get_priority() {
                            updatedTaskData.task_data_set_priority(priority)
                        }
                        if let due = taskData.task_data_get_due() {
                            updatedTaskData.task_data_set_due(due)
                        }
                        
                        try replica.update_task(uuid, updatedTaskData)
                        logger.debug("Updated task \(uuid) to \(statusString)")
                    }
                } catch {
                    logger.error("Failed to update task \(uuid): \(error)")
                    throw error
                }
            }
            
            logger.info("Successfully updated \(uuids.count) tasks to \(statusString)")
        } catch {
            logger.error("Failed to update tasks: \(error)")
            throw TCError.genericError("Failed to update tasks: \(error.localizedDescription)")
        }
    }

    private func updateTaskSync(_ task: TCTask) throws {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("Updating task in TaskChampion: \(task.uuid)")
        
        do {
            let statusString: String
            switch task.status {
            case .pending:
                statusString = "pending"
            case .completed:
                statusString = "completed"
            case .deleted:
                statusString = "deleted"
            }
            
            let priorityString: String?
            if let priority = task.priority {
                switch priority {
                case .high:
                    priorityString = "high"
                case .medium:
                    priorityString = "medium"
                case .low:
                    priorityString = "low"
                case .none:
                    priorityString = nil
                }
            } else {
                priorityString = nil
            }
            
            let dueString: String?
            if let due = task.due {
                dueString = String(Int(due.timeIntervalSince1970))
            } else {
                dueString = nil
            }
            
            // Use the new TaskChampion bridge API
            logger.debug("🔧 Updating task using new bridge API...")
            
            // Create TaskData object with updated values
            let taskData = new_task_data(task.uuid, task.description)
            taskData.task_data_set_status(statusString)
            
            if let project = task.project, !project.isEmpty {
                taskData.task_data_set_project(project)
            }
            
            if let priorityString = priorityString, !priorityString.isEmpty {
                taskData.task_data_set_priority(priorityString)
            }
            
            if let dueString = dueString, !dueString.isEmpty {
                taskData.task_data_set_due(dueString)
            }
            
            // Update task using bridge API
            try replica.update_task(task.uuid, taskData)
            logger.debug("📝 Task updated using bridge API")
            
            logger.info("Successfully updated task: \(task.uuid)")
        } catch {
            logger.error("Failed to update task \(task.uuid): \(error)")
            throw TCError.genericError("Failed to update task: \(error.localizedDescription)")
        }
    }

    private func createTaskSync(task: TCTask) throws {
        guard let replica = self.replica else {
            logger.error("❌ TaskChampion replica not initialized for createTask")
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("➕ Creating task in TaskChampion: '\(task.description)' (uuid: \(task.uuid))")
        
        do {
            logger.info("🔎 About to create task - replica is initialized")
            logger.info("🔎 Replica memory address: \(String(describing: replica))")
            
            let priorityString: String?
            if let priority = task.priority {
                switch priority {
                case .high:
                    priorityString = "high"
                case .medium:
                    priorityString = "medium"
                case .low:
                    priorityString = "low"
                case .none:
                    priorityString = nil
                }
            } else {
                priorityString = nil
            }
            
            let dueString: String?
            if let due = task.due {
                dueString = String(Int(due.timeIntervalSince1970))
            } else {
                dueString = nil
            }
            
            logger.debug("📝 Task properties: project=\(task.project ?? "nil"), priority=\(priorityString ?? "nil"), due=\(dueString ?? "nil"), obsidianNote=\(task.obsidianNote ?? "nil")")
            
            // Use the new TaskChampion bridge API
            logger.debug("🔧 Creating task using new bridge API...")
            logger.debug("🔍 UUID format check: '\(task.uuid)' (length: \(task.uuid.count))")
            
            // Create TaskData object
            let taskData = new_task_data(task.uuid, task.description)
            
            // Set optional properties
            if let project = task.project, !project.isEmpty {
                taskData.task_data_set_project(project)
            }
            
            if let priorityString = priorityString, !priorityString.isEmpty {
                taskData.task_data_set_priority(priorityString)
            }
            
            if let dueString = dueString, !dueString.isEmpty {
                taskData.task_data_set_due(dueString)
            }
            
            // Create task using bridge API
            do {
                logger.info("🔎 About to call replica.create_task with TaskData")
                let createdUuid = try replica.create_task(taskData)
                logger.debug("✅ Task created with UUID: \(createdUuid)")
            } catch {
                logger.error("❌ Failed to create task: \(error)")
                throw error
            }
            
            logger.info("✅ Successfully created task: \(task.uuid)")
            
            // Verify the task was actually created by trying to retrieve it
            logger.debug("🔍 Verifying task creation by retrieving it...")
            do {
                let retrievedTask = try getTask(uuid: task.uuid)
                logger.info("✅ Verification successful: Retrieved task '\(retrievedTask.description)'")
            } catch {
                logger.error("❌ Verification failed: Could not retrieve created task: \(error)")
                logger.error("💡 This suggests the bridge set_property() calls are not persisting to database")
            }
        } catch {
            logger.error("❌ Failed to create task \(task.uuid): \(error)")
            throw TCError.genericError("Failed to create task: \(error.localizedDescription)")
        }
    }

    // MARK: - AWS Sync Methods (Real TaskChampion Implementation)

    public func syncToAWS(config: AWSConfig) async throws {
        logger.info("Performing real TaskChampion S3 sync with PBKDF2+ChaCha20 encryption")
        
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        do {
            // Use real TaskChampion encrypted sync with access key authentication
            try replica.sync_to_aws_with_access_key(
                config.accessKeyId,
                config.secretAccessKey,
                config.region,
                config.bucket,
                config.encryptionSecret
            )
            
            logger.info("Real TaskChampion S3 sync completed successfully")
        } catch {
            logger.error("Real TaskChampion S3 sync failed: \(error)")
            throw TCError.genericError("TaskChampion S3 sync failed: \(error.localizedDescription)")
        }
    }



    public func syncToAWSFromUserDefaults() async throws {
        logger.info("Starting real TaskChampion S3 sync from UserDefaults")
        
        guard UserDefaults.standard.isAWSConfigured else {
            throw TCError.genericError("AWS settings not configured")
        }
        
        guard let config = UserDefaults.standard.getAWSConfig() else {
            throw TCError.genericError("Failed to load AWS access key configuration")
        }
        
        try await syncToAWS(config: config)
    }
    
    // MARK: - Sync Status Methods

    public func getLocalOperationsCount() throws -> UInt64 {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        // Use real TaskChampion API to get local operations count
        return replica.num_local_operations()
    }

    public func needsSync() throws -> Bool {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("Checking if sync needed using real TaskChampion API")
        
        // Check if AWS is configured - no point syncing if not set up
        guard UserDefaults.standard.isAWSConfigured else {
            logger.debug("AWS not configured, no sync needed")
            return false
        }
        
        // Use real TaskChampion API to check if we have local operations that need syncing
        let localOpsCount = replica.num_local_operations()
        let needsSync = localOpsCount > 0
        
        logger.debug("Local operations count: \(localOpsCount), needs sync: \(needsSync)")
        return needsSync
    }
    
    // MARK: - Async API for DBService compatibility
    
    public func getTasks() async throws -> [TCTask] {
        logger.info("🚀 TaskchampionService.getTasks(async) called")
        // Convert async to sync for now
        return try getTasks(sortType: .defaultSort, filter: TCFilter.defaultFilter)
    }
    
    public func getTasks(filters: [String]) async throws -> [TCTask] {
        // Convert async to sync for now
        return try await getTasks()
    }
    
    public func getTask(uuid: String) async throws -> TCTask {
        // Call the sync version directly using the same name resolution trick
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        // Get task from TaskChampion using real API
        guard let taskData = replica.get_task(uuid) else {
            throw TCError.genericError("Task not found: \(uuid)")
        }
        
        // Convert TaskChampion TaskData to TCTask
        guard let tcTask = convertTaskDataToTCTask(taskData) else {
            throw TCError.genericError("Failed to convert task data for: \(uuid)")
        }
        
        return tcTask
    }
    
    
    public func updateTask(_ task: TCTask) async throws {
        // Call the sync version which now uses proper low-level bridge API
        try updateTaskSync(task)
    }
    
    public func updateTask(_ task: TCTask) throws {
        try updateTaskSync(task)
    }
    
    public func createTask(task: TCTask) async throws {
        logger.info("🚀 TaskchampionService.createTask(async) called")
        // Call the sync version which now uses proper low-level bridge API
        try createTaskSync(task: task)
    }
    
    public func createTask(task: TCTask) throws {
        logger.info("🚀 TaskchampionService.createTask(sync) called")
        try createTaskSync(task: task)
    }
    
    // MARK: - Task Conversion Helpers
    
    private func convertTaskDataToTCTask(_ taskData: TaskData) -> TCTask? {
        // Convert TaskChampion TaskData to TCTask with full property support
        let status: TCTask.Status
        switch taskData.task_data_get_status().lowercased() {
        case "completed":
            status = .completed
        case "deleted":
            status = .deleted
        default:
            status = .pending
        }
        
        // Convert priority string to TCTask.Priority
        let priority: TCTask.Priority?
        if let priorityString = taskData.task_data_get_priority() {
            switch priorityString.lowercased() {
            case "high":
                priority = .high
            case "medium":
                priority = .medium
            case "low":
                priority = .low
            default:
                priority = TCTask.Priority.none
            }
        } else {
            priority = TCTask.Priority.none
        }
        
        // Convert due date string to Date
        let due: Date?
        if let dueString = taskData.task_data_get_due(), let dueTimestamp = Double(dueString) {
            due = Date(timeIntervalSince1970: dueTimestamp)
        } else {
            due = nil
        }
        
        return TCTask(
            uuid: taskData.task_data_get_uuid(),
            project: taskData.task_data_get_project()?.isEmpty == true ? nil : taskData.task_data_get_project(),
            description: taskData.task_data_get_description(),
            status: status,
            priority: priority,
            due: due,
            obsidianNote: nil // TaskData doesn't include obsidianNote yet
        )
    }
    
}