
import SwiftUI
import EventKit

struct CalendarEventsView: View {
    @StateObject private var calendarManager = CalendarManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Events")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.activeTheme.textSecondary)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await calendarManager.requestAccess()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.activeTheme.textSecondary)
                }
            }
            .padding(.horizontal, 4)
            
            if calendarManager.upcomingEvents.isEmpty {
                Text("No upcoming events")
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.activeTheme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.activeTheme.surface)
                    .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(calendarManager.upcomingEvents, id: \.eventIdentifier) { event in
                            EventCard(event: event)
                                .environmentObject(themeManager)
                        }
                    }
                }
            }
        }
        .onAppear {
            calendarManager.fetchUpcomingEvents()
        }
    }
}

struct EventCard: View {
    let event: EKEvent
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 8, height: 8)
                
                Text(event.startDate, style: .time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.activeTheme.textSecondary)
            }
            
            Text(event.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.activeTheme.text)
                .lineLimit(2)
            
            if let location = event.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(location)
                        .font(.system(size: 10))
                }
                .foregroundColor(themeManager.activeTheme.textSecondary)
            }
        }
        .padding(12)
        .frame(width: 160, height: 100, alignment: .topLeading)
        .background(themeManager.activeTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.activeTheme.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}
