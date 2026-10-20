import Foundation
import RiffleTheory
import SwiftData

/// Version 1 of the on-device schema. Everything stays on the device; there is no sync.
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [CustomTuning.self, ItemState.self, SessionRecord.self, AttemptRecord.self, DayActivity.self]
    }

    /// A tuning the user made in the tuning editor.
    @Model
    public final class CustomTuning {
        @Attribute(.unique) public var id: String
        public var name: String
        /// Spelled pitches low → high, e.g. ["D2", "A2", "D3", "G3", "B3", "E4"].
        public var strings: [String]
        public var createdAt: Date

        public init(tuning: Tuning, createdAt: Date = .now) {
            id = tuning.id
            name = tuning.name
            strings = tuning.strings.map(\.description)
            self.createdAt = createdAt
        }

        public var tuning: Tuning? {
            let pitches = strings.compactMap(SpelledPitch.init)
            guard pitches.count == Tuning.stringCount else { return nil }
            return Tuning(id: id, name: name, strings: pitches)
        }
    }

    /// Learning state for one item (a chord voicing, an ear-check degree…), used by the scheduler.
    @Model
    public final class ItemState {
        /// e.g. "chord:Am/open", "degree:3|mode:major|ctx:cadence".
        @Attribute(.unique) public var key: String
        public var kind: String
        public var attempts: Int
        public var reps: Int
        public var lapses: Int
        public var ease: Double
        public var intervalDays: Double
        public var due: Date
        public var accuracyEWMA: Double
        public var medianMsToSuccess: Int
        public var lastSeen: Date?

        public init(key: String, kind: SessionKind, due: Date = .now) {
            self.key = key
            self.kind = kind.rawValue
            attempts = 0
            reps = 0
            lapses = 0
            ease = 2.5
            intervalDays = 0
            self.due = due
            accuracyEWMA = 0
            medianMsToSuccess = 0
            lastSeen = nil
        }
    }

    /// One quiz session (or one round of a longer ear session).
    @Model
    public final class SessionRecord {
        @Attribute(.unique) public var id: UUID
        public var date: Date
        public var kind: String
        public var isFreePractice: Bool
        public var round: Int
        public var score: Int
        public var total: Int
        public var durationSec: Int
        public var level: Int

        public init(kind: SessionKind, isFreePractice: Bool, date: Date = .now, round: Int = 1,
                    score: Int = 0, total: Int = 0, durationSec: Int = 0, level: Int = 1) {
            id = UUID()
            self.date = date
            self.kind = kind.rawValue
            self.isFreePractice = isFreePractice
            self.round = round
            self.score = score
            self.total = total
            self.durationSec = durationSec
            self.level = level
        }
    }

    /// One answer or one chord attempt inside a session.
    @Model
    public final class AttemptRecord {
        @Attribute(.unique) public var id: UUID
        public var sessionID: UUID
        public var itemKey: String
        public var date: Date
        public var grade: Int
        public var responseMs: Int
        public var usedHint: Bool
        public var replays: Int
        /// Mode-specific details as JSON: missing/extra tones, picked note, key, timbre.
        public var detailJSON: Data?

        public init(sessionID: UUID, itemKey: String, grade: Grade, responseMs: Int, usedHint: Bool = false,
                    replays: Int = 0, detailJSON: Data? = nil, date: Date = .now) {
            id = UUID()
            self.sessionID = sessionID
            self.itemKey = itemKey
            self.date = date
            self.grade = grade.rawValue
            self.responseMs = responseMs
            self.usedHint = usedHint
            self.replays = replays
            self.detailJSON = detailJSON
        }
    }

    /// What happened on one calendar day. Drives the streak and the 7-day row.
    @Model
    public final class DayActivity {
        /// Start of the day in the user's calendar.
        @Attribute(.unique) public var day: Date
        public var chordDone: Bool
        public var earDone: Bool
        public var tuned: Bool
        /// Today's generated set (chords, ear key/level/count, minutes), so relaunches show the same set.
        public var planJSON: Data?
        public var freePracticeSec: Int
        /// The daily minutes goal that applied on this day.
        public var goalMinutes: Int

        public init(day: Date, goalMinutes: Int) {
            self.day = day
            chordDone = false
            earDone = false
            tuned = false
            planJSON = nil
            freePracticeSec = 0
            self.goalMinutes = goalMinutes
        }

        public var dailySetComplete: Bool { chordDone && earDone }

        /// D6: the day counts if the daily set is done, or free practice reached the daily minutes.
        public var countsTowardStreak: Bool {
            dailySetComplete || (goalMinutes > 0 && freePracticeSec >= goalMinutes * 60)
        }
    }
}

public typealias CustomTuning = SchemaV1.CustomTuning
public typealias ItemState = SchemaV1.ItemState
public typealias SessionRecord = SchemaV1.SessionRecord
public typealias AttemptRecord = SchemaV1.AttemptRecord
public typealias DayActivity = SchemaV1.DayActivity

public enum SessionKind: String, Codable, Sendable, CaseIterable {
    case chord, ear
}

/// Automatic grade for an attempt (plan §8.1).
public enum Grade: Int, Codable, Sendable, Comparable {
    case again = 1, hard, good, easy

    public static func < (lhs: Grade, rhs: Grade) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum RiffleMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum RiffleStore {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: RiffleMigrationPlan.self, configurations: configuration)
    }
}

extension DayActivity {
    /// The record for `date`'s day, created if missing.
    public static func forDay(
        _ date: Date, goalMinutes: Int, in context: ModelContext, calendar: Calendar = .current
    ) throws -> DayActivity {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<DayActivity>(predicate: #Predicate { $0.day == day })
        if let existing = try context.fetch(descriptor).first { return existing }
        let created = DayActivity(day: day, goalMinutes: goalMinutes)
        context.insert(created)
        return created
    }
}
