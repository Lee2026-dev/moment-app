//
//  FavoriteView.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import SwiftUI
import CoreData

struct FavoriteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("note_layout_mode") private var layoutMode: LayoutMode = .list
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.timestamp, ascending: false)],
        predicate: NSPredicate(format: "isFavorite == %@", NSNumber(value: true)),
        animation: .default
    )
    private var favoriteNotes: FetchedResults<Note>
    
    var body: some View {
        NavigationStack {
            ZStack {
                MomentDesign.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Favorites")
                            .font(.system(size: 34, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 15)
                    
                    if favoriteNotes.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(MomentDesign.Colors.accent.opacity(0.08))
                                    .frame(width: 120, height: 120)
                                Image(systemName: "heart.slash")
                                    .font(.system(size: 50, weight: .light))
                                    .foregroundColor(MomentDesign.Colors.accent.opacity(0.6))
                            }
                            Text("No Favorites Yet")
                                .font(.system(size: 22, weight: .semibold))
                            Text("Notes you favorite will appear here for quick access.")
                                .font(.system(size: 15))
                                .foregroundColor(MomentDesign.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                if layoutMode == .list {
                                    LazyVStack(spacing: 16) {
                                        ForEach(favoriteNotes) { note in
                                            NavigationLink(destination: NoteDetailView(note: note)) {
                                                NoteRowView(note: note)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 16) {
                                        let notes = Array(favoriteNotes)
                                        let leftColumn = notes.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
                                        let rightColumn = notes.enumerated().filter { $0.offset % 2 != 0 }.map { $0.element }
                                        
                                        LazyVStack(spacing: 16) {
                                            ForEach(leftColumn, id: \.id) { note in
                                                noteCard(note: note)
                                            }
                                        }
                                        
                                        LazyVStack(spacing: 16) {
                                            ForEach(rightColumn, id: \.id) { note in
                                                noteCard(note: note)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    @ViewBuilder
    private func noteCard(note: Note) -> some View {
        NavigationLink(destination: NoteDetailView(note: note)) {
            NoteCardView(note: note)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FavoriteView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
