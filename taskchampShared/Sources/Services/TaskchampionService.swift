import Foundation
import os.log
import Taskchampion

// swiftlint:disable type_body_length file_length
public class TaskchampionService {
    public static let shared = TaskchampionService()
    private var replica: Taskchampion.Replica?
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "TaskchampionService")

    public func setDbUrl(_ dbUrl: String) {
        logger.info("Initializing TaskChampion replica with database: \(dbUrl)")
        
        // Create TaskChampion replica using the real implementation
        self.replica = Taskchampion.new_replica_in_memory()
        logger.info("TaskChampion replica initialized successfully")
    }

    public func getTasks(
        sortType: TasksHelper.TCSortType = .defaultSort,
        filter: TCFilter = TCFilter.defaultFilter
    ) throws -> [TCTask] {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("Fetching tasks from TaskChampion replica")
        
        do {
            // Get all tasks from TaskChampion using real API
            let taskDataList = try replica.getAllTasks()
            
            // Convert TaskChampion TaskData to TCTask
            let tasks = taskDataList.compactMap { taskData -> TCTask? in
                return convertTaskDataToTCTask(taskData)
            }
            
            // Apply filtering
            var filteredTasks = tasks
            if filter.didSetStatus && filter.status != .deleted {
                filteredTasks = filteredTasks.filter { $0.status == filter.status }
            }
            if filter.didSetProject && !filter.project.isEmpty {
                filteredTasks = filteredTasks.filter { $0.project == filter.project }
            }
            if filter.didSetPrio && filter.priority != .none {
                filteredTasks = filteredTasks.filter { $0.priority == filter.priority }
            }
            
            // Apply sorting
            TasksHelper.sortTasksWithSortType(&filteredTasks, sortType: sortType)
            
            logger.info("Fetched \(filteredTasks.count) tasks from TaskChampion")
            return filteredTasks
        } catch {
            logger.error("Failed to fetch tasks from TaskChampion: \(error)")
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
            guard let taskData = try replica.getTask(uuid: uuid) else {
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
                    if let taskData = try replica.getTask(uuid: uuid) {
                        let newStatus = taskData.status == "pending" ? "completed" : "pending"
                        try replica.updateTask(uuid: uuid, description: nil, status: newStatus, project: nil, priority: nil, due: nil, obsidianNote: nil)
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
                    try replica.updateTask(uuid: uuid, description: nil, status: statusString, project: nil, priority: nil, due: nil, obsidianNote: nil)
                    logger.debug("Updated task \(uuid) to \(statusString)")
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

    public func updateTask(_ task: TCTask) throws {
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
            
            // Update task using TaskChampion with all properties
            try replica.updateTask(
                uuid: task.uuid,
                description: task.description,
                status: statusString,
                project: task.project,
                priority: priorityString,
                due: dueString,
                obsidianNote: task.obsidianNote
            )
            
            logger.info("Successfully updated task: \(task.uuid)")
        } catch {
            logger.error("Failed to update task \(task.uuid): \(error)")
            throw TCError.genericError("Failed to update task: \(error.localizedDescription)")
        }
    }

    public func createTask(task: TCTask) throws {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        logger.info("Creating task in TaskChampion: \(task.description)")
        
        do {
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
            
            // Create task using real TaskChampion API with all properties
            try replica.createTask(
                uuid: task.uuid,
                description: task.description,
                project: task.project,
                priority: priorityString,
                due: dueString,
                obsidianNote: task.obsidianNote
            )
            
            logger.info("Successfully created task: \(task.uuid)")
        } catch {
            logger.error("Failed to create task \(task.uuid): \(error)")
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
                region: config.region,
                bucket: config.bucket,
                accessKeyId: config.accessKeyId,
                secretAccessKey: config.secretAccessKey,
                encryptionSecret: config.encryptionSecret,
                avoidSnapshots: config.avoidSnapshots
            )
            
            logger.info("Real TaskChampion S3 sync completed successfully")
        } catch {
            logger.error("Real TaskChampion S3 sync failed: \(error)")
            throw TCError.genericError("TaskChampion S3 sync failed: \(error.localizedDescription)")
        }
    }

    public func syncToAWS(profileConfig: AWSProfileConfig) throws {
        logger.info("Performing real TaskChampion S3 sync with profile authentication")
        
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        do {
            // Use real TaskChampion encrypted sync with profile authentication
            try replica.sync_to_aws_with_profile(
                region: profileConfig.region,
                bucket: profileConfig.bucket,
                profileName: profileConfig.profileName,
                encryptionSecret: profileConfig.encryptionSecret,
                avoidSnapshots: profileConfig.avoidSnapshots
            )
            
            logger.info("Real TaskChampion S3 sync with profile completed successfully")
        } catch {
            logger.error("Real TaskChampion S3 sync with profile failed: \(error)")
            throw TCError.genericError("TaskChampion S3 sync with profile failed: \(error.localizedDescription)")
        }
    }

    public func syncToAWSWithDefaultCredentials(
        region: String,
        bucket: String,
        encryptionSecret: String,
        avoidSnapshots: Bool = false
    ) throws {
        logger.info("Performing real TaskChampion S3 sync with default credentials")
        
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        do {
            // Use real TaskChampion encrypted sync with default credentials
            try replica.sync_to_aws_with_default_creds(
                region: region,
                bucket: bucket,
                encryptionSecret: encryptionSecret,
                avoidSnapshots: avoidSnapshots
            )
            
            logger.info("Real TaskChampion S3 sync with default credentials completed successfully")
        } catch {
            logger.error("Real TaskChampion S3 sync with default credentials failed: \(error)")
            throw TCError.genericError("TaskChampion S3 sync with default credentials failed: \(error.localizedDescription)")
        }
    }

    public func syncToAWSFromUserDefaults() async throws {
        logger.info("Starting real TaskChampion S3 sync from UserDefaults")
        
        guard UserDefaults.standard.isAWSConfigured else {
            throw TCError.genericError("AWS settings not configured")
        }
        
        // Route to appropriate authentication method
        switch UserDefaults.standard.awsAuthMethod {
        case .accessKey:
            guard let config = UserDefaults.standard.getAWSConfig() else {
                throw TCError.genericError("Failed to load AWS access key configuration")
            }
            try await syncToAWS(config: config)
            
        case .profile:
            guard let config = UserDefaults.standard.getAWSProfileConfig() else {
                throw TCError.genericError("Failed to load AWS profile configuration")
            }
            try syncToAWS(profileConfig: config)
            
        case .defaultCredentials:
            try syncToAWSWithDefaultCredentials(
                region: UserDefaults.standard.awsRegion,
                bucket: UserDefaults.standard.awsBucket,
                encryptionSecret: UserDefaults.standard.awsEncryptionSecret,
                avoidSnapshots: UserDefaults.standard.awsAvoidSnapshots
            )
        }
    }
    
    // MARK: - Sync Status Methods

    public func getLocalOperationsCount() throws -> UInt32 {
        guard let replica = self.replica else {
            throw TCError.genericError("TaskChampion replica not initialized")
        }
        
        do {
            // Use real TaskChampion API to get local operations count
            return try replica.num_local_operations()
        } catch {
            logger.error("Failed to get local operations count: \(error)")
            throw TCError.genericError("Failed to get sync status: \(error.localizedDescription)")
        }
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
        
        do {
            // Use real TaskChampion API to check if we have local operations that need syncing
            let localOpsCount = try replica.num_local_operations()
            let needsSync = localOpsCount > 0
            
            logger.debug("Local operations count: \(localOpsCount), needs sync: \(needsSync)")
            return needsSync
        } catch {
            logger.error("Failed to check sync status: \(error)")
            // Default to false if we can't determine sync status
            return false
        }
    }
    
    // MARK: - Async API for DBService compatibility
    
    public func getTasks(filters: [String]) async throws -> [TCTask] {
        // Convert async to sync for now
        return try getTasks()
    }
    
    public func getTask(uuid: String) async throws -> TCTask {
        // Convert async to sync for now
        return try await Task.detached {
            try self.getTask(uuid: uuid)
        }.value
    }
    
    public func updateTask(_ task: TCTask) async throws {
        // Convert async to sync for now
        try await Task.detached {
            try self.updateTask(task)
        }.value
    }
    
    public func createTask(task: TCTask) async throws {
        // Convert async to sync for now
        try await Task.detached {
            try self.createTask(task: task)
        }.value
    }
    
    // MARK: - Task Conversion Helpers
    
    private func convertTaskDataToTCTask(_ taskData: Taskchampion.TaskData) -> TCTask? {
        // Convert TaskChampion TaskData to TCTask with full property support
        let status: TCTask.Status
        switch taskData.status.lowercased() {
        case "completed":
            status = .completed
        case "deleted":
            status = .deleted
        default:
            status = .pending
        }
        
        // Convert priority string to TCTask.Priority
        let priority: TCTask.Priority?
        if let priorityString = taskData.priority {
            switch priorityString.lowercased() {
            case "high":
                priority = .high
            case "medium":
                priority = .medium
            case "low":
                priority = .low
            default:
                priority = .none
            }
        } else {
            priority = .none
        }
        
        // Convert due date string to Date
        let due: Date?
        if let dueString = taskData.due, let dueTimestamp = Double(dueString) {
            due = Date(timeIntervalSince1970: dueTimestamp)
        } else {
            due = nil
        }
        
        return TCTask(
            uuid: taskData.uuid,
            project: taskData.project?.isEmpty == true ? nil : taskData.project,
            description: taskData.description,
            status: status,
            priority: priority,
            due: due,
            obsidianNote: taskData.obsidianNote?.isEmpty == true ? nil : taskData.obsidianNote
        )
    }
    
}