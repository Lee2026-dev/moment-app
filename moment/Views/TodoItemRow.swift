//
//  TodoItemRow.swift
//  moment
//

import SwiftUI

struct TodoItemRow: View {
    @ObservedObject var todo: TodoItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var deadlineColor: Color {
        guard let deadline = todo.deadline else { return MomentDesign.Colors.textSecondary }
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        if daysUntil < 0 {
            return MomentDesign.Colors.destructive
        } else if daysUntil == 0 {
            return MomentDesign.Colors.warning
        } else if daysUntil <= 3 {
            return MomentDesign.Colors.warning.opacity(0.8)
        }
        return MomentDesign.Colors.accent
    }
    
    private var deadlineText: String? {
        guard let deadline = todo.deadline else { return nil }
        let calendar = Calendar.current
        let daysUntil = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: deadline)).day ?? 0
        
        if daysUntil < 0 {
            return "Overdue"
        } else if daysUntil == 0 {
            return "Today"
        } else if daysUntil == 1 {
            return "Tomorrow"
        } else if daysUntil <= 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: deadline)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: deadline)
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            checkboxButton
            
            VStack(alignment: .leading, spacing: 4) {
                todoTextAndDeadline
                parentNoteLink
            }
            
            Spacer()
            
            editButton
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(MomentDesign.Colors.surface)
        .cornerRadius(16)
        .shadow(color: MomentDesign.Colors.shadow.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
            HapticHelper.light()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
                HapticHelper.medium()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var checkboxButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onToggle()
                HapticHelper.medium()
            }
        }) {
            ZStack {
                Circle()
                    .stroke(todo.isCompleted ? MomentDesign.Colors.accent : MomentDesign.Colors.textSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 26, height: 26)
                
                if todo.isCompleted {
                    Circle()
                        .fill(MomentDesign.Colors.accent)
                        .frame(width: 18, height: 18)
                        .transition(.scale.combined(with: .opacity))
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var todoTextAndDeadline: some View {
        HStack(spacing: 8) {
            Text(todo.text ?? "")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(todo.isCompleted ? MomentDesign.Colors.textSecondary : MomentDesign.Colors.text)
                .strikethrough(todo.isCompleted, color: MomentDesign.Colors.textSecondary)
                .lineLimit(2)
            
            if let deadlineLabel = deadlineText, !todo.isCompleted {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                    Text(deadlineLabel)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(deadlineColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(deadlineColor.opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }
    
    @ViewBuilder
    private var parentNoteLink: some View {
        if let parentNote = todo.parentNote {
            NavigationLink(destination: NoteDetailView(note: parentNote)) {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                    Text(parentNote.displayTitle)
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(MomentDesign.Colors.accent.opacity(0.5))
                }
                .foregroundColor(MomentDesign.Colors.accent.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(TapGesture().onEnded {
                HapticHelper.light()
            })
        }
    }
    
    private var editButton: some View {
        Button(action: {
            onEdit()
            HapticHelper.light()
        }) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(MomentDesign.Colors.surfaceElevated)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
