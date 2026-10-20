import Foundation
import RiffleTheory
import SwiftData
import Testing
@testable import RiffleStore

@MainActor
struct StoreTests {
    @Test func dayActivityIsCreatedOncePerDay() throws {
        let container = try RiffleStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let morning = Date(timeIntervalSince1970: 1_792_400_000)
        let evening = morning.addingTimeInterval(6 * 3600)

        let first = try DayActivity.forDay(morning, goalMinutes: 10, in: context)
        first.chordDone = true
        let again = try DayActivity.forDay(evening, goalMinutes: 10, in: context)
        #expect(again.chordDone)
        #expect(try context.fetchCount(FetchDescriptor<DayActivity>()) == 1)
    }

    @Test func streakRuleD6() {
        let day = DayActivity(day: .now, goalMinutes: 10)
        #expect(!day.countsTowardStreak)
        day.chordDone = true
        #expect(!day.countsTowardStreak)
        day.earDone = true
        #expect(day.countsTowardStreak)

        let free = DayActivity(day: .now, goalMinutes: 10)
        free.freePracticeSec = 599
        #expect(!free.countsTowardStreak)
        free.freePracticeSec = 600
        #expect(free.countsTowardStreak)
    }

    @Test func customTuningRoundTrips() throws {
        let container = try RiffleStore.makeContainer(inMemory: true)
        let tuning = Tuning.custom(name: "Low B", strings: Tuning.halfStepDown.strings)
        container.mainContext.insert(CustomTuning(tuning: tuning))
        let stored = try #require(try container.mainContext.fetch(FetchDescriptor<CustomTuning>()).first)
        #expect(stored.tuning == tuning)
    }

    @Test func sessionsAndAttempts() throws {
        let container = try RiffleStore.makeContainer(inMemory: true)  // must outlive its context
        let context = container.mainContext
        let session = SessionRecord(kind: .ear, isFreePractice: false, score: 7, total: 10)
        context.insert(session)
        context.insert(AttemptRecord(sessionID: session.id, itemKey: "degree:3|mode:major|ctx:cadence", grade: .good, responseMs: 2100))
        context.insert(ItemState(key: "chord:Am/open", kind: .chord))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<AttemptRecord>()) == 1)
        #expect(try context.fetch(FetchDescriptor<ItemState>()).first?.ease == 2.5)
    }
}

struct StreakTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test func countsBackFromToday() {
        let days = [date(2026, 10, 17), date(2026, 10, 18), date(2026, 10, 19, hour: 8)]
        #expect(Streak.current(practisedDays: days, today: date(2026, 10, 19, hour: 22), calendar: calendar) == 3)
    }

    @Test func todayNotDoneYetKeepsYesterdaysStreak() {
        let days = [date(2026, 10, 17), date(2026, 10, 18)]
        #expect(Streak.current(practisedDays: days, today: date(2026, 10, 19), calendar: calendar) == 2)
    }

    @Test func gapBreaksTheStreak() {
        let days = [date(2026, 10, 15), date(2026, 10, 17)]
        #expect(Streak.current(practisedDays: days, today: date(2026, 10, 19), calendar: calendar) == 0)
    }

    @Test func survivesDaylightSavingChange() {
        // US clocks go back on 1 Nov 2026; that day is 25 hours long.
        let days = [date(2026, 10, 31, hour: 23), date(2026, 11, 1, hour: 1), date(2026, 11, 2, hour: 0)]
        #expect(Streak.current(practisedDays: days, today: date(2026, 11, 2, hour: 20), calendar: calendar) == 3)
    }

    @Test func lastSevenDaysForTheTodayRow() {
        let row = Streak.lastSevenDays(practisedDays: [date(2026, 10, 13), date(2026, 10, 18)],
                                       today: date(2026, 10, 19), calendar: calendar)
        #expect(row.map(\.label) == ["T", "W", "T", "F", "S", "S", "M"])
        #expect(row.map(\.status) == [.done, .missed, .missed, .missed, .missed, .done, .today])
    }
}
