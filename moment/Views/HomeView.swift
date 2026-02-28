//
//  HomeView.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NoteListView(context: viewContext)
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
