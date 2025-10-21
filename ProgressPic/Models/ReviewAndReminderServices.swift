import SwiftUI
import UserNotifications
import StoreKit

// MARK: - Review Request Manager
enum ReviewRequestManager {
    private static let lastReviewRequestStreakKey = "LastReviewRequestStreak"
    private static let hasRequestedFinalReviewKey = "HasRequestedFinalReview"
    
    static func checkAndRequestReview(currentStreak: Int) {
        // Don't request if we've already done the final request
        if UserDefaults.standard.bool(forKey: hasRequestedFinalReviewKey) {
            return
        }
        
        let lastRequestedStreak = UserDefaults.standard.integer(forKey: lastReviewRequestStreakKey)
        
        // Determine if we should request a review
        var shouldRequest = false
        var isFinalRequest = false
        
        if currentStreak >= 14 && lastRequestedStreak < 14 {
            shouldRequest = true
            isFinalRequest = true
        } else if currentStreak >= 7 && lastRequestedStreak < 7 {
            shouldRequest = true
        } else if currentStreak >= 3 && lastRequestedStreak < 3 {
            shouldRequest = true
        }
        
        if shouldRequest {
            // Import StoreKit at the top of the file
            if #available(iOS 14.0, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            } else {
                SKStoreReviewController.requestReview()
            }
            
            // Update last requested streak
            UserDefaults.standard.set(currentStreak, forKey: lastReviewRequestStreakKey)
            
            // Mark if this was the final request
            if isFinalRequest {
                UserDefaults.standard.set(true, forKey: hasRequestedFinalReviewKey)
            }
        }
    }
}

// MARK: - Reminder scheduling
enum ReminderManager {
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }

    static func schedule(for journey: Journey) {
        // Request permission first, then schedule
        Task {
            // Request permission when first reminder is being scheduled
            let granted = await requestPermission()

            guard granted else {
                print("⚠️ Notification permission not granted")
                return
            }

            // Capture values to avoid Sendable issues
            let journeyId = journey.id.uuidString
            let journeyName = journey.name
            
            // Cancel all old notifications for this journey using async API
            let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let journeyNotificationIds = requests
                .filter { $0.identifier.hasPrefix(journeyId) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: journeyNotificationIds)

            // Schedule notifications for each reminder
            guard let reminders = journey.reminders else { return }

            for reminder in reminders {
                let selectedDays = reminder.selectedDays

                // Schedule a separate notification for each selected day
                for day in selectedDays {
                    var dc = DateComponents()
                    dc.hour = reminder.hour
                    dc.minute = reminder.minute
                    dc.weekday = day // 1 = Sunday, 2 = Monday, etc. in Calendar, but we use 1 = Monday

                    // Adjust weekday: our system uses 1=Mon...7=Sun, iOS uses 1=Sun...7=Sat
                    let adjustedWeekday = day == 7 ? 1 : day + 1
                    dc.weekday = adjustedWeekday

                    let content = UNMutableNotificationContent()
                    content.title = reminder.notificationText
                    content.body = "Add today's photo to \(journeyName)."
                    content.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                    let id = "\(journeyId)-\(reminder.id.uuidString)-\(day)"

                    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
    }
}

