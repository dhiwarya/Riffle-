import RiffleTheory
import Testing
@testable import RiffleQuiz

struct ChordLevelTests {
    @Test func everyLevelParses() {
        let expected = [1: 8, 2: 10, 3: 7, 4: 8, 5: 24, 6: 8, 7: 6]
        for level in ChordLevels.range {
            #expect(ChordLevels.items(level: level).count == expected[level], "level \(level)")
        }
    }

    @Test func itemKeysAndBassRules() throws {
        let am = try #require(ChordItem("Am"))
        #expect(am.key == "chord:Am")
        #expect(am.requiredBass == nil)
        #expect(am.subtitle == "A minor — any voicing counts")
        let c1 = try #require(ChordItem("C", inversion: 1))
        #expect(c1.key == "triad:C/1")
        #expect(c1.requiredBass == PitchClass(4))
        #expect(c1.subtitle == "C major — 1st inversion, E lowest")
        let power = try #require(ChordItem("G5", rootInBass: true))
        #expect(power.requiredBass == PitchClass(7))
    }

    @Test func dailyItemsAreStablePerSeed() {
        let a = ChordLevels.dailyItems(level: 1, count: 3, seed: 42)
        #expect(a == ChordLevels.dailyItems(level: 1, count: 3, seed: 42))
        #expect(Set(a).count == 3)
        #expect(a != ChordLevels.dailyItems(level: 1, count: 3, seed: 43) || a != ChordLevels.dailyItems(level: 1, count: 3, seed: 44))
    }
}

struct ChordQuizSessionTests {
    private func session(_ symbols: String = "Am C G") -> ChordQuizSession {
        ChordQuizSession(settings: .init(items: symbols.split(separator: " ").compactMap { ChordItem(String($0)) }, level: 1))
    }

    @Test func gradesFollowThePlan() {
        var quiz = session()
        let attempt1 = quiz.pass(elapsed: 4, strums: 1)
        #expect(attempt1?.grade == .easy)
        quiz.advance()
        let attempt2 = quiz.pass(elapsed: 14, strums: 1)
        #expect(attempt2?.grade == .good)
        quiz.advance()
        quiz.useHint()
        let attempt3 = quiz.pass(elapsed: 5, strums: 1)
        #expect(attempt3?.grade == .hard)
        let more = quiz.advance()
        #expect(!more)
        #expect(quiz.isFinished)
        #expect(quiz.score == 3)
        #expect(quiz.practiseThese.map(\.key) == ["chord:G"])
    }

    @Test func secondStrumIsGoodNotEasy() {
        var quiz = session()
        let attempt4 = quiz.pass(elapsed: 6, strums: 2)
        #expect(attempt4?.grade == .good)
    }

    @Test func revealCountsAsHelp() {
        var quiz = session()
        quiz.useReveal()
        let attempt5 = quiz.pass(elapsed: 20, strums: 3)
        #expect(attempt5?.grade == .hard)
        quiz.advance()
        #expect(!quiz.usedReveal)
    }

    @Test func timeUpAndSkipAreAgain() {
        var quiz = session()
        let timedOut = quiz.timeUp(strums: 4, missing: [PitchClass(0)], extra: [])
        #expect(timedOut?.grade == .again)
        #expect(timedOut?.elapsed == 30)
        #expect(timedOut?.missing == [PitchClass(0)])
        // Only one outcome per chord.
        let attempt6 = quiz.pass(elapsed: 31, strums: 5)
        #expect(attempt6 == nil)
        quiz.advance()
        let attempt7 = quiz.skip(elapsed: 3, strums: 0)
        #expect(attempt7?.outcome == .skipped)
        quiz.advance()
        #expect(quiz.number == 3)
        #expect(quiz.score == 0)
    }
}

struct ChordCoachTests {
    private func coach(_ symbol: String, inversion: Int? = nil, tuning: Tuning = .standard) -> ChordCoach {
        ChordCoach(item: ChordItem(symbol, inversion: inversion)!, tuning: tuning)
    }

    @Test func missingThirdPointsAtTheString() {
        // The mockup's line: open Am, C on the B string not ringing.
        #expect(coach("Am").feedback(missing: [PitchClass(0)], extra: [], bass: PitchClass(9))
                == "So close. The 3rd isn't ringing — check the B string.")
    }

    @Test func twoMissingTones() {
        #expect(coach("Am").feedback(missing: [PitchClass(0), PitchClass(4)], extra: [], bass: nil)
                == "Not quite. The 3rd and 5th aren't ringing — check the B and D strings.")
    }

    @Test func wrongThirdNamesTheOtherChord() {
        #expect(coach("Am").feedback(missing: [PitchClass(0)], extra: [PitchClass(1)], bass: nil)
                == "I hear C♯ — that makes it A major. The B string should be on the 1st fret.")
        #expect(coach("E").feedback(missing: [], extra: [PitchClass(2)], bass: nil)
                == "I hear D — that makes it E7. The D string should be on the 2nd fret.")
    }

    @Test func openStringThatShouldBeMuted() {
        // Open D strummed from the low E: an E creeps in.
        #expect(coach("D").feedback(missing: [], extra: [PitchClass(4)], bass: PitchClass(4))
                == "I hear E — mute the low E string, it isn't part of D.")
    }

    @Test func fingerOneFretOff() {
        // C with the B string fretted at 2 (C♯) instead of 1.
        #expect(coach("C").feedback(missing: [], extra: [PitchClass(1)], bass: nil)
                == "I hear C♯, which isn't in C. Check the B string — it should be on the 1st fret.")
    }

    @Test func inversionNeedsTheRightBass() {
        #expect(coach("C", inversion: 1).feedback(missing: [], extra: [], bass: PitchClass(0))
                == "Right notes, but C is the lowest. E should be the lowest note.")
    }

    @Test func hints() {
        #expect(coach("Am").hint == "A minor chord is root + ♭3 + 5. Your root is the open A string.")
        #expect(coach("C").hint == "A major chord is root + 3 + 5. Your root is the A string, 3rd fret.")
        #expect(coach("C", inversion: 1).hint.contains("Put the 3rd (E) lowest."))
        #expect(coach("Cmaj7").hint.hasPrefix("A major 7th chord is root + 3 + 7."))
    }

    @Test func alternateTuningAdviceUsesThatTuning() {
        // Drop D: the generator's D shape; whatever it picked, the advice names a real string.
        let message = coach("D", tuning: .dropD).feedback(missing: [PitchClass(6)], extra: [], bass: nil)
        #expect(message.hasPrefix("So close. The 3rd isn't ringing — check the "))
    }
}
