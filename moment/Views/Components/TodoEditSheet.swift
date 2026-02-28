//
//  TodoEditSheet.swift
//  moment
//

import SwiftUI
import CoreData

struct TodoEditSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let todo: TodoItem
    let onSave: (String, Date?) -> Void
    
    @State private var editedText: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date()
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                MomentDesign.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        textSection
                        deadlineSection
                        noteInfoSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(MomentDesign.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(MomentDesign.Colors.accent)
                    .disabled(editedText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            editedText = todo.text ?? ""
            if let existingDeadline = todo.deadline {
                hasDeadline = true
                deadline = existingDeadline
            }
            isTextFieldFocused = true
        }
    }
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TASK")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(MomentDesign.Colors.textSecondary)
            
            TextField("What needs to be done?", text: $editedText, axis: .vertical)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(MomentDesign.Colors.text)
                .padding(16)
                .background(MomentDesign.Colors.surface)
                .cornerRadius(16)
                .focused($isTextFieldFocused)
                .lineLimit(1...5)
        }
    }
    
    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEADLINE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(MomentDesign.Colors.textSecondary)
            
            VStack(spacing: 0) {
                Toggle(isOn: $hasDeadline) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(hasDeadline ? MomentDesign.Colors.accent : MomentDesign.Colors.textSecondary)
                        Text("Set deadline")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MomentDesign.Colors.text)
                    }
                }
                .tint(MomentDesign.Colors.accent)
                .padding(16)
                .onChange(of: hasDeadline) { newValue in
                    HapticHelper.light()
                    if newValue && todo.deadline == nil {
                        deadline = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    }
                }
                
                if hasDeadline {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    DatePicker(
                        "Due date",
                        selection: $deadline,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(MomentDesign.Colors.accent)
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(MomentDesign.Colors.surface)
            .cornerRadius(16)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasDeadline)
        }
    }
    
    private var noteInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SOURCE NOTE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(MomentDesign.Colors.textSecondary)
            
            if let parentNote = todo.parentNote {
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 16))
                        .foregroundColor(MomentDesign.Colors.accent)
                    
                    Text(parentNote.displayTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(MomentDesign.Colors.text)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "link")
                        .font(.system(size: 12))
                        .foregroundColor(MomentDesign.Colors.textSecondary)
                }
                .padding(16)
                .background(MomentDesign.Colors.surface)
                .cornerRadius(16)
            }
        }
    }
    
    private func saveChanges() {
        let trimmedText = editedText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }
        
        let finalDeadline = hasDeadline ? deadline : nil
        onSave(trimmedText, finalDeadline)
        HapticHelper.success()
        dismiss()
    }
}
