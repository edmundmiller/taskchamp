import XCTest
@testable import taskchampShared
import Taskchampion

/// Simple test to debug TaskData conversion issues
class TaskChampionConversionDebuggingTests: XCTestCase {
    
    func testTaskDataConversionFromExistingTasks() throws {
        print("🔍 DEBUG: Testing TaskData conversion with real tasks")
        
        // Use a database path that might have existing tasks
        let dbPath = "/Users/emiller/Library/Mobile Documents/iCloud~com~emiller~taskchamp/Documents/task/taskchampion.sqlite3"
        
        // Check if the file exists
        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("⏭️  Skipping test - database file doesn't exist at: \(dbPath)")
            return
        }
        
        print("📁 Using existing database: \(dbPath)")
        
        let replica = new_replica_on_disk(dbPath)
        
        // Get all tasks using bridge
        let tasksVec = replica.get_all_tasks()
        print("📊 Bridge returned \(tasksVec.len()) tasks")
        
        if tasksVec.len() == 0 {
            print("⚠️  No tasks found in database - this might be normal")
            return
        }
        
        // Test conversion of first few tasks
        let maxTasks = min(5, Int(tasksVec.len()))
        for i in 0..<maxTasks {
            if let taskRef = tasksVec.get(index: UInt(i)) {
                print("\\n🔍 Converting task \(i+1):")
                
                // Get UUID
                let uuid = taskRef.get_uuid().to_string().toString()
                print("  UUID: \(uuid)")
                
                // Get all fields
                let fields = taskRef.get_fields()
                print("  Fields count: \(fields.len())")
                
                var taskProperties: [String: String] = [:]
                for j in 0..<fields.len() {
                    if let field = fields.get(index: UInt(j)) {
                        let key = field.get_key().toString()
                        let value = field.get_value().toString()
                        taskProperties[key] = value
                        print("    \(key): '\(value)'")
                    }
                }
                
                // Check if description exists (required field)
                if let description = taskProperties["description"] {
                    print("  ✅ Task has description: '\(description)'")
                } else {
                    print("  ❌ Task missing description field")
                }
                
                // Test TaskData creation
                let status = taskProperties["status"] ?? "pending"
                let project = taskProperties["project"]?.isEmpty == true ? nil : taskProperties["project"]
                let priority = taskProperties["priority"]?.isEmpty == true ? nil : taskProperties["priority"]
                let due = taskProperties["due"]?.isEmpty == true ? nil : taskProperties["due"]
                let obsidianNote = taskProperties["obsidianNote"]?.isEmpty == true ? nil : taskProperties["obsidianNote"]
                
                if let description = taskProperties["description"] {
                    let taskData = TaskData(
                        uuid: uuid,
                        description: description,
                        status: status,
                        project: project,
                        priority: priority,
                        due: due,
                        obsidianNote: obsidianNote
                    )
                    print("  ✅ TaskData created successfully")
                    print("     - UUID: \(taskData.uuid)")
                    print("     - Description: '\(taskData.description)'")
                    print("     - Status: \(taskData.status)")
                    print("     - Project: \(taskData.project ?? "nil")")
                    print("     - Priority: \(taskData.priority ?? "nil")")
                } else {
                    print("  ❌ Cannot create TaskData - missing description")
                }
            }
        }
    }
    
    func testTaskChampionServiceWithExistingDB() async throws {
        print("\\n🔍 DEBUG: Testing TaskchampionService with existing database")
        
        let dbPath = "/Users/emiller/Library/Mobile Documents/iCloud~com~emiller~taskchamp/Documents/task/taskchampion.sqlite3"
        
        guard FileManager.default.fileExists(atPath: dbPath) else {
            print("⏭️  Skipping service test - database file doesn't exist")
            return
        }
        
        // Initialize TaskchampionService with existing database
        TaskchampionService.shared.setDbUrl(dbPath)
        
        do {
            // Test getting tasks
            let tasks = try TaskchampionService.shared.getTasks()
            print("📊 TaskchampionService returned \(tasks.count) tasks")
            
            if tasks.count > 0 {
                print("🎉 SUCCESS: TaskchampionService is working!")
                for (index, task) in tasks.prefix(3).enumerated() {
                    print("  Task[\(index)]: '\(task.description)' (project: \(task.project ?? "nil"), status: \(task.status.rawValue))")
                }
            } else {
                print("⚠️  TaskchampionService returned no tasks")
                
                // Try S3 sync if configured
                if UserDefaults.standard.isAWSConfigured {
                    print("🔄 Trying S3 sync...")
                    try await TaskchampionService.shared.syncToAWSFromUserDefaults()
                    
                    let syncedTasks = try TaskchampionService.shared.getTasks()
                    print("📊 After S3 sync: \(syncedTasks.count) tasks")
                    
                    if syncedTasks.count > 0 {
                        print("🎉 S3 sync successful! Tasks retrieved.")
                    }
                }
            }
        } catch {
            print("❌ TaskchampionService failed: \(error)")
            throw error
        }
    }
}