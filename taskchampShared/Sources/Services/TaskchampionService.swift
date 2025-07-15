import Foundation
import os.log
import Taskchampion

public class TaskchampionService {
    public static let shared = TaskchampionService()
    private var replica: Replica?
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "TaskchampionService")

    public func setDbUrl(_: String) {
        // TODO: use replica from disk
        replica = Taskchampion.new_replica_in_memory()
    }

    public func getTasks(
        sortType: TasksHelper.TCSortType = .defaultSort,
        filter _: TCFilter = TCFilter.defaultFilter
    ) throws -> [TCTask] {
        var taskObjects: [TCTask] = []
        let tasks = replica?.all_task_data()
        guard let tasks else {
            throw TCError.genericError("Query was null")
        }
        for task in tasks {
            logger.debug("Processing task: \(String(describing: task))")
            // TODO: TCTask init from taskchampion task
            // taskObjects.append(task)
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
        // TODO:
        let uuid = Taskchampion.uuid_v4()
        var ops = Taskchampion.new_operations()
        ops = Taskchampion.create_task(uuid, ops)
        throw TCError.genericError("Not implemented")
    }
    
    // MARK: - AWS Sync Methods
    
    public func syncToAWS(config: AWSConfig) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available")
        }
        
        do {
            try replica.sync_to_aws_with_access_key(
                config.region,
                bucket: config.bucket,
                access_key_id: config.accessKeyId,
                secret_access_key: config.secretAccessKey,
                encryption_secret: config.encryptionSecret,
                avoid_snapshots: config.avoidSnapshots
            )
            logger.info("Successfully synced to AWS S3 bucket: \(config.bucket)")
        } catch {
            logger.error("Failed to sync to AWS: \(error.localizedDescription)")
            throw TCError.genericError("AWS sync failed: \(error.localizedDescription)")
        }
    }
    
    public func syncToAWS(profileConfig: AWSProfileConfig) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available")
        }
        
        do {
            try replica.sync_to_aws_with_profile(
                profileConfig.region,
                bucket: profileConfig.bucket,
                profile_name: profileConfig.profileName,
                encryption_secret: profileConfig.encryptionSecret,
                avoid_snapshots: profileConfig.avoidSnapshots
            )
            logger.info("Successfully synced to AWS S3 bucket with profile: \(profileConfig.bucket)")
        } catch {
            logger.error("Failed to sync to AWS with profile: \(error.localizedDescription)")
            throw TCError.genericError("AWS profile sync failed: \(error.localizedDescription)")
        }
    }
    
    public func syncToAWSWithDefaultCredentials(region: String, bucket: String, encryptionSecret: String, avoidSnapshots: Bool = false) throws {
        guard let replica = replica else {
            throw TCError.genericError("No replica available")
        }
        
        do {
            try replica.sync_to_aws_with_default_creds(
                region,
                bucket: bucket,
                encryption_secret: encryptionSecret,
                avoid_snapshots: avoidSnapshots
            )
            logger.info("Successfully synced to AWS S3 bucket with default credentials: \(bucket)")
        } catch {
            logger.error("Failed to sync to AWS with default credentials: \(error.localizedDescription)")
            throw TCError.genericError("AWS default credentials sync failed: \(error.localizedDescription)")
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
    
    public func getLocalOperationsCount() throws -> UInt32 {
        guard let replica = replica else {
            throw TCError.genericError("No replica available")
        }
        
        do {
            return try replica.num_local_operations()
        } catch {
            logger.error("Failed to get local operations count: \(error.localizedDescription)")
            throw TCError.genericError("Failed to get local operations count: \(error.localizedDescription)")
        }
    }
    
    public func needsSync() throws -> Bool {
        do {
            let count = try getLocalOperationsCount()
            return count > 0
        } catch {
            logger.error("Failed to check if sync is needed: \(error.localizedDescription)")
            throw TCError.genericError("Failed to check sync status: \(error.localizedDescription)")
        }
    }
}
