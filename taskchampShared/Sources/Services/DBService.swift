import Foundation
import os.log

import SQLite
import WidgetKit

// This class is going to be deprecated in favor of the Taskchampion service:
// Please do not add any more features into this service, but rather make a PR to
// https://github.com/LostLaplace/taskchampion-swift
// Re-enabled temporarily while TaskChampion API is incompatible
public class DBServiceDEPRECATED {
     enum TasksColumns {
         static let uuid = SQLite.Expression<String>("uuid")
         static let data = SQLite.Expression<String>("data")
     }

     public static let shared = DBServiceDEPRECATED()
     private var dbConnection: Connection?
     private let logger = Logger(subsystem: "com.mav.taskchamp", category: "DBService")

     private init() {}

     public func setDbUrl(_ path: String) throws {
         do {
             dbConnection = try Connection(path)
             logger.info("Successfully connected to database at path: \(path)")

             // Log database info for debugging
             if let db = dbConnection {
                 do {
                     let userVersion = try db.scalar("PRAGMA user_version")
                     let journalMode = try db.scalar("PRAGMA journal_mode")
                     let foreignKeys = try db.scalar("PRAGMA foreign_keys")
                     logger.debug("Database info - user_version: \(String(describing: userVersion)), journal_mode: \(String(describing: journalMode)), foreign_keys: \(String(describing: foreignKeys))")
                 } catch {
                     logger.warning("Could not read database pragmas: \(error.localizedDescription)")
                 }
             }
         } catch {
             logger.error("Failed to connect to database at path \(path): \(error.localizedDescription)")
             throw TCError.genericError("Failed to connect to database: \(error.localizedDescription)")
         }
     }

     public func getTasks(
         sortType: TasksHelper.TCSortType = .defaultSort,
         filter: TCFilter = TCFilter.defaultFilter
     ) throws -> [TCTask] {
         var taskObjects: [TCTask] = []
         let tasks = Table("tasks")
         var query = tasks.select(TasksColumns.data, TasksColumns.uuid)
         for filter in filter.convertToSqlFilters() {
             query = query.filter(TasksColumns.data.like(filter))
         }
         guard let db = dbConnection else {
             throw TCError.genericError("No database connection available")
         }
         
         WidgetCenter.shared.reloadAllTimelines()
         let queryTasks = try db.prepare(query)
         for task in queryTasks {
             if let taskObject = try parseTask(row: task) {
                 taskObjects.append(taskObject)
             }
         }
         TasksHelper.sortTasksWithSortType(&taskObjects, sortType: sortType)
         return taskObjects
     }

     public func getTask(uuid: String) throws -> TCTask {
         guard let db = dbConnection else {
             throw TCError.genericError("No database connection available")
         }
         
         let tasks = Table("tasks")
         let query = tasks.filter(uuid == TasksColumns.uuid)
         let queryTasks = try db.prepare(query)
         for task in queryTasks {
             let taskObject = try parseTask(row: task)
             if let taskObject {
                 return taskObject
             }
         }
         throw TCError.genericError("Task not found")
     }

     private func parseTask(row: Row) throws -> TCTask? {
         let jsonObject = row[TasksColumns.data]
         let jsonData = jsonObject.data(using: .utf8)
         if let jsonData {
             var jsonDictionary = try? JSONSerialization
                 .jsonObject(with: jsonData, options: []) as? [String: Any]

             jsonDictionary?["uuid"] = row[TasksColumns.uuid]

             guard let jsonDictionary else {
                 throw TCError.genericError("jsonDictionary was null")
             }

             let updatedJsonData = try? JSONSerialization.data(withJSONObject: jsonDictionary, options: [])

             guard let updatedJsonData else {
                 throw TCError.genericError("updatedJsonData was null")
             }

             let jsonDecoder = JSONDecoder()
             jsonDecoder.dateDecodingStrategy = .secondsSince1970

             let taskObject = try? jsonDecoder.decode(TCTask.self, from: updatedJsonData)

             return taskObject
         }
         return nil
     }

     public func togglePendingTasksStatus(uuids: Set<String>) throws {
         guard let db = dbConnection else {
             throw TCError.genericError("No database connection available")
         }
         
         let tasks = Table("tasks")
         let query = tasks.filter(uuids.contains(TasksColumns.uuid))
         let queryTasks = try db.prepare(query)
         for task in queryTasks {
             if let taskObject = try parseTask(row: task) {
                 let newStatus: TCTask.Status = taskObject.status == .pending ? .completed : .pending
                 var newTask = taskObject
                 newTask.status = newStatus
                 try updateTask(newTask)
             }
         }
     }

     public func updatePendingTasks(_ uuids: Set<String>, withStatus newStatus: TCTask.Status) throws {
         guard let db = dbConnection else {
             throw TCError.genericError("No database connection available")
         }
         
         let oldStatus: TCTask.Status = (newStatus == .deleted || newStatus == .completed) ? .pending : .completed
         let tasks = Table("tasks")

         let query = tasks.filter(uuids.contains(TasksColumns.uuid))
         let queryTasks = try db.prepare(query)
         for task in queryTasks {
             var newData = task[TasksColumns.data].replacingOccurrences(
                 of: oldStatus.rawValue,
                 with: newStatus.rawValue
             )
             if oldStatus == .completed {
                 newData = newData.replacingOccurrences(of: TCTask.Status.deleted.rawValue, with: newStatus.rawValue)
             }
             if newStatus == .deleted {
                 newData = newData.replacingOccurrences(
                     of: TCTask.Status.completed.rawValue,
                     with: TCTask.Status.deleted.rawValue
                 )
             }
             try db.run(query.update(TasksColumns.data <- newData))
             WidgetCenter.shared.reloadAllTimelines()
         }
     }

     public func updateTask(_ task: TCTask) throws {
         let jsonData = try JSONEncoder().encode(task)
         var jsonDictionary = try? JSONSerialization
             .jsonObject(with: jsonData, options: []) as? [String: Any]

         let modifiedDate = String(Date().timeIntervalSince1970.rounded())

         jsonDictionary?["modified"] = modifiedDate

         guard let db = dbConnection else {
             throw TCError.genericError("No database connection available")
         }
         
         let tasks = Table("tasks")
         let query = tasks.filter(TasksColumns.uuid == task.uuid.lowercased())
         let queryTasks = try db.prepare(query)


         for taskRow in queryTasks {
             let oldData = taskRow[TasksColumns.data].data(using: .utf8)
             guard let oldData else {
                 throw TCError.genericError("oldData was null")
             }
             let oldJsonDictionary = try? JSONSerialization
                 .jsonObject(with: oldData, options: []) as? [String: Any]

             guard let oldJsonDictionary, let jsonDictionary else {
                 throw TCError.genericError("jsonDictionary was null")
             }
             let mergedJsonDictionary = oldJsonDictionary.merging(jsonDictionary) { _, new in new }

             let updatedJsonData = try? JSONSerialization.data(withJSONObject: mergedJsonDictionary, options: [])

             guard let updatedJsonData else {
                 throw TCError.genericError("updatedJsonData was null")
             }
             let jsonString = String(data: updatedJsonData, encoding: .utf8)
             guard let jsonString else {
                 throw TCError.genericError("jsonString was null")
             }
             guard let db = dbConnection else {
                 throw TCError.genericError("No database connection available")
             }
             
             do {
                 try db.run(query.update(TasksColumns.data <- jsonString))
                 logger.debug("Successfully updated task with UUID: \(taskRow[TasksColumns.uuid])")
             } catch {
                 logger.error("Failed to update task \(taskRow[TasksColumns.uuid]): \(error.localizedDescription)")
                 throw TCError.genericError("Database update failed: \(error.localizedDescription)")
             }
             WidgetCenter.shared.reloadAllTimelines()
         }
     }

     public func createTask(_ task: TCTask) throws {
         let jsonData = try JSONEncoder().encode(task)
         var jsonDictionary = try? JSONSerialization
             .jsonObject(with: jsonData, options: []) as? [String: Any]

         let createdDate = String(Date().timeIntervalSince1970.rounded())

         jsonDictionary?["modified"] = createdDate
         jsonDictionary?["entry"] = createdDate

         guard let jsonDictionary else {
             throw TCError.genericError("jsonDictionary was null")
         }

         let updatedJsonData = try? JSONSerialization.data(withJSONObject: jsonDictionary, options: [])

         guard let updatedJsonData else {
             throw TCError.genericError("updatedJsonData was null")
         }

         let jsonString = String(data: updatedJsonData, encoding: .utf8)
         guard let jsonString else {
             throw TCError.genericError("jsonString was null")
         }
         guard let db = dbConnection else {
             throw TCError.genericError("No database connection available")
         }
         
         let tasks = Table("tasks")
         do {
             try db.run(tasks.insert(
                 TasksColumns.uuid <- task.uuid.lowercased(),
                 TasksColumns.data <- jsonString
             ))
             logger.debug("Successfully created task with UUID: \(task.uuid)")
         } catch {
             logger.error("Failed to create task \(task.uuid): \(error.localizedDescription)")
             throw TCError.genericError("Database insert failed: \(error.localizedDescription)")
         }
         WidgetCenter.shared.reloadAllTimelines()
     }

     /// Diagnose database compatibility issues with different Taskwarrior versions
     public func diagnoseDatabaseCompatibility() -> String {
         guard let db = dbConnection else {
             return "No database connection available"
         }

         var diagnostics: [String] = []

         do {
             // Check database version and settings
             let userVersion = try db.scalar("PRAGMA user_version") as! Int64
             let journalMode = try db.scalar("PRAGMA journal_mode") as! String
             let foreignKeys = try db.scalar("PRAGMA foreign_keys") as! Int64
             let walAutocheckpoint = try db.scalar("PRAGMA wal_autocheckpoint") as! Int64

             diagnostics.append("Database version: \(userVersion)")
             diagnostics.append("Journal mode: \(journalMode)")
             diagnostics.append("Foreign keys: \(foreignKeys == 1 ? "enabled" : "disabled")")
             diagnostics.append("WAL autocheckpoint: \(walAutocheckpoint)")

             // Check table schema
             let tableInfo = try db.prepare("PRAGMA table_info(tasks)")
             var columns: [String] = []
             for row in tableInfo {
                 let name = row[1] as! String
                 let type = row[2] as! String
                 columns.append("\(name) (\(type))")
             }
             diagnostics.append("Tasks table columns: \(columns.joined(separator: ", "))")

             // Check for additional tables that might cause conflicts
             let tables = try db.prepare("SELECT name FROM sqlite_master WHERE type='table'")
             var tableNames: [String] = []
             for row in tables {
                 tableNames.append(row[0] as! String)
             }
             diagnostics.append("All tables: \(tableNames.joined(separator: ", "))")

             // Test write permissions
             do {
                 try db.run("CREATE TEMP TABLE test_write (id INTEGER)")
                 try db.run("DROP TABLE test_write")
                 diagnostics.append("Write permissions: OK")
             } catch {
                 diagnostics.append("Write permissions: FAILED - \(error.localizedDescription)")
             }

         } catch {
             diagnostics.append("Error during diagnosis: \(error.localizedDescription)")
         }

         return diagnostics.joined(separator: "\n")
     }
 }

// MARK: - Unified DBService

/// Unified DBService that provides a clean interface for task operations
/// This service wraps both the deprecated and new services while maintaining compatibility
public class DBService {

    public static let shared = DBService()
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "DBService")

    public init() {}

    public func setDbUrl(_ path: String) throws {
        try DBServiceDEPRECATED.shared.setDbUrl(path)
    }

    public func getTasks(
        sortType: TasksHelper.TCSortType = .defaultSort,
        filter: TCFilter = TCFilter.defaultFilter
    ) throws -> [TCTask] {
        return try DBServiceDEPRECATED.shared.getTasks(sortType: sortType, filter: filter)
    }

    public func getTasks(filters _: [String]) throws -> [TCTask] {
        let filter = TCFilter()
        return try DBServiceDEPRECATED.shared.getTasks(filter: filter)
    }

    public func getTask(uuid: String) throws -> TCTask {
        return try DBServiceDEPRECATED.shared.getTask(uuid: uuid)
    }

    public func updateTask(_ task: TCTask) throws {
        try DBServiceDEPRECATED.shared.updateTask(task)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func createTask(task: TCTask) throws {
        try DBServiceDEPRECATED.shared.createTask(task)
    }

    public func togglePendingTasksStatus(uuids: Set<String>) throws {
        // Convert to individual task operations using TaskchampionService
        for uuid in uuids {
            let task = try DBServiceDEPRECATED.shared.getTask(uuid: uuid)
            var updatedTask = task
            updatedTask.status = task.status == .pending ? .completed : .pending
            try DBServiceDEPRECATED.shared.updateTask(updatedTask)
        }
    }

    public func updatePendingTasks(_ uuids: Set<String>, withStatus newStatus: TCTask.Status) throws {
        // Convert to individual task operations using TaskchampionService
        for uuid in uuids {
            let task = try DBServiceDEPRECATED.shared.getTask(uuid: uuid)
            var updatedTask = task
            updatedTask.status = newStatus
            try DBServiceDEPRECATED.shared.updateTask(updatedTask)
        }
    }

    // MARK: - AWS Sync Methods

    public func syncToAWSFromUserDefaults() throws {
        // AWS sync requires TaskChampion integration - currently disabled during migration
        // For now, show user a helpful message about using desktop sync
        let bucket = UserDefaults.standard.awsBucket
        if !bucket.isEmpty {
            throw TCError.genericError("AWS sync is configured but temporarily unavailable during TaskChampion migration. Use desktop Taskwarrior 'task sync' to sync with S3 bucket '\(bucket)' for now.")
        } else {
            throw TCError.genericError("AWS sync not configured. Configure AWS settings first.")
        }
    }

    public func needsSync() throws -> Bool {
        // Return true if AWS is configured, indicating sync would be beneficial
        return UserDefaults.standard.isAWSConfigured
    }

    public func getLocalOperationsCount() throws -> UInt32 {
        // Count local tasks as a proxy for sync operations needed
        let tasks = try DBServiceDEPRECATED.shared.getTasks()
        return UInt32(tasks.count)
    }
}
