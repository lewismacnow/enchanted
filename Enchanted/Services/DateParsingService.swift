//
//  DateParsingService.swift
//  Re-Enchanted
//
//  Converts natural language time references into DateInterval values
//  for DejaView screen recall queries. Supports relative and named references.
//

import Foundation

struct DateParsingService {

    /// Parse a natural language time reference into a DateInterval.
    ///
    /// Supported formats:
    /// - "today", "yesterday"
    /// - "last week", "last month"
    /// - "N hours ago", "N minutes ago", "N days ago"
    /// - "last Monday", "last Tuesday", etc.
    /// - "this morning", "this afternoon"
    ///
    /// Returns nil if the text cannot be parsed.
    static func parseTimeReference(_ text: String) -> DateInterval? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let now = Date()

        // "today" - start of day to now
        if normalized == "today" {
            let startOfDay = calendar.startOfDay(for: now)
            return DateInterval(start: startOfDay, end: now)
        }

        // "yesterday" - full previous day
        if normalized == "yesterday" {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
            let startOfYesterday = calendar.startOfDay(for: yesterday)
            let endOfYesterday = calendar.startOfDay(for: now)
            return DateInterval(start: startOfYesterday, end: endOfYesterday)
        }

        // "last week" - 7 days ago to now
        if normalized == "last week" {
            guard let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else { return nil }
            return DateInterval(start: weekAgo, end: now)
        }

        // "last month" - 1 month ago to now
        if normalized == "last month" {
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return DateInterval(start: monthAgo, end: now)
        }

        // "this morning" - today 6:00 AM to 12:00 PM (or now if before noon)
        if normalized == "this morning" {
            let startOfDay = calendar.startOfDay(for: now)
            guard let morningStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: startOfDay),
                  let morningEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay) else {
                return nil
            }
            let end = min(morningEnd, now)
            return DateInterval(start: morningStart, end: end)
        }

        // "this afternoon" - today 12:00 PM to 6:00 PM (or now if before 6 PM)
        if normalized == "this afternoon" {
            let startOfDay = calendar.startOfDay(for: now)
            guard let afternoonStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfDay),
                  let afternoonEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfDay) else {
                return nil
            }
            let end = min(afternoonEnd, now)
            guard afternoonStart <= now else { return nil }
            return DateInterval(start: afternoonStart, end: end)
        }

        // "N hours ago"
        if let match = normalized.wholeMatch(of: /(\d+)\s+hours?\s+ago/) {
            guard let hours = Int(match.1),
                  let date = calendar.date(byAdding: .hour, value: -hours, to: now) else { return nil }
            return DateInterval(start: date, end: now)
        }

        // "N minutes ago"
        if let match = normalized.wholeMatch(of: /(\d+)\s+minutes?\s+ago/) {
            guard let minutes = Int(match.1),
                  let date = calendar.date(byAdding: .minute, value: -minutes, to: now) else { return nil }
            return DateInterval(start: date, end: now)
        }

        // "N days ago"
        if let match = normalized.wholeMatch(of: /(\d+)\s+days?\s+ago/) {
            guard let days = Int(match.1),
                  let date = calendar.date(byAdding: .day, value: -days, to: now) else { return nil }
            return DateInterval(start: date, end: now)
        }

        // "last Monday", "last Tuesday", etc.
        if let match = normalized.wholeMatch(of: /last\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)/) {
            let dayName = String(match.1)
            guard let targetWeekday = weekdayNumber(from: dayName) else { return nil }

            let currentWeekday = calendar.component(.weekday, from: now)
            var daysBack = currentWeekday - targetWeekday
            if daysBack <= 0 {
                daysBack += 7
            }

            guard let targetDate = calendar.date(byAdding: .day, value: -daysBack, to: now) else { return nil }
            let startOfTarget = calendar.startOfDay(for: targetDate)
            guard let endOfTarget = calendar.date(byAdding: .day, value: 1, to: startOfTarget) else { return nil }
            return DateInterval(start: startOfTarget, end: endOfTarget)
        }

        return nil
    }

    /// Convert a day name to Calendar weekday number (Sunday = 1, Monday = 2, ... Saturday = 7).
    private static func weekdayNumber(from name: String) -> Int? {
        switch name.lowercased() {
        case "sunday":    return 1
        case "monday":    return 2
        case "tuesday":   return 3
        case "wednesday": return 4
        case "thursday":  return 5
        case "friday":    return 6
        case "saturday":  return 7
        default:          return nil
        }
    }
}
