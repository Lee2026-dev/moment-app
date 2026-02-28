//
//  TodoListView.swift
//  moment
//

import SwiftUI
import CoreData
import EventKit

struct TodoListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("todoShowCalendarEvents") private var showCalendarEvents = true
    @AppStorage("todoShowAppleReminders") private var showAppleReminders = true
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoItem.deadline, ascending: true),
            NSSortDescriptor(keyPath: \TodoItem.parentNote?.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \TodoItem.lineIndex, ascending: true)
        ],
        predicate: NSPredicate(format: "isCompleted == false AND deletedAt == nil")
    ) private var pendingTodos: FetchedResults<TodoItem>
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoItem.parentNote?.timestamp, ascending: false),
            NSSortDescriptor(keyPath: \TodoItem.lineIndex, ascending: true)
        ],
        predicate: NSPredicate(format: "isCompleted == true AND deletedAt == nil")
    ) private var completedTodos: FetchedResults<TodoItem>
    
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var editingTodoWrapper: TodoEditingWrapper?
    var body: some View {
        NavigationView {
            ZStack {
                MomentDesign.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if showCalendarEvents {
                            CalendarEventsView()
                        }
                        
                        // Apple Reminders Section
                        if showAppleReminders && !calendarManager.reminders.isEmpty {
                            remindersSection
                        }
                        
                        if pendingTodos.isEmpty && completedTodos.isEmpty && (!showAppleReminders || calendarManager.reminders.isEmpty) {
                            emptyStateView
                        } else {
                            if !pendingTodos.isEmpty {
                                todoSection(title: "Upcoming Tasks", items: Array(pendingTodos))
                            }
                            
                            if !completedTodos.isEmpty {
                                todoSection(title: "Completed", items: Array(completedTodos))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Todos")
            .sheet(item: $editingTodoWrapper) { wrapper in
                TodoEditSheet(todo: wrapper.todo) { newText, newDeadline in
                    TodoSyncService.shared.updateTodo(wrapper.todo, newText: newText, newDeadline: newDeadline, in: viewContext)
                }
            }

        }
    }
    
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
             HStack {
                Image(systemName: "apple.logo")
                    .font(.system(size: 12))
                Text("Reminders")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(MomentDesign.Colors.textSecondary)
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(calendarManager.reminders, id: \.calendarItemIdentifier) { reminder in
                    ReminderItemRow(reminder: reminder) {
                        Task {
                            await calendarManager.toggleReminder(reminder)
                        }
                    }
                }
            }
        }
    }
    
    private func todoSection(title: String, items: [TodoItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(items, id: \.objectID) { todo in
                    TodoItemRow(
                        todo: todo,
                        onToggle: {
                            TodoSyncService.shared.toggleTodo(todo, in: viewContext)
                        },
                        onEdit: {
                            editingTodoWrapper = TodoEditingWrapper(todo: todo)
                        },
                        onDelete: {
                            withAnimation {
                                TodoSyncService.shared.deleteTodo(todo, in: viewContext)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
            .font(.system(size: 60))
            .foregroundColor(MomentDesign.Colors.accent.opacity(0.3))
            
            Text("No tasks found")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(MomentDesign.Colors.text)
            
            Text("Create a todo in any note using the ○ button to see it here.")
            .font(.system(size: 14))
            .foregroundColor(MomentDesign.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }
}

struct ReminderItemRow: View {
    let reminder: EKReminder
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation {
                    onToggle()
                    HapticHelper.medium()
                }
            }) {
                Circle()
                    .stroke(MomentDesign.Colors.textSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(MomentDesign.Colors.text)
                
                if let _ = reminder.dueDateComponents {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text("Due")
                           .font(.system(size: 11))
                    }
                    .foregroundColor(MomentDesign.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(MomentDesign.Colors.surface)
        .cornerRadius(16)
        .shadow(color: MomentDesign.Colors.shadow.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct TodoEditingWrapper: Identifiable {
    let todo: TodoItem
    var id: NSManagedObjectID { todo.objectID }
}

#Preview {
    TodoListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
