//
//  TodoSyncServiceTests.swift
//  moment
//
//  Created by Sisyphus on 2026/02/16.
//

import XCTest
import CoreData
@testable import moment

class TodoSyncServiceTests: XCTestCase {
    
    var persistentContainer: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var service: TodoSyncService!
    
    override func setUp() {
        super.setUp()
        
        // Setup in-memory Core Data stack
        let modelURL = Bundle.main.url(forResource: "moment", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
        persistentContainer = NSPersistentContainer(name: "moment", managedObjectModel: managedObjectModel)
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { (description, error) in
            XCTAssertNil(error)
        }
        
        context = persistentContainer.viewContext
        service = TodoSyncService.shared
    }
    
    override func tearDown() {
        persistentContainer = nil
        context = nil
        service = nil
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    func createNote(content: String) -> Note {
        let note = Note(context: context)
        note.id = UUID()
        note.content = content
        note.createdAt = Date()
        note.updatedAt = Date()
        return note
    }
    
    func createTodo(text: String, isCompleted: Bool, lineIndex: Int16, parentNote: Note) -> TodoItem {
        let todo = TodoItem(context: context)
        todo.id = UUID()
        todo.text = text
        todo.isCompleted = isCompleted
        todo.lineIndex = lineIndex
        todo.parentNote = parentNote
        todo.createdAt = Date()
        return todo
    }
    
    // MARK: - Tests
    
    func testDeleteTodo_RemovesLineFromNote() {
        // Given
        let content = """
        Title
        ○ Task 1
        ○ Task 2
        """
        let note = createNote(content: content)
        
        // Create todos (simulate sync having happened)
        let todo1 = createTodo(text: "Task 1", isCompleted: false, lineIndex: 1, parentNote: note)
        let todo2 = createTodo(text: "Task 2", isCompleted: false, lineIndex: 2, parentNote: note)
        
        // When
        service.deleteTodo(todo1, in: context)
        
        // Then
        let expectedContent = """
        Title
        ○ Task 2
        """
        XCTAssertEqual(note.content, expectedContent)
        XCTAssertTrue(todo1.deletedAt != nil)
    }
    
    func testDeleteTodo_MarksItemDeleted() {
        // Given
        let content = "○ Task 1"
        let note = createNote(content: content)
        let todo = createTodo(text: "Task 1", isCompleted: false, lineIndex: 0, parentNote: note)
        
        // When
        service.deleteTodo(todo, in: context)
        
        // Then
        XCTAssertNotNil(todo.deletedAt)
        XCTAssertEqual(todo.syncStatus, 1) // Pending sync
    }
    
    func testDeleteLastTodo_KeepsEmptyNote() {
        // Given
        let content = "○ Task 1"
        let note = createNote(content: content)
        let todo = createTodo(text: "Task 1", isCompleted: false, lineIndex: 0, parentNote: note)
        
        // When
        service.deleteTodo(todo, in: context)
        
        // Then
        // Note content should be empty string (or empty line depending on impl)
        // If the line is removed, it might be empty string if it was the only line.
        XCTAssertEqual(note.content, "") 
        XCTAssertNotNil(todo.deletedAt)
    }
    
    func testDeleteNonExistentTodo_SafelyReturns() {
        // Given
        let content = "Title"
        let note = createNote(content: content)
        // Todo points to line 5 which doesn't exist
        let todo = createTodo(text: "Ghost Task", isCompleted: false, lineIndex: 5, parentNote: note)
        
        // When
        service.deleteTodo(todo, in: context)
        
        // Then
        // Should mark deleted even if text not found (defensive)
        XCTAssertNotNil(todo.deletedAt)
        // Note content remains unchanged
        XCTAssertEqual(note.content, content)
    }
}
