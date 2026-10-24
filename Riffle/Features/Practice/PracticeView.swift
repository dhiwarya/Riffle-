import RiffleDesign
import RiffleQuiz
import RiffleStore
import RiffleTheory
import SwiftData
import SwiftUI

/// The Practice tab: "Today's set" from the mockup, plus the free practice section (D10).
struct PracticeView: View {
    let openTuner: () -> Void

    @Query(sort: \DayActivity.day) private var activity: [DayActivity]
    @Query(sort: \CustomTuning.createdAt) private var customTunings: [CustomTuning]
    @AppStorage(Pref.tuningID) private var tuningID = Pref.Default.tuningID
    @AppStorage(Pref.dailyMinutes) private var dailyMinutes = Pref.Default.dailyMinutes
    @AppStorage(Pref.a4Hz) private var a4 = Pref.Default.a4Hz
    @State private var comingSoon: ComingSoon?
    @State private var showChordQuiz = false
    @State private var showClipRecorder = false
    @State private var showEarCheck = false

    // Until the planner exists (M5), Today shows a fixed sample plan.
    private let plan = TodayPlan.sample

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header.riseIn(delay: 0.05)
                WeekDots(days: weekDots).riseIn(delay: 0.15)
                ChordOfTheDayCard(plan: plan) { showChordQuiz = true }.riseIn(delay: 0.25)
                EarCheckCard(plan: plan) { showEarCheck = true }.riseIn(delay: 0.35)
                TuneUpRow(tuning: currentTuning, action: openTuner).riseIn(delay: 0.45)
                FreePracticeSection { comingSoon = $0 }.riseIn(delay: 0.5)
                #if DEBUG
                devTools
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(DotGridBackground())
        .fullScreenCover(item: $comingSoon) { ComingSoonView(feature: $0) }
        .fullScreenCover(isPresented: $showChordQuiz) {
            ChordQuizView(settings: plan.chordSettings(), tuning: currentTuning, a4: a4)
        }
        .fullScreenCover(isPresented: $showEarCheck) {
            EarCheckView(settings: plan.earSettings, seed: TodayPlan.daySeed())
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showClipRecorder) { ClipRecorderView() }
        #endif
    }

    #if DEBUG
    /// Debug builds only: the M1 clip recorder.
    private var devTools: some View {
        Button { showClipRecorder = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform.badge.mic").font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clip recorder").riffleFont(.body, size: 16, weight: .bold)
                    Text("Dev tool · record the detection test clips").riffleFont(.body, size: 13).foregroundStyle(RiffleColor.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(RiffleColor.textDim)
            }
            .foregroundStyle(RiffleColor.text)
            .padding(14)
            .riffleCard(cornerRadius: 20, fill: RiffleColor.surface, border: RiffleColor.border)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }
    #endif

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel("\(Self.dateLabel(.now)) · \(dailyMinutes) min", weight: .regular, tracking: 0.12)
                    .foregroundStyle(RiffleColor.textMuted)
                Text("Today’s set")
                    .riffleFont(.display, size: 40, weight: .heavy, relativeTo: .largeTitle, maxScale: 1.2, tracking: -0.02)
                    .foregroundStyle(RiffleColor.text)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            StreakPill(count: streak) { comingSoon = .progress }
        }
    }

    // MARK: Data

    private var practisedDays: [Date] {
        activity.filter(\.countsTowardStreak).map(\.day)
    }

    private var streak: Int {
        Streak.current(practisedDays: practisedDays, today: .now)
    }

    private var weekDots: [DayDot] {
        Streak.lastSevenDays(practisedDays: practisedDays, today: .now).map { day in
            let state: DayDot.State = switch day.status {
            case .done: .done
            case .today: .today
            case .missed: .missed
            }
            return DayDot(label: day.label, state: state)
        }
    }

    private var currentTuning: Tuning {
        Tuning.resolve(id: tuningID, custom: customTunings)
    }

    /// "MON · 20 OCT".
    static func dateLabel(_ date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.abbreviated))
        let day = date.formatted(.dateTime.day())
        let month = date.formatted(.dateTime.month(.abbreviated))
        return "\(weekday) · \(day) \(month)".uppercased()
    }
}

/// What today's set contains. Fixed sample until the planner lands in M5.
struct TodayPlan {
    var chordCount: Int
    var newChords: Int
    var chordLevel: Int
    var earCount: Int
    var earKey: Key
    var earDifficulty: EarDifficulty

    static let sample = TodayPlan(chordCount: 3, newChords: 1, chordLevel: 1, earCount: 10, earKey: Key(.C),
                                  earDifficulty: .easy)

    var earSettings: EarSession.Settings {
        let context = KeyContext(rawValue: UserDefaults.standard.string(forKey: Pref.keyContext) ?? "") ?? .cadence
        return EarSession.Settings(level: EarLevel(rawValue: earDifficulty.rawValue) ?? .easy, key: earKey,
                                   questionCount: earCount, context: context)
    }

    /// Today's chords from the plan's level, the same all day.
    func chordSettings(_ date: Date = .now) -> ChordQuizSession.Settings {
        ChordQuizSession.Settings(items: ChordLevels.dailyItems(level: chordLevel, count: chordCount, seed: Self.daySeed(date)),
                                  level: chordLevel)
    }

    /// Same questions all day; a new set tomorrow. (M5 adds the install ID to the seed.)
    static func daySeed(_ date: Date = .now) -> UInt64 {
        UInt64(Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 1)
    }
}

#Preview {
    PracticeView(openTuner: {})
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
