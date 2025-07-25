import XCTest
@testable import taskchampShared
import Taskchampion

/// Test to verify that the TaskChampion CRUD fix actually works
class TaskChampionCRUDFixVerificationTest: XCTestCase {
    
    var tempDbPath: String!
    
    override func setUp() {
        super.setUp()
        // Create a temporary database file for testing
        let tempDir = NSTemporaryDirectory()
        tempDbPath = "\(tempDir)taskchampion_crud_fix_test_\(UUID().uuidString).db"
        print("🧪 CRUD Fix Test DB path: \(tempDbPath!)")
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up the temporary database file
        try? FileManager.default.removeItem(atPath: tempDbPath)
    }
    
    func testTaskChampionCRUDFixWorking() throws {
        print("🧪 Testing TaskChampion CRUD Fix...")
        
        // Initialize TaskchampionService with test database
        TaskchampionService.shared.setDbUrl(tempDbPath)
        print("✅ TaskchampionService initialized")
        
        // Test 1: Create a task using the fixed method
        print("\n🧪 Test 1: Creating a task using fixed method...")
        let testTask = TCTask(
            uuid: UUID().uuidString,
            project: "CRUDFixTest",
            description: "Test task for CRUD fix verification",
            status: .pending,
            priority: .high,
            due: nil,
            obsidianNote: "Test note for verification"
        )
        
        try TaskchampionService.shared.createTask(task: testTask)
        print("✅ Task created successfully: \(testTask.uuid)")
        
        // Test 2: Verify task was actually persisted by retrieving it
        print("\n🧪 Test 2: Verifying task persistence...")
        let retrievedTask = try TaskchampionService.shared.getTask(uuid: testTask.uuid)
        print("✅ Task retrieved: '\(retrievedTask.description)'")
        print("   - Project: \(retrievedTask.project ?? "nil")")
        print("   - Priority: \(retrievedTask.priority?.rawValue ?? "nil")")
        print("   - Status: \(retrievedTask.status.rawValue)")
        print("   - Note: \(retrievedTask.obsidianNote ?? "nil")")
        
        // Verify the properties match
        XCTAssertEqual(retrievedTask.description, testTask.description)
        XCTAssertEqual(retrievedTask.project, testTask.project)
        XCTAssertEqual(retrievedTask.priority, testTask.priority)
        XCTAssertEqual(retrievedTask.status, testTask.status)
        XCTAssertEqual(retrievedTask.obsidianNote, testTask.obsidianNote)
        
        // Test 3: Update the task using the fixed method
        print("\n🧪 Test 3: Updating the task using fixed method...")
        var updatedTask = retrievedTask
        updatedTask.description = "Updated task description - CRUD fix test"
        updatedTask.project = "UpdatedCRUDFixTest"
        updatedTask.priority = .medium
        updatedTask.status = .completed
        updatedTask.obsidianNote = "Updated test note"
        
        try TaskchampionService.shared.updateTask(updatedTask)
        print("✅ Task updated successfully")
        
        // Test 4: Verify update was persisted by retrieving it again
        print("\n🧪 Test 4: Verifying update persistence...")
        let finalTask = try TaskchampionService.shared.getTask(uuid: testTask.uuid)
        print("✅ Updated task retrieved: '\(finalTask.description)'")
        print("   - Project: \(finalTask.project ?? "nil")")
        print("   - Priority: \(finalTask.priority?.rawValue ?? "nil")")
        print("   - Status: \(finalTask.status.rawValue)")
        print("   - Note: \(finalTask.obsidianNote ?? "nil")")
        
        // Verify the updates match
        XCTAssertEqual(finalTask.description, updatedTask.description)
        XCTAssertEqual(finalTask.project, updatedTask.project)
        XCTAssertEqual(finalTask.priority, updatedTask.priority)
        XCTAssertEqual(finalTask.status, updatedTask.status)
        XCTAssertEqual(finalTask.obsidianNote, updatedTask.obsidianNote)
        
        // Test 5: Check that the task shows up in the full list
        print("\n🧪 Test 5: Checking task appears in full task list...")
        let allTasks = try TaskchampionService.shared.getTasks()
        print("✅ Total tasks in database: \(allTasks.count)")
        
        XCTAssertEqual(allTasks.count, 1, "Should have exactly 1 task in database")
        
        let taskInList = allTasks.first!
        XCTAssertEqual(taskInList.uuid, finalTask.uuid)
        XCTAssertEqual(taskInList.description, finalTask.description)
        
        print("\n🎉 SUCCESS: TaskChampion CRUD fix is working!")
        print("   - ✅ Create: Task persisted correctly")
        print("   - ✅ Read: Task retrieved correctly") 
        print("   - ✅ Update: Changes persisted correctly")
        print("   - ✅ List: Task appears in full list correctly")
    }
}