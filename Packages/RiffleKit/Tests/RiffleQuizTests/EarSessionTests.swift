import RiffleTheory
import Testing
@testable import RiffleQuiz

struct EarSessionTests {
    private func labels(_ degrees: [ScaleDegree]) -> [String] { degrees.map(\.label) }

    /// Answers correctly (or picks `wrong` when given) until the session ends.
    private func play(_ session: EarSession, wrongOn: Set<Int> = [], wrong: (ScaleDegree) -> ScaleDegree = { $0 }) {
        while let question = session.question {
            let pick = wrongOn.contains(question.number)
                ? session.pool.first { $0 != question.degree } ?? question.degree
                : question.degree
            session.answer(pick, responseTime: 1.5)
            session.advance()
        }
    }

    @Test func easyStartsWithOneThreeFiveAndGrows() {
        let session = EarSession(settings: .init(level: .easy, key: Key(.C)), seed: 1)
        #expect(labels(session.pool) == ["1", "3", "5"])
        #expect(session.pool.map(\.note.description) == ["C", "E", "G"])
        var grown: [String] = []
        for _ in 0..<8 {
            guard let question = session.question else { break }
            session.answer(question.degree, responseTime: 1)
            if let added = session.newlyAdded { grown.append(added.label) }
            session.advance()
        }
        #expect(grown == ["4", "2", "6", "7"], "two right answers in a row add the next degree")
        #expect(session.pool.count == 7)
    }

    @Test func aMissResetsTheStaircase() {
        let session = EarSession(settings: .init(level: .easy, key: Key(.G)), seed: 2)
        let first = session.question!
        session.answer(first.degree, responseTime: 1)
        session.advance()
        let second = session.question!
        session.answer(session.pool.first { $0 != second.degree }!, responseTime: 1)
        session.advance()
        let third = session.question!
        session.answer(third.degree, responseTime: 1)
        #expect(session.pool.count == 3, "streak broken by the miss")
    }

    @Test func mediumAndHardPools() {
        let minor = EarSession(settings: .init(level: .medium, key: Key(.A, .minor)), seed: 3)
        #expect(labels(minor.pool) == ["1", "2", "♭3", "4", "5", "♭6", "♭7"])
        #expect(minor.pool.map(\.note.description) == ["A", "B", "C", "D", "E", "F", "G"])
        let hard = EarSession(settings: .init(level: .hard, key: Key(.F)), seed: 3)
        #expect(hard.pool.count == 12)
        #expect(hard.pool.map(\.note.description).contains("B♭"))
    }

    @Test func keyContextSchedule() {
        func scheduled(_ level: EarLevel, _ context: KeyContext = .cadence) -> [Int] {
            let session = EarSession(settings: .init(level: level, key: Key(.C), questionCount: 12, context: context), seed: 4)
            var numbers: [Int] = []
            while let q = session.question {
                if q.playsKeyContext { numbers.append(q.number) }
                session.answer(q.degree, responseTime: 1)
                session.advance()
            }
            return numbers
        }
        #expect(scheduled(.easy) == Array(1...12))
        #expect(scheduled(.medium) == [1, 6, 11])
        #expect(scheduled(.hard) == [1])
        #expect(scheduled(.medium, .tonic) == [1, 6, 11])
        #expect(scheduled(.easy, .none).isEmpty)
    }

    @Test func registers() {
        let easy = EarSession(settings: .init(level: .easy, key: Key(.F), questionCount: 30), seed: 5)
        var easyMidis: [Int] = []
        while let q = easy.question { easyMidis.append(q.midi); easy.answer(q.degree, responseTime: 1); easy.advance() }
        #expect(easyMidis.allSatisfy { (55...78).contains($0) })
        #expect((easyMidis.max()! - easyMidis.min()!) < 12, "one octave")

        let medium = EarSession(settings: .init(level: .medium, key: Key(.D), questionCount: 40), seed: 5)
        var mediumMidis: [Int] = []
        while let q = medium.question { mediumMidis.append(q.midi); medium.answer(q.degree, responseTime: 1); medium.advance() }
        #expect(mediumMidis.max()! - mediumMidis.min()! >= 12, "two octaves")
        #expect(mediumMidis.allSatisfy { Key(.D).scale.contains(PitchClass($0)) })
    }

    @Test func questionNotesMatchTheirDegrees() {
        let session = EarSession(settings: .init(level: .hard, key: Key(.E, .minor), questionCount: 30), seed: 6)
        while let q = session.question {
            #expect(PitchClass(q.midi) == q.degree.note.pitchClass)
            session.answer(q.degree, responseTime: 1)
            session.advance()
        }
    }

    @Test func neverTheSameDegreeTwiceInARow() {
        let session = EarSession(settings: .init(level: .medium, key: Key(.C), questionCount: 60), seed: 7)
        var previous: ScaleDegree?
        while let q = session.question {
            #expect(q.degree != previous)
            previous = q.degree
            session.answer(q.degree, responseTime: 1)
            session.advance()
        }
    }

    @Test func replaysAndGrades() {
        let session = EarSession(settings: .init(level: .medium, key: Key(.C)), seed: 8)
        #expect(session.replaysLeft == 3)
        #expect(session.useReplay())
        #expect(session.useReplay())
        let q = session.question!
        let answer = session.answer(q.degree, responseTime: 1)!
        #expect(answer.replaysUsed == 2)
        #expect(answer.grade == .good)
        #expect(!session.useReplay(), "no replays once answered")
        #expect(session.answer(q.degree, responseTime: 1) == nil, "one answer per question")
        session.advance()
        #expect(session.replaysLeft == 3)
        let fast = session.answer(session.question!.degree, responseTime: 1.2)!
        #expect(fast.grade == .easy)
        session.advance()
        let wrong = session.answer(session.pool.first { $0 != session.question!.degree }!, responseTime: 1)!
        #expect(wrong.grade == .again)
    }

    @Test func sessionEndsAndSummarises() {
        let session = EarSession(settings: .init(level: .medium, key: Key(.C), questionCount: 10), seed: 9)
        play(session, wrongOn: [2, 5, 8])
        #expect(session.isFinished)
        let summary = session.summary
        #expect(summary.total == 10)
        #expect(summary.score == 7)
        #expect(summary.perDegree.reduce(0) { $0 + $1.total } == 10)
        #expect(summary.confusions.reduce(0) { $0 + $1.count } == 3)
        #expect(!summary.practiseThese.isEmpty)
    }

    @Test func focusSessionsUseOnlyThoseDegrees() {
        let focus: [Interval] = [.majorThird, .perfectFourth]
        let session = EarSession(settings: .init(level: .medium, key: Key(.G), questionCount: 20, focus: focus), seed: 10)
        #expect(labels(session.pool) == ["3", "4"])
        while let q = session.question {
            #expect(focus.contains(q.degree.interval))
            session.answer(q.degree, responseTime: 1)
            session.advance()
        }
    }

    @Test func seededSessionsRepeat() {
        func run(_ seed: UInt64) -> [Int] {
            let session = EarSession(settings: .init(level: .hard, key: Key(.D)), seed: seed)
            var midis: [Int] = []
            while let q = session.question { midis.append(q.midi); session.answer(q.degree, responseTime: 1); session.advance() }
            return midis
        }
        #expect(run(42) == run(42))
        #expect(run(42) != run(43))
    }

    @Test func itemKeysAndNaming() {
        let degree = Key(.A, .minor).scale.degrees[2]
        #expect(EarSession.itemKey(degree: degree, mode: .minor, context: .cadence) == "degree:♭3|mode:minor|ctx:cadence")
        #expect(DegreeNaming.degrees.labels(for: degree) == ("♭3", "C"))
        #expect(DegreeNaming.noteNames.labels(for: degree) == ("C", "♭3"))
        #expect(DegreeNaming.solfege.labels(for: degree).primary == "me")
        #expect(DegreeNaming.solfege.labels(for: Key(.C).scale.degrees[4]).primary == "sol")
    }
}

struct PhraseTests {
    @Test func cadenceChordsAndTiming() {
        let phrase = Phrase.cadence(Key(.C), style: .block)
        #expect(phrase.notes.count == 16) // 4 chords × (bass + 3 tones)
        let firstChord = Set(phrase.notes.filter { $0.offset == 0 }.map { PitchClass($0.midi) })
        #expect(firstChord == Chord(.C, .major).pitchClasses)
        #expect(abs(phrase.duration - (0.62 * 3 + 1.0)) < 0.01)
        #expect(phrase.notes.allSatisfy { (45...68).contains($0.midi) })
    }

    @Test func strumAndSequencing() {
        let strum = Phrase.chord(Chord(.G, .major), style: .strum)
        #expect(Set(strum.notes.map(\.offset)).count == 4)
        let both = Phrase.note(60).then(.note(64), gap: 0.2)
        #expect(both.notes.map(\.offset) == [0, 1.8])
    }
}
