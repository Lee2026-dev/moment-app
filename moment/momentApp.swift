//
//  momentApp.swift
//  moment
//
//  Created by wen li on 2025/12/30.
//

import SwiftUI
import CoreData

@main
struct momentApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.scenePhase) private var scenePhase
    private let transcriptionManager = TranscriptionManager.shared
    init() {
        // Firebase removed
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authService.isCheckingAuth {
                    MomentDesign.Colors.background.ignoresSafeArea()
                    LaunchScreenView()
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                } else if authService.isLoggedIn {
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(themeManager)
                        .environmentObject(GlobalAudioService.shared)
                        .environmentObject(authService)
                        .preferredColorScheme(themeManager.preferredColorScheme)

                    AudioRecordingOverlay()
                } else {
                    UserView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(themeManager)
                        .environmentObject(authService)
                        .preferredColorScheme(themeManager.preferredColorScheme)
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task {
                        await authService.refreshSessionIfNeeded()
                        await SyncEngine.shared.sync()
                    }
                }
            }
            
        }
    }
}
