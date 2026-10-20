import Foundation
import RiffleStore
import SwiftData

/// In-memory store with a six-day streak, for SwiftUI previews.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! RiffleStore.makeContainer(inMemory: true)
        let calendar = Calendar.current
        for offset in 1...6 {
            let date = calendar.date(byAdding: .day, value: -offset, to: .now)!
            let day = try! DayActivity.forDay(date, goalMinutes: 10, in: container.mainContext)
            day.chordDone = true
            day.earDone = true
        }
        return container
    }()
}
