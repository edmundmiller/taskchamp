import Foundation
import os.log
import Taskchampion

public class TaskchampionService {
    public static let shared = TaskchampionService()
    private var replica: Replica?
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "TaskchampionService")
    

    public func setDbUrl(_ dbUrl: String) {
        do {
            if dbUrl.isEmpty || dbUrl == "test-db-path" {
                replica = try Taskchampion.new_replica_in_memory()
            } else {
                replica = try Taskchampion.new_replica_on_disk(dbUrl, true)
            }
        } catch {
            logger.error("Failed to create replica: \(error)")
            replica = nil
        }
    }

    public func getTasks(
        sortType: TasksHelper.TCSortType = .defaultSort,
        filter _: TCFilter = TCFilter.defaultFilter
    ) throws -> [TCTask] {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        var taskObjects: [TCTask] = []
        let tasks = try replica.get_all_tasks()

        for i in 0 ..< tasks.len() {
            if let taskData = tasks.get(index: UInt(i)) {
                logger.debug("Processing task: \(taskData.get_uuid().as_str().toString())")
                if let tcTask = convertTaskDataToTCTask(taskData) {
                    taskObjects.append(tcTask)
                }
            }
        }

        // TODO: use filters
        TasksHelper.sortTasksWithSortType(&taskObjects, sortType: sortType)
        return taskObjects
    }

    public func getTask(uuid: String) throws -> TCTask {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        do {
            let taskData = try replica.get_task_by_uuid(uuid)
            guard let tcTask = convertTaskDataToTCTask(taskData) else {
                throw TCError.genericError("Failed to convert task data for UUID: \(uuid)")
            }
            return tcTask
        } catch {
            logger.error("Failed to get task \(uuid): \(error)")
            throw TCError.genericError("Failed to get task: \(error.localizedDescription)")
        }
    }

    public func togglePendingTasksStatus(uuids: Set<String>) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        do {

            for uuid in uuids {
                let taskData = try replica.get_task_by_uuid(uuid)
                let currentStatus = taskData.get_property("status")?.as_str().toString() ?? "pending"

                let newStatus: String
                switch currentStatus {
                case "pending":
                    newStatus = "completed"
                case "completed":
                    newStatus = "pending"
                default:
                    continue // Skip tasks with other statuses
                }

                let statusOps = taskData.set_property("status", newStatus)
                try replica.commit_operations(statusOps)

                logger.debug("Toggling task \(uuid) from \(currentStatus) to \(newStatus)")
            }

            logger.info("Successfully toggled status for \(uuids.count) tasks")

        } catch {
            logger.error("Failed to toggle task statuses: \(error)")
            throw TCError.genericError("Failed to toggle task statuses: \(error.localizedDescription)")
        }
    }

    public func updatePendingTasks(_ uuids: Set<String>, withStatus status: TCTask.Status) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        do {

            for uuid in uuids {
                let taskData = try replica.get_task_by_uuid(uuid)
                let currentStatus = taskData.get_property("status")?.as_str().toString() ?? "pending"

                // Only update if currently pending
                guard currentStatus == "pending" else {
                    logger.debug("Skipping task \(uuid) - not pending (status: \(currentStatus))")
                    continue
                }

                let statusOps = taskData.set_property("status", status.rawValue)
                try replica.commit_operations(statusOps)

                logger.debug("Updating pending task \(uuid) to \(status.rawValue)")
            }

            logger.info("Successfully updated \(uuids.count) pending tasks to \(status.rawValue)")

        } catch {
            logger.error("Failed to update pending tasks: \(error)")
            throw TCError.genericError("Failed to update pending tasks: \(error.localizedDescription)")
        }
    }

    public func updateTask(_ task: TCTask) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        do {
            let taskData = try replica.get_task_by_uuid(task.uuid)

            // Update description
            let descOps = taskData.set_property("description", task.description)
            try replica.commit_operations(descOps)

            // Update status
            let statusOps = taskData.set_property("status", task.status.rawValue)
            try replica.commit_operations(statusOps)

            // Update project (remove if nil)
            if let project = task.project {
                let projOps = taskData.set_property("project", project)
                try replica.commit_operations(projOps)
            } else {
                let projOps = taskData.remove_property("project")
                try replica.commit_operations(projOps)
            }

            // Update priority (remove if nil or none)
            if let priority = task.priority, priority != .none {
                let prioOps = taskData.set_property("priority", priority.rawValue)
                try replica.commit_operations(prioOps)
            } else {
                let prioOps = taskData.remove_property("priority")
                try replica.commit_operations(prioOps)
            }

            // Update due date (remove if nil)
            if let due = task.due {
                let timestamp = String(Int(due.timeIntervalSince1970))
                let dueOps = taskData.set_property("due", timestamp)
                try replica.commit_operations(dueOps)
            } else {
                let dueOps = taskData.remove_property("due")
                try replica.commit_operations(dueOps)
            }

            // Update Obsidian note annotation
            if let obsidianNote = task.obsidianNote {
                // Remove old annotation if exists
                if let oldKey = task.noteAnnotationKey {
                    let removeOps = taskData.remove_property(oldKey)
                    try replica.commit_operations(removeOps)
                }

                // Add new annotation
                let timestamp = String(Int(Date().timeIntervalSince1970))
                let annotationKey = "annotation_\(timestamp)"
                let annotationValue = "task-note: \(obsidianNote)"
                let noteOps = taskData.set_property(annotationKey, annotationValue)
                try replica.commit_operations(noteOps)
            } else if let oldKey = task.noteAnnotationKey {
                // Remove existing annotation
                let removeOps = taskData.remove_property(oldKey)
                try replica.commit_operations(removeOps)
            }

            // Commit all operations
            logger.info("Successfully updated task: \(task.uuid)")

        } catch {
            logger.error("Failed to update task \(task.uuid): \(error)")
            throw TCError.genericError("Failed to update task: \(error.localizedDescription)")
        }
    }

    public func createTask(task: TCTask) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        do {
            // Create task with provided UUID or generate new one
            let uuidString = task.uuid.isEmpty ? Taskchampion.uuid_v4().to_string().as_str().toString() : task.uuid
            let taskData = try replica.create_task(uuidString)


            // Set required description
            let descOps = taskData.set_property("description", task.description)
            try replica.commit_operations(descOps)

            // Set status
            let statusOps = taskData.set_property("status", task.status.rawValue)
            try replica.commit_operations(statusOps)

            // Set optional fields
            if let project = task.project {
                let projOps = taskData.set_property("project", project)
                try replica.commit_operations(projOps)
            }

            if let priority = task.priority, priority != .none {
                let prioOps = taskData.set_property("priority", priority.rawValue)
                try replica.commit_operations(prioOps)
            }

            if let due = task.due {
                let timestamp = String(Int(due.timeIntervalSince1970))
                let dueOps = taskData.set_property("due", timestamp)
                try replica.commit_operations(dueOps)
            }

            // Set Obsidian note annotation if provided
            if let obsidianNote = task.obsidianNote {
                let timestamp = String(Int(Date().timeIntervalSince1970))
                let annotationKey = "annotation_\(timestamp)"
                let annotationValue = "task-note: \(obsidianNote)"
                let noteOps = taskData.set_property(annotationKey, annotationValue)
                try replica.commit_operations(noteOps)
            }

            // Commit all operations
            logger.info("Successfully created task: \(uuidString)")

        } catch {
            logger.error("Failed to create task: \(error)")
            throw TCError.genericError("Failed to create task: \(error.localizedDescription)")
        }
    }

    // MARK: - AWS Sync Methods

    public func syncToAWS(config: AWSConfig) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        logger.info("Starting AWS sync with access key method")
        logger.info("Region: \(config.region), Bucket: \(config.bucket)")

        do {
            try replica.sync_to_aws_with_access_key(
                config.region,
                config.bucket,
                config.accessKeyId,
                config.secretAccessKey,
                config.encryptionSecret,
                config.avoidSnapshots
            )
            logger.info("AWS sync with access key completed successfully")
        } catch {
            logger.error("AWS sync with access key failed: \(error)")
            throw TCError.genericError("AWS sync failed: \(error.localizedDescription)")
        }
    }

    public func syncToAWS(profileConfig: AWSProfileConfig) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        logger.info("Starting AWS sync with profile method")
        logger
            .info(
                "Region: \(profileConfig.region), Bucket: \(profileConfig.bucket), Profile: \(profileConfig.profileName)"
            )

        do {
            try replica.sync_to_aws_with_profile(
                profileConfig.region,
                profileConfig.bucket,
                profileConfig.profileName,
                profileConfig.encryptionSecret,
                profileConfig.avoidSnapshots
            )
            logger.info("AWS sync with profile completed successfully")
        } catch {
            logger.error("AWS sync with profile failed: \(error)")
            throw TCError.genericError("AWS sync failed: \(error.localizedDescription)")
        }
    }

    public func syncToAWSWithDefaultCredentials(
        region: String,
        bucket: String,
        encryptionSecret: String,
        avoidSnapshots: Bool = false
    ) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        logger.info("Starting AWS sync with default credentials method")
        logger.info("Region: \(region), Bucket: \(bucket)")

        do {
            try replica.sync_to_aws_with_default_creds(
                region,
                bucket,
                encryptionSecret,
                avoidSnapshots
            )
            logger.info("AWS sync with default credentials completed successfully")
        } catch {
            logger.error("AWS sync with default credentials failed: \(error)")
            throw TCError.genericError("AWS sync failed: \(error.localizedDescription)")
        }
    }

    public func syncToAWSFromUserDefaults() throws {
        let userDefaults = UserDefaults.standard

        guard userDefaults.isAWSConfigured else {
            throw TCError.genericError("AWS sync is not configured")
        }

        guard userDefaults.validateAWSConfig() else {
            throw TCError.genericError("AWS configuration is invalid")
        }

        switch userDefaults.awsAuthMethod {
        case .accessKey:
            guard let config = userDefaults.getAWSConfig() else {
                throw TCError.genericError("Failed to get AWS access key configuration")
            }
            try syncToAWS(config: config)

        case .profile:
            guard let config = userDefaults.getAWSProfileConfig() else {
                throw TCError.genericError("Failed to get AWS profile configuration")
            }
            try syncToAWS(profileConfig: config)

        case .defaultCredentials:
            try syncToAWSWithDefaultCredentials(
                region: userDefaults.awsRegion,
                bucket: userDefaults.awsBucket,
                encryptionSecret: userDefaults.awsEncryptionSecret,
                avoidSnapshots: userDefaults.awsAvoidSnapshots
            )
        }
    }

    // MARK: - Sync Status Methods

    public func getLocalOperationsCount() throws -> UInt32 {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }

        do {
            let count = try replica.num_local_operations()
            logger.info("Local operations count: \(count)")
            return count
        } catch {
            logger.error("Failed to get local operations count: \(error)")
            throw TCError.genericError("Failed to get local operations count: \(error.localizedDescription)")
        }
    }

    public func needsSync() throws -> Bool {
        do {
            let count = try getLocalOperationsCount()
            let needsSync = count > 0
            logger.info("Sync needed: \(needsSync) (\(count) operations)")
            return needsSync
        } catch {
            logger.error("Failed to check if sync is needed: \(error.localizedDescription)")
            throw TCError.genericError("Failed to check sync status: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    private func convertTaskDataToTCTask(_ taskData: TaskDataRef) -> TCTask? {
        let uuid = taskData.get_uuid().as_str().toString()

        // Get required fields
        guard let description = taskData.get_property("description")?.as_str().toString() else {
            logger.warning("Task \(uuid) missing description")
            return nil
        }

        // Get status (default to pending if not set)
        let statusString = taskData.get_property("status")?.as_str().toString() ?? "pending"
        let status = TCTask.Status(rawValue: statusString) ?? .pending

        // Get optional fields
        let project = taskData.get_property("project")?.as_str().toString()

        let priority: TCTask.Priority?
        if let priorityString = taskData.get_property("priority")?.as_str().toString() {
            priority = TCTask.Priority(rawValue: priorityString) ?? .none
        } else {
            priority = nil
        }

        // Parse due date (TaskWarrior stores as timestamp)
        let due: Date?
        if let dueString = taskData.get_property("due")?.as_str().toString(),
           let timeInterval = TimeInterval(dueString)
        {
            due = Date(timeIntervalSince1970: timeInterval)
        } else {
            due = nil
        }

        // Extract Obsidian note from annotations
        var obsidianNote: String?
        var noteAnnotationKey: String?
        let allProperties = taskData.get_all_properties()

        for i in 0 ..< allProperties.len() {
            if let property = allProperties.get(index: UInt(i)) {
                let propertyName = property.as_str().toString()
                if propertyName.starts(with: "annotation_"),
                   let value = taskData.get_property(propertyName)?.as_str().toString(),
                   value.starts(with: "task-note:")
                {
                    noteAnnotationKey = propertyName
                    obsidianNote = value.replacingOccurrences(of: "task-note: ", with: "")
                    break
                }
            }
        }

        return TCTask(
            uuid: uuid,
            project: project,
            description: description,
            status: status,
            priority: priority,
            due: due,
            obsidianNote: obsidianNote,
            noteAnnotationKey: noteAnnotationKey
        )
    }

}
