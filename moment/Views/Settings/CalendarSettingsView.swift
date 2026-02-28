//
//  CalendarSettingsView.swift
//  moment
//
//  Created by Codex on 2026/02/14.
//

import EventKit
import SwiftUI
import UIKit

struct CalendarSettingsView: View {
    @Environment(\.openURL) private var openURL
    
    @ObservedObject private var calendarManager = CalendarManager.shared
    
    @AppStorage("todoShowCalendarEvents") private var showCalendarEvents = true
    @AppStorage("todoShowAppleReminders") private var showAppleReminders = true
    @AppStorage("todoSyncAppleReminders") private var syncAppleReminders = true
    
    var body: some View {
        ZStack {
            MomentDesign.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    permissionSection
                    optionsSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Calendar & Reminders")
        .task {
            await calendarManager.checkAuthorizationStatus()
        }
    }
    
    // MARK: - Subviews
    
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Access")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                permissionRow(
                    title: "Apple Calendar",
                    icon: "calendar",
                    status: eventAuthorizationStatus
                )
                
                Divider()
                    .padding(.leading, 56)
                
                permissionRow(
                    title: "Apple Reminders",
                    icon: "checklist",
                    status: reminderAuthorizationStatus
                )
            }
            .background(MomentDesign.Colors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 0.5)
            )
            
            Button(action: handleAccessButtonTapped) {
                Text(accessButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(MomentDesign.Colors.accent)
                    .cornerRadius(12)
            }
        }
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Integration")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(MomentDesign.Colors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                Toggle(isOn: $showCalendarEvents) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Calendar Events")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MomentDesign.Colors.text)
                        Text("Display upcoming Apple Calendar events in Todos.")
                            .font(.system(size: 12))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .onChange(of: showCalendarEvents) { _ in
                    HapticHelper.light()
                }
                
                Divider()
                    .padding(.leading, 16)
                
                Toggle(isOn: $showAppleReminders) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Apple Reminders")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MomentDesign.Colors.text)
                        Text("Show reminder items from the Reminders app in Todos.")
                            .font(.system(size: 12))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .onChange(of: showAppleReminders) { _ in
                    HapticHelper.light()
                }
                
                Divider()
                    .padding(.leading, 16)
                
                Toggle(isOn: $syncAppleReminders) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync Todos to Reminders")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MomentDesign.Colors.text)
                        Text("Create and update Apple Reminders from Moment todo items.")
                            .font(.system(size: 12))
                            .foregroundColor(MomentDesign.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .onChange(of: syncAppleReminders) { _ in
                    HapticHelper.light()
                }
            }
            .background(MomentDesign.Colors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MomentDesign.Colors.border.opacity(0.5), lineWidth: 0.5)
            )
        }
    }
    
    private func permissionRow(title: String, icon: String, status: EKAuthorizationStatus) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(MomentDesign.Colors.accent)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(MomentDesign.Colors.text)
            
            Spacer()
            
            Text(label(for: status))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color(for: status))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - Methods
    
    private var eventAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }
    
    private var reminderAuthorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }
    
    private var accessButtonTitle: String {
        if eventAuthorizationStatus == .denied || reminderAuthorizationStatus == .denied {
            return "Open iOS Settings"
        }
        
        return "Request Access"
    }
    
    private func handleAccessButtonTapped() {
        if eventAuthorizationStatus == .denied || reminderAuthorizationStatus == .denied {
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(settingsURL)
            return
        }
        
        Task {
            await calendarManager.requestAccess()
            HapticHelper.medium()
        }
    }
    
    private func label(for status: EKAuthorizationStatus) -> String {
        switch status {
        case .authorized, .fullAccess:
            return "Allowed"
        case .writeOnly:
            return "Write Only"
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func color(for status: EKAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            return .green
        case .notDetermined:
            return .orange
        case .restricted, .denied:
            return .red
        @unknown default:
            return MomentDesign.Colors.textSecondary
        }
    }
}
