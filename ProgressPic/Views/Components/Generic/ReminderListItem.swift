//
//  ReminderListItem.swift
//  ProgressPic
//
//  Reusable reminder list item component
//  Extracted from JourneySettingsView and NewJourneySheet
//

import SwiftUI

/// Reusable view for displaying a reminder in a list
struct ReminderListItem: View {
    let hour: Int
    let minute: Int
    let daysBitmask: Int
    let notificationText: String
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatTime(hour: hour, minute: minute))
                        .foregroundColor(.white)
                        .font(.body)
                    Text(ReminderFormatter.formatDays(daysBitmask))
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text(notificationText)
                        .foregroundColor(.gray)
                        .font(.caption2)
                        .lineLimit(1)
                }
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(AppConstants.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(hour: Int, minute: Int) -> String {
        "\(String(format: "%02d", hour)):\(String(format: "%02d", minute))"
    }
}

/// Reusable "Add Reminder" button
struct AddReminderButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.gray)
                Text("Add Reminder")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(AppConstants.Layout.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}

/// Utility functions for formatting reminders
enum ReminderFormatter {
    /// Format a days bitmask into a human-readable string
    static func formatDays(_ bitmask: Int) -> String {
        var selectedDays: Set<Int> = []
        for day in 1...7 {
            if bitmask & (1 << (day - 1)) != 0 {
                selectedDays.insert(day)
            }
        }

        let sortedDays = Array(selectedDays).sorted()

        if sortedDays == [1, 2, 3, 4, 5, 6, 7] {
            return "Every Day"
        } else if sortedDays == [1, 2, 3, 4, 5] {
            return "Weekdays"
        } else if sortedDays == [6, 7] {
            return "Weekends"
        } else {
            let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let selectedDayNames = sortedDays.map { dayNames[$0 - 1] }
            return selectedDayNames.joined(separator: ", ")
        }
    }

    /// Decode a bitmask into a Set of selected days
    static func decodeDays(_ bitmask: Int) -> Set<Int> {
        var days: Set<Int> = []
        for day in 1...7 {
            if bitmask & (1 << (day - 1)) != 0 {
                days.insert(day)
            }
        }
        return days
    }

    /// Encode a Set of days into a bitmask
    static func encodeDays(_ days: Set<Int>) -> Int {
        var bitmask = 0
        for day in days {
            bitmask |= (1 << (day - 1))
        }
        return bitmask
    }
}
