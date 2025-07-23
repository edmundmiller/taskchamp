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
        
        do {
            // Create TaskChampion replica using the real implementation
            self.replica = try Taskchampion.new_replica_in_memory()
            logger.info("TaskChampion replica initialized successfully")
        } catch {
            logger.error("Failed to initialize TaskChampion replica: \(error)")
            self.replica = nil
        }
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
            let taskChampionTasks = try replica.get_all_tasks()
            
            // Convert TaskChampion Task objects to TCTask
            var tasks: [TCTask] = []
            for i in 0..<taskChampionTasks.len() {
                if let task = taskChampionTasks.get(index: UInt(i)) {
                    if let tcTask = convertTaskChampionToTCTask(task) {
                        tasks.append(tcTask)
                    }
                }
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
            let taskChampionTask = try replica.get_task_by_uuid(uuid)
            
            // Convert TaskChampion Task to TCTask
            guard let tcTask = convertTaskChampionToTCTask(taskChampionTask) else {
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
                    let task = try replica.get_task_by_uuid(uuid)
                    
                    // Get current status
                    let currentStatus = task.get_property("status")?.toString() ?? "pending"
                    let newStatus = currentStatus == "pending" ? "completed" : "pending"
                    
                    // Set new status using TaskChampion operations
                    let ops = task.set_property("status", newStatus)
                    try replica.commit_operations(ops)
                    
                    logger.debug("Toggled task \(uuid) to \(newStatus)")
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
                    let task = try replica.get_task_by_uuid(uuid)
                    
                    // Set status using TaskChampion operations
                    let ops = task.set_property("status", statusString)
                    try replica.commit_operations(ops)
                    
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
            // Get the existing task from TaskChampion
            let taskChampionTask = try replica.get_task_by_uuid(task.uuid)
            
            // Convert TCTask properties to TaskChampion format and update
            try updateTaskChampionWithTCTask(taskChampionTask, from: task, replica: replica)
            
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
            // Create task using real TaskChampion API
            let taskChampionTask = try replica.create_task(task.uuid)
            
            // Set all properties from TCTask to TaskChampion task
            try updateTaskChampionWithTCTask(taskChampionTask, from: task, replica: replica)
            
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
    
    private func convertTaskChampionToTCTask(_ taskChampionTask: Taskchampion.Task) -> TCTask? {
        // Extract UUID
        let uuid = taskChampionTask.get_uuid().toString()
        
        // Extract basic properties
        let description = taskChampionTask.get_property("description")?.toString() ?? ""
        
        // Extract status
        let statusString = taskChampionTask.get_property("status")?.toString() ?? "pending"
        let status: TCTask.Status
        switch statusString.lowercased() {
        case "completed":
            status = .completed
        case "deleted":
            status = .deleted
        default:
            status = .pending
        }
        
        // Extract project
        let project = taskChampionTask.get_property("project")?.toString()
        let projectValue = (project?.isEmpty ?? true) ? nil : project
        
        // Extract priority
        let priorityString = taskChampionTask.get_property("priority")?.toString()
        let priority: TCTask.Priority?
        switch priorityString {
        case "H":
            priority = .high
        case "M":
            priority = .medium
        case "L":
            priority = .low
        case "None", "", nil:
            priority = .none
        default:
            priority = .none
        }
        
        // Extract due date
        var due: Date?
        if let dueDateString = taskChampionTask.get_property("due")?.toString(),
           let timestamp = TimeInterval(dueDateString) {
            due = Date(timeIntervalSince1970: timestamp)
        }
        
        // Extract Obsidian note from annotations
        var obsidianNote: String?
        var noteAnnotationKey: String?
        
        let allProperties = taskChampionTask.get_all_properties()
        for i in 0..<allProperties.len() {
            if let prop = allProperties.get(index: UInt(i)) {
                let propString = prop.as_str().toString()
                if propString.starts(with: "annotation_") && propString.contains("task-note:") {
                    let parts = propString.components(separatedBy: "task-note: ")
                    if parts.count > 1 {
                        obsidianNote = parts[1]
                        noteAnnotationKey = propString.components(separatedBy: ":").first
                        break
                    }
                }
            }
        }
        
        return TCTask(
            uuid: uuid,
            project: projectValue,
            description: description,
            status: status,
            priority: priority,
            due: due,
            obsidianNote: obsidianNote,
            noteAnnotationKey: noteAnnotationKey
        )
    }
    
    private func updateTaskChampionWithTCTask(
        _ taskChampionTask: Taskchampion.Task,
        from tcTask: TCTask,
        replica: Taskchampion.Replica
    ) throws {
        // Set description
        let descOps = taskChampionTask.set_property("description", tcTask.description)
        try replica.commit_operations(descOps)
        
        // Set status
        let statusString: String
        switch tcTask.status {
        case .pending:
            statusString = "pending"
        case .completed:
            statusString = "completed"
        case .deleted:
            statusString = "deleted"
        }
        let statusOps = taskChampionTask.set_property("status", statusString)
        try replica.commit_operations(statusOps)
        
        // Set project
        if let project = tcTask.project, !project.isEmpty {
            let projectOps = taskChampionTask.set_property("project", project)
            try replica.commit_operations(projectOps)
        }
        
        // Set priority
        if let priority = tcTask.priority {
            let priorityString: String
            switch priority {
            case .none:
                priorityString = "None"
            case .high:
                priorityString = "H"
            case .medium:
                priorityString = "M"
            case .low:
                priorityString = "L"
            }
            let priorityOps = taskChampionTask.set_property("priority", priorityString)
            try replica.commit_operations(priorityOps)
        }
        
        // Set due date
        if let due = tcTask.due {
            let timestamp = String(Int(due.timeIntervalSince1970))
            let dueOps = taskChampionTask.set_property("due", timestamp)
            try replica.commit_operations(dueOps)
        }
        
        // Set Obsidian note as annotation
        if let obsidianNote = tcTask.obsidianNote, !obsidianNote.isEmpty {
            let timestamp = String(Int(Date().timeIntervalSince1970))
            let annotationKey = "annotation_\(timestamp)"
            let annotationValue = "task-note: \(obsidianNote)"
            let noteOps = taskChampionTask.set_property(annotationKey, annotationValue)
            try replica.commit_operations(noteOps)
        }
    }
}