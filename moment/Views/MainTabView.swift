//
//  MainTabView.swift
//  moment
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var themeManager: ThemeManager

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 0 ? "folder.fill" : "folder")
                        Text("Notes")
                    }
                }
                .tag(0)
            
            TodoListView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 2 ? "checklist.checked" : "checklist")
                        Text("Todos")
                    }
                }
                .tag(1)
            
            UserView()
                .tabItem {
                    VStack {
                        Image(systemName: selectedTab == 3 ? "person.circle.fill" : "person.circle")
                        Text("User")
                    }
                }
                .tag(2)
        }
        .accentColor(MomentDesign.Colors.accent)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
