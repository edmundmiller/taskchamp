import Foundation
import os.log

public class FileService {
    public static let shared = FileService()
    private let logger = Logger(subsystem: "com.mav.taskchamp", category: "FileService")

    private init() {}

    public func isICloudAvailable() -> Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }

    public func getDestinationPath() throws -> String {
        let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        guard let containerURL = containerURL else {
            throw TCError.genericError("No container URL")
        }

        let documentsURL = containerURL.appendingPathComponent("Documents")
        let taskDirectory = documentsURL.appendingPathComponent("task")

        let exists = FileManager.default.fileExists(atPath: taskDirectory.path)
        guard exists else {
            throw TCError.genericError("Task directory not found")
        }
        
        // Return directory path for TaskChampion, not file path
        return taskDirectory.path
    }

    public func copyDatabaseIfNeededAndGetDestinationPath() throws -> String {
        // Always use local documents directory since iCloud container requires paid developer account
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logger.info("Using local documents directory: \(baseURL.path)")
        
        // TODO: For full iCloud Drive sync, need to enable iCloud entitlements with paid Apple Developer account
        // Then use: FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.mav.taskchamp")

        let taskDirectory = baseURL.appendingPathComponent("task")
        let databaseFile = taskDirectory.appendingPathComponent("taskchampion.db")

        createDirectoryIfNeeded(url: baseURL)
        createDirectoryIfNeeded(url: taskDirectory)

        // Clean up legacy directory structure if it exists
        // (Previous versions may have created taskchampion.db as a directory)
        if FileManager.default.fileExists(atPath: databaseFile.path) {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: databaseFile.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                logger.info("Removing legacy directory structure at database path")
                try? FileManager.default.removeItem(at: databaseFile)
            }
        }

        // TaskChampion expects a file path to the SQLite database
        // It will create the database file if it doesn't exist
        logger.info("TaskChampion database file path: \(databaseFile.path)")
        return databaseFile.path
    }

    func createDirectoryIfNeeded(url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                print("Error creating directory: \(error)")
            }
        }
    }
}
