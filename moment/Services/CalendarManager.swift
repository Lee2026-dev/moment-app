
import Foundation
import EventKit
import EventKitUI
import Combine

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    let eventStore = EKEventStore()
    
    @Published var upcomingEvents: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var isAuthorized = false
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Permissions
    
    @MainActor
    func requestAccess() async {
        do {
            if #available(iOS 17.0, *) {
                let eventsGranted = try await eventStore.requestFullAccessToEvents()
                let remindersGranted = try await eventStore.requestFullAccessToReminders()
                self.isAuthorized = eventsGranted && remindersGranted
            } else {
                let eventsGranted = try await eventStore.requestAccess(to: .event)
                let remindersGranted = try await eventStore.requestAccess(to: .reminder)
                self.isAuthorized = eventsGranted && remindersGranted
            }
            
            if isAuthorized {
                fetchUpcomingEvents()
                await fetchReminders()
            }
        } catch {
            print("Failed to request access: \(error)")
        }
    }
    
    @MainActor
    func checkAuthorizationStatus() async {
        let eventStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        
        let validEventStatus: Bool = (eventStatus == .authorized) || (eventStatus == .fullAccess)
        let validReminderStatus: Bool = (reminderStatus == .authorized) || (reminderStatus == .fullAccess)
        
        if validEventStatus && validReminderStatus {
            self.isAuthorized = true
            fetchUpcomingEvents()
            await fetchReminders()
        }
    }
    
    // MARK: - Events
    
    @MainActor
    func fetchUpcomingEvents() {
        let calendars = eventStore.calendars(for: .event)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        self.upcomingEvents = events.sorted { $0.startDate < $1.startDate }
    }
    
    // MARK: - Reminders
    
    @MainActor
    func fetchReminders() async {
        let predicate = eventStore.predicateForReminders(in: nil)
        
        let fetchedReminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        self.reminders = fetchedReminders.filter { !$0.isCompleted }.sorted {
            let date1 = $0.dueDateComponents?.date ?? Date.distantFuture
            let date2 = $1.dueDateComponents?.date ?? Date.distantFuture
            return date1 < date2
        }
    }
    
    func syncTodoToReminder(title: String, isCompleted: Bool, deadline: Date?, reminderIdentifier: String?) async -> String? {
        // Use a "Moment" list or default
        let defaultCalendar = eventStore.defaultCalendarForNewReminders()
        
        var reminder: EKReminder?
        
        if let id = reminderIdentifier, let existing = eventStore.calendarItem(withIdentifier: id) as? EKReminder {
            reminder = existing
        } else {
            reminder = EKReminder(eventStore: eventStore)
            reminder?.calendar = defaultCalendar
        }
        
        guard let reminderToSave = reminder else { return nil }
        
        reminderToSave.title = title
        reminderToSave.isCompleted = isCompleted
        
        if let deadlineDate = deadline {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: deadlineDate)
            reminderToSave.dueDateComponents = components
            if reminderToSave.alarms == nil || reminderToSave.alarms?.isEmpty == true {
                 reminderToSave.addAlarm(EKAlarm(absoluteDate: deadlineDate))
            } else {
                 // Update existing alarm if needed, simplified for now
                 reminderToSave.alarms = [EKAlarm(absoluteDate: deadlineDate)]
            }
        } else {
            reminderToSave.dueDateComponents = nil
            reminderToSave.alarms = []
        }
        
        do {
            try eventStore.save(reminderToSave, commit: true)
            return reminderToSave.calendarItemIdentifier
        } catch {
            print("Failed to save reminder: \(error)")
            return nil
        }
    }
    
    func deleteReminder(identifier: String) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            print("Failed to delete reminder: \(error)")
        }
    }
    
    func fetchReminderStatus(reminderIdentifier: String) -> Bool? {
         guard let reminder = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else {
             return nil
         }
         return reminder.isCompleted
    }
    
    @MainActor
    func toggleReminder(_ reminder: EKReminder) async {
        guard let actualReminder = eventStore.calendarItem(withIdentifier: reminder.calendarItemIdentifier) as? EKReminder else { return }
        
        actualReminder.isCompleted = !actualReminder.isCompleted
        
        do {
            try eventStore.save(actualReminder, commit: true)
            // Refresh list
            await fetchReminders()
        } catch {
            print("Failed to toggle reminder: \(error)")
        }
    }
}
