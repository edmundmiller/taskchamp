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
        
        for i in 0..<tasks.len() {
            if let taskData = tasks.get(index: UInt(i)) {
                logger.debug("Processing task: \(taskData.get_uuid().toString())")
                // TODO: Convert TaskData to TCTask
                // For now, create a placeholder TCTask
                // taskObjects.append(TCTask(from: taskData))
            }
        }
        
        // TODO: use filters
        TasksHelper.sortTasksWithSortType(&taskObjects, sortType: sortType)
        return taskObjects
    }

    public func getTask(uuid _: String) throws -> TCTask {
        // TODO:
        throw TCError.genericError("Not implemented")
    }

    public func togglePendingTasksStatus(uuids _: Set<String>) throws {
        // TODO:
        throw TCError.genericError("Not implemented")
    }

    public func updatePendingTasks(_: Set<String>, withStatus _: TCTask.Status) throws {
        // TODO:
        throw TCError.genericError("Not implemented")
    }

    public func updateTask(_: TCTask) throws {
        // TODO:
        throw TCError.genericError("Not implemented")
    }

    public func createTask(task _: TCTask) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available - please refresh the task list")
        }
        
        let uuid = Taskchampion.uuid_v4()
        let taskData = try replica.create_task(uuid.to_string().toString())
        
        // TODO: Set task properties based on TCTask
        // For now, just create the task
        logger.info("Created task with UUID: \(taskData.get_uuid().toString())")
        
        // TODO: Implement proper task creation with properties
        throw TCError.genericError("Task creation not fully implemented yet")
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
        logger.info("Region: \(profileConfig.region), Bucket: \(profileConfig.bucket), Profile: \(profileConfig.profileName)")
        
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
    
    public func syncToAWSWithDefaultCredentials(region: String, bucket: String, encryptionSecret: String, avoidSnapshots: Bool = false) throws {
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
    
}
