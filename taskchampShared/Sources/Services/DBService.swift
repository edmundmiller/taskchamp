import Foundation
import os.log
import WidgetKit

// MARK: - Unified DBService

/// Unified DBService that provides a clean interface for task operations
/// This service wraps TaskchampionService while maintaining compatibility
public class DBService {

    public static let shared = DBService()
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "DBService")

    public init() {}

    public func setDbUrl(_ path: String) throws {
        TaskchampionService.shared.setDbUrl(path)
    }

    public func getTasks(
        sortType: TasksHelper.TCSortType = .defaultSort,
        filter: TCFilter = TCFilter.defaultFilter
    ) throws -> [TCTask] {
        return try TaskchampionService.shared.getTasks(sortType: sortType, filter: filter)
    }

    public func getTasks(filters _: [String]) throws -> [TCTask] {
        let filter = TCFilter()
        return try TaskchampionService.shared.getTasks(filter: filter)
    }

    public func getTask(uuid: String) throws -> TCTask {
        return try TaskchampionService.shared.getTask(uuid: uuid)
    }

    public func updateTask(_ task: TCTask) throws {
        try TaskchampionService.shared.updateTask(task)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func createTask(task: TCTask) throws {
        print("🔄 DEBUG: DBService.createTask() called - THIS SHOULD NOT BE CALLED!")
        throw TCError.genericError("DBService.createTask should not be called during testing")
    }

    public func togglePendingTasksStatus(uuids: Set<String>) throws {
        try TaskchampionService.shared.togglePendingTasksStatus(uuids: uuids)
    }

    public func updatePendingTasks(_ uuids: Set<String>, withStatus newStatus: TCTask.Status) throws {
        try TaskchampionService.shared.updatePendingTasks(uuids, withStatus: newStatus)
    }

    // MARK: - AWS Sync Methods

    public func syncToAWSFromUserDefaults() async throws {
        try await TaskchampionService.shared.syncToAWSFromUserDefaults()
    }

    public func needsSync() throws -> Bool {
        return try TaskchampionService.shared.needsSync()
    }

    public func getLocalOperationsCount() throws -> UInt32 {
        return UInt32(try TaskchampionService.shared.getLocalOperationsCount())
    }
}