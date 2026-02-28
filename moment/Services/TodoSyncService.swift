//
//  TodoSyncService.swift
//  moment
//

import Foundation
import CoreData

class TodoSyncService {
    static let shared = TodoSyncService()
    private static let syncAppleRemindersKey = "todoSyncAppleReminders"
    
    private let deadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    /// Pattern: @YYYY-MM-DD at end of line
    private let deadlinePattern = #"\s*@(\d{4}-\d{2}-\d{2})\s*$"#
    
    private init() {}
    
    // MARK: - Parsing Helpers
    
    private func parseTextAndDeadline(from rawText: String) -> (text: String, deadline: Date?) {
        guard let regex = try? NSRegularExpression(pattern: deadlinePattern, options: []) else {
            return (text: rawText.trimmingCharacters(in: .whitespaces), deadline: nil)
        }
        
        let nsString = rawText as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = regex.firstMatch(in: rawText, options: [], range: range) {
            let dateRange = match.range(at: 1)
            let dateString = nsString.substring(with: dateRange)
            let deadline = deadlineFormatter.date(from: dateString)
            let textWithoutDeadline = nsString.replacingCharacters(in: match.range, with: "")
            return (text: textWithoutDeadline.trimmingCharacters(in: .whitespaces), deadline: deadline)
        }
        
        return (text: rawText.trimmingCharacters(in: .whitespaces), deadline: nil)
    }
    
    func formatDeadline(_ date: Date) -> String {
        return "@" + deadlineFormatter.string(from: date)
    }
    
    // MARK: - Sync Methods
    
    func syncTodos(for note: Note, in context: NSManagedObjectContext) {
        guard let content = note.content else {
            removeAllTodos(for: note, in: context)
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        var currentTodoData: [(text: String, isCompleted: Bool, index: Int, deadline: Date?)] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("○ ") {
                let rawText = trimmedLine.replacingOccurrences(of: "○ ", with: "")
                let parsed = parseTextAndDeadline(from: rawText)
                currentTodoData.append((text: parsed.text, isCompleted: false, index: index, deadline: parsed.deadline))
            } else if trimmedLine.hasPrefix("● ") {
                let rawText = trimmedLine.replacingOccurrences(of: "● ", with: "")
                let parsed = parseTextAndDeadline(from: rawText)
                currentTodoData.append((text: parsed.text, isCompleted: true, index: index, deadline: parsed.deadline))
            }
        }
        
        let fetchRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "parentNote == %@ AND deletedAt == nil", note)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lineIndex", ascending: true)]
        
        do {
            let existingTodos = try context.fetch(fetchRequest)
            
            var usedExistingIndices = Set<Int>()
            
            for data in currentTodoData {
                if let existingTodo = existingTodos.first(where: { $0.lineIndex == Int16(data.index) }) {
                    usedExistingIndices.insert(Int(data.index))
                    
                    if existingTodo.text != data.text || 
                       existingTodo.isCompleted != data.isCompleted ||
                       existingTodo.deadline != data.deadline {
                        
                        existingTodo.text = data.text
                        existingTodo.isCompleted = data.isCompleted
                        existingTodo.deadline = data.deadline
                        existingTodo.syncStatus = 1
                        existingTodo.updatedAt = Date()
                        
                        self.syncToCalendar(existingTodo)
                    }
                } else {
                    let todo = TodoItem(context: context)
                    todo.id = UUID()
                    todo.text = data.text
                    todo.isCompleted = data.isCompleted
                    todo.lineIndex = Int16(data.index)
                    todo.deadline = data.deadline
                    todo.parentNote = note
                    todo.syncStatus = 1
                    todo.updatedAt = Date()
                    
                    if let currentUserId = AuthenticationService.shared.currentUser?.id {
                        todo.userId = currentUserId
                    }
                    
                    self.syncToCalendar(todo)
                }
            }
            
            for todo in existingTodos {
                if !usedExistingIndices.contains(Int(todo.lineIndex)) {
                    todo.deletedAt = Date()
                    todo.syncStatus = 1
                    todo.updatedAt = Date()
                }
            }
            
        } catch {
            print("Error syncing todos: \(error)")
        }
        
        save(context: context)
    }
    
    func toggleTodo(_ todo: TodoItem, in context: NSManagedObjectContext) {
        guard let note = todo.parentNote, let content = note.content else { return }
        
        let lines = content.components(separatedBy: .newlines)
        let index = Int(todo.lineIndex)
        
        guard index < lines.count else { return }
        
        var updatedLines = lines
        let currentLine = lines[index]
        
        if currentLine.hasPrefix("○ ") {
            updatedLines[index] = currentLine.replacingOccurrences(of: "○ ", with: "● ")
            todo.isCompleted = true
        } else if currentLine.hasPrefix("● ") {
            updatedLines[index] = currentLine.replacingOccurrences(of: "● ", with: "○ ")
            todo.isCompleted = false
        }
        
        note.content = updatedLines.joined(separator: "\n")
        note.syncStatus = 1
        note.updatedAt = Date()
        
        todo.syncStatus = 1
        todo.updatedAt = Date()
        
        self.syncToCalendar(todo)
        
        save(context: context)
        
        Task {
            await SyncEngine.shared.sync()
        }
    }
    
    // MARK: - Edit Methods
    
    func updateTodo(_ todo: TodoItem, newText: String, newDeadline: Date?, in context: NSManagedObjectContext) {
        guard let note = todo.parentNote, let content = note.content else { return }
        
        let lines = content.components(separatedBy: .newlines)
        let index = Int(todo.lineIndex)
        
        guard index < lines.count else { return }
        
        var updatedLines = lines
        let prefix = todo.isCompleted ? "● " : "○ "
        var newLine = prefix + newText.trimmingCharacters(in: .whitespaces)
        if let deadline = newDeadline {
            newLine += " " + formatDeadline(deadline)
        }
        
        updatedLines[index] = newLine
        note.content = updatedLines.joined(separator: "\n")
        note.syncStatus = 1
        note.updatedAt = Date()
        
        todo.text = newText.trimmingCharacters(in: .whitespaces)
        todo.deadline = newDeadline
        todo.syncStatus = 1 // 1 = Pending
        todo.updatedAt = Date()
        
        self.syncToCalendar(todo)
        
        save(context: context)
        
        Task {
            await SyncEngine.shared.sync()
        }
    }
    
    func deleteTodo(_ todo: TodoItem, in context: NSManagedObjectContext) {
        guard let note = todo.parentNote, let content = note.content else {
            markAsDeleted(todo)
            save(context: context)
            return
        }
        
        var lines = content.components(separatedBy: .newlines)
        let index = Int(todo.lineIndex)
        
        if index < lines.count {
            let line = lines[index]
            if line.hasPrefix("○ ") || line.hasPrefix("● ") {
                lines.remove(at: index)
                
                note.content = lines.joined(separator: "\n")
                note.syncStatus = 1
                note.updatedAt = Date()
                
                // Shift indices of subsequent todos
                let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
                request.predicate = NSPredicate(format: "parentNote == %@ AND lineIndex > %d AND deletedAt == nil", note, todo.lineIndex)
                
                do {
                    let subsequentTodos = try context.fetch(request)
                    for item in subsequentTodos {
                        item.lineIndex -= 1
                        item.syncStatus = 1
                        item.updatedAt = Date()
                    }
                } catch {
                    print("Error shifting todo indices: \(error)")
                }
            } else {
                 print("Warning: Todo line mismatch at index \(index). Text: \(line)")
            }
        }
        
        markAsDeleted(todo)
        save(context: context)
        
        Task {
            await SyncEngine.shared.sync()
        }
    }
    
    private func markAsDeleted(_ todo: TodoItem) {
        todo.deletedAt = Date()
        todo.syncStatus = 1
        todo.updatedAt = Date()
        
        if let reminderId = todo.reminderIdentifier {
             Task {
                 await CalendarManager.shared.deleteReminder(identifier: reminderId)
             }
        }
    }
    
    func removeDeadline(from todo: TodoItem, in context: NSManagedObjectContext) {
        updateTodo(todo, newText: todo.text ?? "", newDeadline: nil, in: context)
    }
    
    // MARK: - Private Helpers
    
    private func removeAllTodos(for note: Note, in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "parentNote == %@", note)
        
        do {
            let existingTodos = try context.fetch(fetchRequest)
            for todo in existingTodos {
                context.delete(todo)
            }
        } catch {
            print("Error fetching existing todos for deletion: \(error)")
        }
    }
    
    private func save(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving TodoSync: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Calendar/Reminders Sync
    
    private func syncToCalendar(_ todo: TodoItem) {
        let isSyncEnabled = UserDefaults.standard.object(forKey: Self.syncAppleRemindersKey) as? Bool ?? true
        guard isSyncEnabled else { return }
        
        let title = todo.text ?? ""
        let isCompleted = todo.isCompleted
        let deadline = todo.deadline
        let reminderIdentifier = todo.reminderIdentifier
        let context = todo.managedObjectContext
        
        Task { [weak todo] in
            let newId = await CalendarManager.shared.syncTodoToReminder(
                title: title,
                isCompleted: isCompleted,
                deadline: deadline,
                reminderIdentifier: reminderIdentifier
            )
            
            guard let newId = newId, let todo = todo, todo.reminderIdentifier != newId else { return }
            
            await context?.perform {
                todo.reminderIdentifier = newId
                try? todo.managedObjectContext?.save()
            }
        }
    }
}
