import Foundation
import os.log
// import Taskchampion // Temporarily disabled - API incompatible

// MARK: - Temporary Stub Types (until TaskChampion API is fixed)
private class Replica {
    // Stub implementation
}

// swiftlint:disable type_body_length file_length
public class TaskchampionService {
    public static let shared = TaskchampionService()
    private var replica: Replica?
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "TaskchampionService")

    public func setDbUrl(_ dbUrl: String) {
        // TODO: Implement when TaskChampion API is compatible
        logger.info("TaskChampion temporarily disabled - using SQLite service instead")
        replica = Replica() // Stub replica
    }

    public func getTasks(
        sortType: TasksHelper.TCSortType = .defaultSort,
        filter _: TCFilter = TCFilter.defaultFilter
    ) throws -> [TCTask] {
        logger.warning("TaskChampion API temporarily unavailable")
        throw TCError.genericError("TaskChampion service temporarily disabled - use DBService instead")
    }

    public func getTask(uuid: String) throws -> TCTask {
        logger.warning("TaskChampion API temporarily unavailable")
        throw TCError.genericError("TaskChampion service temporarily disabled - use DBService instead")
    }

    public func togglePendingTasksStatus(uuids: Set<String>) throws {
        logger.warning("TaskChampion API temporarily unavailable")
        throw TCError.genericError("TaskChampion service temporarily disabled - use DBService instead")
    }

    public func updatePendingTasks(_ uuids: Set<String>, withStatus status: TCTask.Status) throws {
        logger.warning("TaskChampion API temporarily unavailable")
        throw TCError.genericError("TaskChampion service temporarily disabled - use DBService instead")
    }

    public func updateTask(_ task: TCTask) throws {
        logger.warning("TaskChampion API temporarily unavailable")
        throw TCError.genericError("TaskChampion service temporarily disabled - use DBService instead")
    }

    public func createTask(task: TCTask) throws {
        logger.warning("TaskChampion API temporarily unavailable")
        throw TCError.genericError("TaskChampion service temporarily disabled - use DBService instead")
    }

    // MARK: - AWS Sync Methods (Keep these working for testing)

    public func syncToAWS(config: AWSConfig) throws {
        logger.warning("AWS sync temporarily disabled due to TaskChampion API issues")
        throw TCError.genericError("AWS sync temporarily disabled")
    }

    public func syncToAWS(profileConfig: AWSProfileConfig) throws {
        logger.warning("AWS sync temporarily disabled due to TaskChampion API issues")
        throw TCError.genericError("AWS sync temporarily disabled")
    }

    public func syncToAWSWithDefaultCredentials(
        region: String,
        bucket: String,
        encryptionSecret: String,
        avoidSnapshots: Bool = false
    ) throws {
        logger.warning("AWS sync temporarily disabled due to TaskChampion API issues")
        throw TCError.genericError("AWS sync temporarily disabled")
    }

    public func syncToAWSFromUserDefaults() throws {
        logger.warning("AWS sync temporarily disabled due to TaskChampion API issues")
        throw TCError.genericError("AWS sync temporarily disabled")
    }

    // MARK: - Sync Status Methods

    public func getLocalOperationsCount() throws -> UInt32 {
        logger.warning("TaskChampion API temporarily unavailable")
        return 0 // Return 0 to indicate no operations pending
    }

    public func needsSync() throws -> Bool {
        logger.warning("TaskChampion API temporarily unavailable")
        return false // Return false to indicate no sync needed
    }
}