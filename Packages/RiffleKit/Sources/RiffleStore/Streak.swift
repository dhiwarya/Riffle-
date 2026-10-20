import Foundation

/// Streak and 7-day row maths. Works on day starts in the given calendar, so DST and time zones are safe.
public enum Streak {
    public enum DayStatus: Hashable, Sendable { case done, today, missed }

    public struct Day: Hashable, Sendable {
        public let date: Date
        /// One-letter weekday, e.g. "M".
        public let label: String
        public let status: DayStatus
    }

    /// Consecutive practised days ending today, or ending yesterday if today isn't done yet
    /// (the streak is still alive until the day is over).
    public static func current(practisedDays: some Sequence<Date>, today: Date, calendar: Calendar = .current) -> Int {
        let days = Set(practisedDays.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// The last seven days, oldest first, ending today.
    public static func lastSevenDays(practisedDays: some Sequence<Date>, today: Date, calendar: Calendar = .current) -> [Day] {
        let days = Set(practisedDays.map { calendar.startOfDay(for: $0) })
        let start = calendar.startOfDay(for: today)
        return (0..<7).reversed().compactMap { offset -> Day? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let weekday = calendar.component(.weekday, from: date)
            let label = calendar.veryShortStandaloneWeekdaySymbols[weekday - 1]
            let status: DayStatus = days.contains(date) ? .done : (offset == 0 ? .today : .missed)
            return Day(date: date, label: label, status: status)
        }
    }
}
