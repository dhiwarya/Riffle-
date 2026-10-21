# Riffle — iOS Implementation Plan

> Native iOS guitar practice app: tuner, "Play the chord" daily quiz, "Name that note" ear check.
> Local-only: no accounts, no backend, no network calls. All data on the device.

Source mockup: `Riffle — guitar practice app.html` (5 screens at 390×844: Today, Tuner, Chord quiz (listening), Chord reveal (all voicings), Ear check).

## Decisions (19 Oct 2026)

| # | Topic | Decision |
|---|---|---|
| D1 | v1 scope | The **core three only**: Tuner, Play the chord, Name that note. Fretboard finder, Chord changes, Play what you hear and the other new modes move to the post‑launch backlog (§8.3). |
| D2 | Name that note | Switch to the **key‑context model**: short cadence establishes the key, answers as scale degrees or note names, reworked difficulty ladder (§7). |
| D3 | Daily set length | Driven by the **minutes per day** the user picks in onboarding (changeable in Settings) (§8.2). |
| D4 | Electric guitar via audio interface | **Out of scope.** v1 listens through the iPhone's built‑in mic only (§5.1). |
| D5 | Free practice | **Yes.** A free‑practice area alongside the daily set (§8.5). |
| D6 | Streak rule | A day counts if the daily set is completed **or** the user does free practice for at least their daily minutes (§8.2). |
| D7 | Devices | **iPhone only, portrait only** (as in the mockup). No iPad, no landscape (§2, §15). |
| D8 | Minutes options | 5 / 10 / 15 / 20 minutes, **default 10** (§8.2). |
| D9 | Playback sound | **Guitar (default) and piano**, selectable in Settings and in the ear check (§2, §7.5). |
| D10 | Free practice location | A section on the **Practice tab**; the tab bar stays at two tabs (§8.5). |
| D11 | Missing screens | No separate design phase. New screens are designed during the build, following the mockup's design principles (§10.1). |
| D12 | Chord detection | The simple approach (harmonic‑aware note salience, §6.2) is the v1 approach. **No Core ML model in v1.** The recorded clips are still used to set thresholds and as regression tests. |

---

## 1. What the mockup already defines

| # | Screen | Key elements | Behaviour hinted by the prototype code |
|---|--------|--------------|------------------------------------------|
| 1 | **Today** ("Today's set") | Date, streak pill (🔥 12), 7‑day dot row (done = lime, today = pulsing orange ring), **Chord of the Day** pedal card (orange), **Ear Check** pedal card (blue, "10 notes · C major · Easy"), "Tune up first" row showing current tuning, 2‑tab bar (Practice / Tuner) | Cards look like guitar pedals: press‑down animation with a hard drop shadow |
| 2 | **Tuner** | Note name (glows when in tune), "E2 · string 6 · 82.4 Hz", ±50¢ arc gauge with 21 ticks and spring needle, 3+3 headstock peg buttons, vibrating string lines, Auto/Manual toggle, footer hint | In tune = \|cents\| ≤ 3; Auto mode advances to the next untuned string after a hold; per‑string "tuned" check marks; "All six strings in tune. Go play." |
| 3 | **Chord quiz — listening** | Close, progress (1 of 3), 30 s countdown ring, chord card ("Am · A minor — any voicing counts · Minor triad · Level 2"), mic status, live waveform, **interval slots** (ROOT / ♭3RD / 5TH light up as each is heard), feedback ("So close. The 3rd isn't ringing — check the B string."), Hint, Show me how, Skip | Detection is per chord tone, not just pass/fail |
| 4 | **Chord reveal** | Chord + its tones (A R, C ♭3, E 5), tabs *Full chords · 3* / *Triads · 3*, voicing chips (Open, E shape, A shape / Root, 1st inv, 2nd inv), fretboard diagram (barres, ×/o markers, start‑fret label), Fingers/Notes toggle (interval‑coloured dots: R orange, ♭3 blue, 5 lime), per‑voicing tip, "Hear it · n of 6", "Got it — let me play it" | Strummed playback, 45 ms between strings |
| 5 | **Ear check** | 10‑question progress, score with "+1" float, Easy/Medium/Hard, scale chips (C/G/F major, A minor pent., Chromatic), big play button with ripples, "Reference: C", "3 replays left", answer pads, "Hear both" on a miss, Next / See results | Easy = C major + reference; Medium = 4 keys + tonic reference; Hard = chromatic, no reference |

**Screens the mockup does not cover yet (need design before or during build):**
onboarding + mic permission (including the minutes‑per‑day picker), mic‑denied state, tuning picker & custom tuning editor, chord quiz results, ear check results, progress/stats (behind the streak pill), settings, the "listening but nothing heard" / noisy room states, and the **free‑practice** screens (practice hub, chord library, custom ear session setup).

### Design tokens (from the mockup)

| Token | Value | Use |
|---|---|---|
| `bg` | `#14110D` + 14 px dot grid at 6 % | App background |
| `surface` / `surface2` | `#1C1813` / `#211C16` | Cards, pegs, pads |
| `border` | `#2E2720`, `#3A3229` | 1.5 px outlines |
| `text` / `textMuted` / `textDim` | `#F6EFE4` / `#B5A994` / `#6E6455` | |
| `lime` (success, in‑tune, 5th) | `#C6F15A` | |
| `orange` (chord track, root, wrong, out of tune) | `#FF7A33` (shadow `#A9471A`) | |
| `blue` (ear track, ♭3) | `#7B93FF` (shadow `#4A5BC2`) | |
| Fonts | Bricolage Grotesque 800 (display), DM Sans 400–700 (body), DM Mono 400/500 (labels, caps with 0.12–0.14em tracking) | All SIL OFL → can be bundled; ship the licence file |

Motion vocabulary: `rise` (staggered entrance), `blink`, `ringpulse`, `knob`, `flip`, `bar` (EQ bars), `strum`/`vib` (string vibration), `pop`, `glow`, `shake`, `slidein`, needle spring `cubic-bezier(.3,1.6,.45,1)`. All must stop under **Reduce Motion** (the mockup already does this).

---

## 2. Tech stack & key decisions

| Area | Decision | Why |
|---|---|---|
| Language / UI | Swift 6, SwiftUI, `@Observable` | Mockup maps cleanly to SwiftUI; Canvas for gauge & fretboard |
| Min iOS | **iOS 17** | SwiftData, Observation, `sensoryFeedback`, `phaseAnimator`/`keyframeAnimator` |
| Devices (D7) | **iPhone only, portrait only** (`TARGETED_DEVICE_FAMILY = 1`, portrait orientation only) | Matches the 390×844 mockup; layouts only need to scale between iPhone SE and Pro Max widths |
| Persistence | **SwiftData** (+ `@AppStorage` for small prefs) | Local only, no server; easy migrations |
| Audio I/O | `AVAudioEngine` (input tap + output graph) | One engine for listening and playback |
| DSP | **Accelerate / vDSP** (FFT, autocorrelation, windowing) | Fast, no third‑party deps |
| Playback sound (D9) | `AVAudioUnitSampler` with two small bundled, licence‑checked SoundFonts: **nylon/steel guitar (default) and piano**; Karplus–Strong synth fallback for guitar | Triangle waves in the prototype sound "beepy"; piano gives a cleaner pitch for ear training |
| Chord detection v1 | Harmonic‑aware chroma / note‑salience **verification** (we know the target chord) | Much easier and more robust than open chord recognition |
| Chord detection v2 (post‑launch only, D12) | Spotify **Basic Pitch** (Apache‑2.0) as Core ML, only if real users report accuracy problems | Not in v1 |
| Notifications | `UNUserNotificationCenter` local reminders only | Streak reminder without a server |
| Widget | WidgetKit (later milestone) | Streak + chord of the day on the home screen |
| Dependencies | None at launch (maybe `swift-collections`) | Keep the app small and local |
| Project layout | Xcode app + **local Swift packages** | Theory/DSP/quiz logic are testable without the UI |

---

## 3. Architecture

```
Riffle.xcodeproj
├── App/                        RiffleApp, root TabView, navigation, DI container
├── Packages/RiffleKit/         One local Swift package, one module per area:
│   ├── RiffleTheory            Pure Swift music theory (no UIKit/AVFoundation)        ✅ M0
│   ├── RiffleDesign            Tokens, bundled fonts, shared components, animations   ✅ M0
│   ├── RiffleStore             SwiftData models, preferences, streak logic            ✅ M0
│   ├── RiffleAudio             Mic capture, MPM pitch detector, chord verifier, test corpus    🟡 M1 (needs recordings)
│   └── RiffleQuiz              Ear-check sessions ✅ M3; item model, scheduler, daily planner, levels (M5)
└── Features/
    ├── Today/  Tuner/  ChordQuiz/  ChordReveal/  EarCheck/
    ├── Results/  Progress/  Settings/  Onboarding/  TuningEditor/
```

**Build notes (M0):** the Xcode project uses folder‑synced groups, so new files under `Riffle/` are picked up automatically. Package tests run with `swift test` in `Packages/RiffleKit` (macOS host). Fonts are the WOFF2 files from the mockup, loaded directly with CoreText.

**Pattern:** one `@Observable` view model per screen; services injected through `Environment` (`AudioEngineService`, `PitchDetector`, `ChordVerifier`, `ToneSynth`, `QuizEngine`, `ProgressStore`). View models are `@MainActor`; DSP runs on a dedicated serial queue/actor and publishes results via `AsyncStream`.

```swift
// RiffleAudio – the main seams
protocol MicrophoneInput { func start() async throws -> AsyncStream<AudioFrame>; func stop() }
protocol PitchDetecting   { func process(_ frame: AudioFrame) -> PitchReading? }   // f0, clarity, rms
protocol ChordVerifying   { func process(_ frame: AudioFrame, target: ChordTarget) -> ChordEvidence }
protocol TonePlaying      { func play(_ notes: [Note], style: PlayStyle) }           // .single, .strum(gapMs), .sequence(ioiMs)
```

These protocols let unit tests feed recorded WAV files instead of the live mic.

---

## 4. RiffleTheory (foundation — build first)

Types:
- `PitchClass` (0–11), `Note` (MIDI number + **spelled name**: letter + accidental), `Interval` (semitones + degree, e.g. ♭3 vs ♯2).
- `Scale` (type + root) with correct enharmonic spelling per key (F major spells **B♭**, G major **F♯**, as in the mockup). Types: major, natural minor, major/minor pentatonic, blues, modes (later), chromatic.
- `ChordQuality` (intervals + symbol + display name): maj, min, 5 (power), sus2, sus4, dim, aug, 7, maj7, m7, m7♭5, dim7, add9, 6, m6, 9 …
- `Chord(root, quality)` → tones with their roles (R, ♭3, 5 …) for the slot UI.
- `Tuning(name, strings: [Note])` with frequency `f = A4 · 2^((midi − 69)/12)`, A4 configurable (default 440).
- `Voicing(frets: [Int?], fingers: [Int?], startFret, barres, family: .full/.triad, shape: "E shape" …, tip)`.
- `VoicingGenerator`: given chord + tuning, search playable shapes (≤ 4‑fret span, ≤ 4 fingers counting barres, no muted inner strings for strummed shapes, root in bass for "root position"), rank by commonness. Used to (a) generate triad inversions on string sets and (b) adapt diagrams to **alternate tunings**.
- Curated `chords.json` for the common open/barre shapes (hand‑written tips like the mockup's) — the generator fills the gaps.

Tuning presets: Standard (E A D G B E), Drop D, Half‑step down (E♭), Full‑step down (D), Drop C, Open G, Open D, Open E, Open C, DADGAD. **Custom**: per‑string note + octave picker, limited to ±5 semitones from standard with a "high tension" warning, saved to SwiftData.

100 % unit‑test coverage target for this package (it is pure logic).

---

## 5. Feature 1 — Tuner

### 5.1 Audio session
- Category `.playAndRecord`, mode **`.measurement`** while listening (turns off AGC / voice processing that would distort pitch), options `.defaultToSpeaker`, `.allowBluetoothA2DP`.
- **Built‑in mic only (D4).** Force the built‑in mic as preferred input (`setPreferredInput`) even when headphones are connected; output can still go to headphones. Target sources: acoustic guitar, or an electric played through an amp in the room. Direct input through an audio interface (iRig etc.) is out of scope for v1: not tested, not advertised.
- If the system still routes to a Bluetooth HFP mic (AirPods, 16 kHz, heavy processing), show a "using the phone mic gives better accuracy" banner.
- Handle interruptions (calls), route changes, and `AVAudioSession.recordPermission` (onboarding asks first; denied → settings deep link screen).

### 5.2 Pitch detection pipeline
1. Input tap at hardware rate (48 kHz), buffer 1024; push into a ring buffer.
2. Analysis window **4096 samples (≈85 ms)**, hop 1024 (≈47 updates/s). Long enough for low tunings (Drop C = C2 65.4 Hz, ~5.5 periods per window).
3. Pre‑processing: DC removal, 2nd‑order high‑pass at ~50 Hz, noise gate with an adaptive noise floor (estimate during the first 500 ms; gate at floor + 12 dB).
4. **McLeod Pitch Method (MPM)** via FFT‑based NSDF (vDSP) → key maximum with k = 0.9 → parabolic interpolation. Output `f0` + `clarity`.
5. Reject readings with clarity < 0.85; ignore the first ~60 ms after an onset (plucked strings start sharp).
6. Octave‑error guard: in Manual mode fold the estimate toward the selected string's octave; in Auto mode check f0/2 and 2·f0 against the tuning.
7. Smoothing: median of last 5 → **One‑Euro filter** on cents (low jitter when steady, fast when moving). The needle itself uses a SwiftUI spring that mirrors the mockup curve.

### 5.3 Logic
- **Auto mode:** nearest string in the current tuning (by \|cents\|), with hysteresis: switch only when another string has been closest for ≥ 150 ms.
- **Manual mode:** user taps a peg; detection is constrained to that string. Tapping a peg while in Auto switches to Manual.
- **In tune:** \|cents\| ≤ 3 for ≥ 400 ms → mark string tuned, success haptic, lime glow (matches mockup). When all 6 are tuned → "All six strings in tune. Go play." and record a `tuned` event for the day (feeds the streak/Today card).
- Hint text: "Too low — tighten" / "Too high — loosen". Optional "reverse peg direction" setting is not needed (we say tighten/loosen, not left/right).
- Header shows tuning name + A4; tapping it opens the **tuning picker sheet** (presets, custom tunings, "+ New tuning", A4 stepper 430–450 Hz).
- Left‑handed setting mirrors the headstock.

### 5.4 Acceptance criteria
- Synthetic sine/sawtooth tests: error < 0.5 ¢ from 60–1,400 Hz.
- Recorded guitar corpus: error < 2 ¢ median, needle settles < 250 ms after pluck.
- CPU < 10 % on an iPhone 12‑class device; no allocation in the audio callback.

---

## 6. Feature 2 — "Play the chord" quiz

### 6.1 Flow
`Today card → Chord quiz (n chords) → [Hint | Show me how → Chord reveal] → Results`

Per chord: show chord card → start listening with 30 s ring (time allowance is personalised, see §8) → slots light up per chord tone → pass (pop + haptic + auto‑advance) / fail with targeted feedback → Retry / Hint / Show me how / Skip.

### 6.2 Detection: verify, don't recognise
We know the target chord, so the problem is "are exactly these pitch classes sounding?".

1. Window **8192 (≈170 ms)**, hop 2048, Hann; magnitude spectrum, 70 Hz – 4 kHz.
2. Spectral whitening (divide by a moving average) to reduce body/mic colouration.
3. **Note salience with harmonic summation**: salience(m) = Σₕ₌₁…₅ wʰ·\|X(h·f(m))\| for each MIDI note 40–88, then non‑max suppression of notes explained as harmonics of a stronger lower note.
   - This is the critical part: the 5th harmonic of A2 is ≈C♯5, which would make a correct **A minor** look like **A major** in a naive chroma vector. Harmonic attribution prevents that false "you're playing major" verdict.
4. Fold salience into a 12‑bin chroma; normalise by max.
5. **Onset detection** (spectral flux). Evaluate the sustain window 100–900 ms after each strum.
6. A chord tone counts as *heard* when its chroma ≥ τ (start τ = 0.25, tuned on the corpus) in ≥ 3 of 5 frames. This drives the ROOT / ♭3RD / 5TH slots exactly like the mockup.
7. **Pass** = all required tones heard AND no strong non‑chord tone (≥ 0.5) in the same strum.
8. Higher levels add a **bass check** (lowest salient note's pitch class) for inversions and "root in the bass" requirements.

### 6.3 Feedback generator
Turn evidence into coaching, using the reference voicing:
- Missing tone → which string carries it in the most likely voicing → "The 3rd isn't ringing — check the B string."
- Extra tone that changes quality (C♯ when Am expected) → "I hear C♯ — that makes it A major. The B string should be on fret 1."
- Extra muddy low note (e.g. open low E on Am) → "Mute the low E string."
- Nothing above the gate → "I can't hear you — move closer or strum harder."

### 6.4 Chord reveal screen
Fully data‑driven from `Voicing` (no hard‑coding like the prototype):
- Families: Full chords (open, E‑shape barre, A‑shape barre, …) and Triads (root, 1st, 2nd inversion on chosen string sets).
- Diagram drawn with `Canvas`: nut vs start‑fret label, barre capsule, ×/o markers, dots labelled by finger or note, interval colours (R orange, 3rd blue, 5th lime, 7th/extensions a 4th colour to add).
- "Hear it" strums the voicing (45 ms per string, down‑strum) using the sampler.
- If the user's tuning isn't standard, voicings come from `VoicingGenerator` for that tuning, with a small "for Drop D" label.

### 6.5 Level ladder (default — personalisation adjusts it)

| Level | Content | Check |
|---|---|---|
| 1 | Open majors & minors: E, A, D, G, C, Em, Am, Dm | Pitch classes |
| 2 | Dominant 7ths & sus: E7, A7, D7, G7, B7, C7, Dsus2/4, Asus2/4 | Pitch classes |
| 3 | Power chords anywhere on E/A strings | Pitch classes + bass |
| 4 | Barre E‑shape & A‑shape majors/minors (F, Bm, Bb, F♯m …) | Pitch classes |
| 5 | Triads on top 3 strings + inversions | Pitch classes + **bass note** |
| 6 | maj7, m7, m7♭5, dim7 | Pitch classes |
| 7 | Extended/colour chords (add9, 6, 9, 13 shapes) | Allow omitted 5th |

### 6.6 Acceptance criteria (on the recorded corpus)
- True‑positive rate ≥ 95 % for correctly played chords (acoustic + clean electric, quiet room).
- False‑positive rate ≤ 5 % for the classic confusions (A vs Am, E vs E7, C vs Cmaj7, chord with a muted/dead string).
- Time from strum to verdict ≤ 1 s.

---

## 7. Feature 3 — "Name that note" ear check (key‑context model, D2)

The goal changes from "name an isolated pitch" to **"hear where a note sits in a key"**: the skill guitarists use when learning songs and improvising, and one that transfers to every key.

### 7.1 Flow
- **Daily set:** the planner picks the key, level and question count (from the minutes budget, §8.2). Ear check opens with those settings shown read‑only in the header ("Key of G · Medium · 20 notes").
- **Free practice:** the user picks difficulty, key/scale, answer mode and question count (§8.5). This is where the mockup's difficulty and scale selectors live.
- Each question: tap Play → (key context, if due) → target note → answer on pads → right: "+1", pop, lime; wrong: orange shake, "It was 5 (G), you picked 6 (A)" + **Hear both** → Next.

### 7.2 Establishing the key
- **Cadence:** I–IV–V–I strummed in the key (≈0.6 s per chord), a 0.5 s gap, then the target note. Played at the start of the session and again as the level requires (see 7.4).
- The mockup's "Reference: C" button becomes **"Replay key"** (replays the cadence). A setting allows a single tonic note instead of the cadence for users who prefer it.
- Minor keys use i–iv–V–i (harmonic‑minor V) so the key is unambiguous.

### 7.3 Answer modes
- **Scale degrees (default):** pads show the degree large (1 2 3 4 5 6 7, or ♭2 ♭3 ♯4 ♭6 ♭7 in chromatic) with the note name small underneath.
- **Note names:** pads show C D E… (the mockup's current layout), spelled correctly for the key (B♭ in F, F♯ in G).
- **Solfège (optional, movable do):** do re mi…
- Toggle on the screen (`1 2 3 | C D E`) and in Settings. The skill model always records **degrees**, whatever the display, so progress carries across keys.

### 7.4 Difficulty ladder (replaces the mockup's Easy/Medium/Hard rules; the segmented control stays)

| Level | Note pool | Keys | Register | Key context |
|---|---|---|---|---|
| **Easy** | Starts with 1‑3‑5, grows to all 7 degrees through the staircase | C, G, F major | One octave (E3–E4) | Cadence before every question |
| **Medium** | All 7 diatonic degrees | Any major key + natural minor | Two octaves | Cadence every 5 questions or on demand |
| **Hard** | All 12 degrees (chromatic inside the key) | Any key | Two octaves + | Cadence once per session |
| **Challenge** (opt‑in, free practice only) | 12 note names | — | Two octaves | **None** — absolute pitch. Tracked as a personal best only; does not affect level or the daily planner |

- **Staircase inside a session:** two correct in a row adds the next degree to the pool; a miss replays the contrast pair (picked vs target) and keeps the pool.
- Pads: 7 for diatonic, 12 for chromatic (smaller pads, as in the prototype).
- Replay budget: 3 per question; replays lower the grade, not the score.

### 7.5 Audio
- **Guitar or piano** (D9): a Guitar / Piano toggle on the ear check screen and a default in Settings. The choice is saved per user and recorded in each attempt, so the progress screen can show accuracy per timbre. Chord reveal "Hear it" always uses guitar. Cadence chords and target are scheduled on the audio clock (`AVAudioTime`) so the gaps are exact.
- The mic is not used in this mode, so the session uses the default (non‑measurement) mode for full speaker volume.

### 7.6 Items & results
- Item key: `degree:<d>|mode:<major|minor>|ctx:<cadence|tonic|none>`; the key and octave are stored in the attempt details. The confusion matrix is kept on degrees (e.g. 3↔4, 6↔5).
- Results screen: score, accuracy per degree, most confused pairs, "Practise these" (starts a free‑practice session on exactly those pairs).

---

## 8. Personalisation, daily set & free practice

### 8.1 A local skill model
Everything is tracked per **item** — the smallest thing you can know:
- Chord items: `chord:Am/open`, `chord:F/barreE`, `triad:C/1stInv/GBE` …
- Ear items (by scale degree, §7.6): `degree:3|mode:major|ctx:cadence`.
- Post‑launch kinds slot in without schema changes: `fret:G@D`, `interval:m3`, `quality:minor`.

Per item we store: attempts, accuracy (EWMA), median time to success, last seen, and a **spaced‑repetition state** (FSRS‑lite or SM‑2: ease, interval, due date). Each attempt is graded automatically, no buttons:

| Chord quiz | Grade | Ear check | Grade |
|---|---|---|---|
| Clean on first strum, < 10 s | Easy | Correct, no replay, < 3 s | Easy |
| Pass within the time limit | Good | Correct with replays | Good |
| Pass after Hint or Show me how | Hard | — | — |
| Fail / Skip | Again | Wrong | Again |

### 8.2 The daily set planner ("Today's set") — minutes‑based (D3)
The user picks **5, 10, 15 or 20 minutes a day** in onboarding, **default 10** (changeable in Settings). The planner turns that budget into a set. The set is deterministic per day (seeded with date + install ID), so it doesn't change when the app relaunches. Changing the minutes regenerates today's set only if it hasn't been started.

**Budget → item counts.** Start from default time costs (chord ≈ 45 s including feedback, ear question ≈ 10 s), then split the budget by the user's goal:

| Minutes | Balanced (60 / 40) | Chord‑focused (75 / 25) | Ear‑focused (25 / 75) |
|---|---|---|---|
| 5 | 3 chords · 10 notes | 4 chords · 6 notes | 2 chords · 20 notes |
| 10 | 6 chords · 20 notes | 8 chords · 12 notes | 3 chords · 40 notes → split into 2 ear rounds |
| 15 | 9 chords · 30 notes (2 rounds) | 12 chords · 18 notes | 4 chords · 60 notes (3 rounds) |
| 20 | 12 chords · 40 notes (2 rounds) | 15 chords · 24 notes | 6 chords · 80 notes (4 rounds) |

- Bounds: 2–15 chords per day, ear rounds of 10–20 questions (longer sessions are split into rounds with a short break screen; long single rounds hurt ear accuracy).
- **Self‑calibrating:** after ~5 sessions the planner replaces the default costs with the user's own median time per chord and per question, so "10 minutes" really takes about 10 minutes.
- **Chord mix:** about 1 new chord per 3 (max 2 new per day, and only if recent accuracy ≥ 80 %), half due reviews, the rest the weakest chords.
- **Ear mix:** weighted sampling by (1 − p(correct)) plus a boost for confused degree pairs (e.g. 3↔4 mixed up 6× this week → targeted contrast questions).
- Time allowance per chord shrinks as mastery grows (30 s → 20 s → 10 s), so the countdown ring becomes a speed goal.
- **Level up/down:** promote when ≥ 80 % of the current level's items are at "Good" or better over the last 3 sessions; after 2 bad sessions, add easier review items instead of demoting (less discouraging).
- **Today screen copy is generated from the plan:** header "≈ 10 min", chord card "6 chords · 2 new · Level 4", ear card "20 notes · Key of G · Medium". The mockup's fixed "3 chords" / "10 notes" become these values.
- **Streak (D6):** a day counts when the daily set is completed **or** free practice adds up to at least the user's daily minutes (measured as active time in quiz screens, not time with the app open). The 7‑day dots on Today show both the same way; the progress calendar marks which kind of day it was.

### 8.3 Post‑launch backlog: new modes (D1 — not in v1)
v1 ships the core three. The engine is designed so these slot in later without schema changes (they are new item kinds and session kinds). Ranked by value ÷ effort:
1. **Fretboard finder** — "Play G on the D string." Mic‑verified with the tuner's monophonic detector; cheap and reliable.
2. **Chord changes** — "Switch Am ↔ C as many times as you can in 60 s." Uses the chord verifier; measures changes per minute.
3. **Play what you hear** — the app plays a note or short phrase; the user finds it on the guitar; the mic checks.
4. **Chord quality by ear** — major / minor / dom7 / maj7.
5. **Intervals by ear.**
6. Answering Name that note by **playing** the note instead of tapping.

### 8.4 Personal touches that stay local
- Onboarding (≈60 s): experience level, goal (*learn chords / train my ear / both* → sets the split in §8.2), **minutes per day** (5 / 10 / 15 / 20, preselected 10), preferred sound (guitar / piano), left‑handed?, plus an optional 3‑chord **placement check** to choose the starting level.
- Progress screen (from the streak pill): streak calendar, chord mastery grid, ear confusion heatmap (by degree), plus insights such as "You now play Am in 4 s — it took 18 s two weeks ago."
- Streak with one "freeze" per week; local reminder at a chosen time.
- Settings → **Export / import progress as JSON** (Files app) so local‑only data isn't lost when changing phones.

### 8.5 Free practice (D5)
A place to practise anything, outside the daily set.

**Where it lives (D10):** a "Free practice" section on the Practice tab, below the daily cards. The mockup's two‑tab bar (Practice / Tuner) stays. Needs a design.

| Entry | What the user picks | Reuses |
|---|---|---|
| **Chord library** | Browse chords by level/quality or search ("F♯m"); open any chord's reveal screen; "Quiz me" on one chord or a custom list | Chord reveal + chord quiz screens |
| **Chord set** | Quick presets: "my weakest 5", "all of Level n", "chords I've learned" | Chord quiz |
| **Ear session** | Difficulty, key/scale, answer mode, number of questions, Challenge (no reference) | Ear check screen with the mockup's selectors |
| **Practise these** | Launched from any results screen with the missed items | Either quiz |

Rules:
- Free practice attempts **update the skill model** (stats, spaced‑repetition state), so practising a weak chord helps tomorrow's plan.
- They **do not change today's daily set** once it is generated, and don't count toward its completion, but they **do count toward the streak** once they add up to the daily minutes (D6).
- No countdown pressure by default in free practice (timer optional).
- Sessions are recorded with `kind = free` so the progress screen can show daily‑set vs free‑practice time.

---

## 9. Data model (SwiftData)

```swift
@Model final class CustomTuning   { var id: UUID; var name: String; var midiNotes: [Int]; var createdAt: Date }
@Model final class ItemState      { @Attribute(.unique) var key: String; var kind: String
                                    var reps: Int; var lapses: Int; var ease: Double; var intervalDays: Double; var due: Date
                                    var accuracyEWMA: Double; var medianMsToSuccess: Int; var lastSeen: Date? }
@Model final class SessionRecord  { var id: UUID; var date: Date; var kind: String /* chord|ear (post‑launch: fret|changes) */
                                    var isFreePractice: Bool; var round: Int; var score: Int; var total: Int; var durationSec: Int; var level: Int }
@Model final class AttemptRecord  { var id: UUID; var sessionID: UUID; var itemKey: String; var grade: Int
                                    var responseMs: Int; var usedHint: Bool; var replays: Int
                                    var detailJSON: Data /* missing tones, picked note, extra tones, key, timbre */ }
@Model final class DayActivity    { @Attribute(.unique) var day: Date; var chordDone: Bool; var earDone: Bool; var tuned: Bool
                                    var planJSON: Data /* today's generated set: chord keys, ear key/level/count, minutes */
                                    var freePracticeSec: Int }
```
`@AppStorage`: A4, active tuning id, note naming (♯/♭/auto), playback sound (guitar/piano), ear answer mode (degrees/names/solfège), key context (cadence/tonic), **minutes per day**, goal split, left‑handed, haptics, reminder time, onboarding answers, track levels, learned per‑user time costs.
A `VersionedSchema` + migration plan from day one.

---

## 10. Design system → SwiftUI components

| Component | Notes |
|---|---|
| `DotGridBackground` | Tiled `Canvas`, 14 pt spacing |
| `PedalCard(style: .orange / .blue)` | Hard shadow offset 6 pt; pressed = translateY 5 + shadow 1 pt; `ButtonStyle` |
| `StreakPill`, `WeekDots` | Today ring uses pulsing shadow |
| `SegmentedPill` | Auto/Manual, Easy/Medium/Hard, Fingers/Notes, Full/Triads |
| `Chip` | Voicing & scale chips |
| `TunerGauge` | `Canvas` arc, 21 ticks (±50¢, every 5¢, majors every 25¢), needle angle = cents × 1.6° |
| `HeadstockPegs` + `StringLines` | Selected peg lime; vibrating selected string (`vib`) |
| `CountdownRing` | 30 s ring around the header icon |
| `LiveWaveform` | 30 bars driven by real mic band energies, not a sine |
| `IntervalSlot` | ROOT / ♭3RD / 5TH, `?` → pop note |
| `FretboardDiagram` | `Canvas`, data from `Voicing`, mirrored for left‑handed |
| `NotePad` grid | Pop / shake states |
| `ProgressDots` | 3 or 10 segments |

Fonts are registered from the bundle (`UIAppFonts`). Typography uses fixed sizes from the mockup scaled with `@ScaledMetric` and a cap so Dynamic Type works without breaking layouts. Haptics via `.sensoryFeedback` (success on in‑tune/correct, error on wrong).

### 10.1 Design principles for new screens (D11)
Every screen not in the mockup (onboarding, results, tuning picker/editor, progress, settings, free practice) follows these rules:
1. **Dark "pedalboard" stage:** `bg` with the dot grid; content on `surface` cards with 1.5 pt `border` outlines and large radii (18–28 pt cards, 20–22 pt pills).
2. **One colour per track:** orange = chords, blue = ear, lime = success / in tune / tuner. A screen takes the colour of its track; lime is reserved for "right" and "done"; orange also means "wrong" or "off". No new accent colours.
3. **Main actions are pedals:** one primary, full‑width, press‑down button per screen (hard 6 pt shadow that collapses on press). Secondary actions are outline chips or text.
4. **Type roles:** Bricolage Grotesque 800 for titles and big values (chord names, notes, scores); DM Sans for body; DM Mono in caps with wide tracking for labels and metadata ("CHORD OF THE DAY", "MON · 19 OCT").
5. **Short, friendly copy** in the second person with a coaching tone ("So close…", "Nice ear", "Go play.").
6. **Motion has a meaning:** `rise` stagger on entry, `pop` for success, `shake` for wrong, small idle loops (blink, knob, bars) only on cards that invite action. All off under Reduce Motion.
7. **Layout:** 390 pt baseline, 20 pt side margins, 44 pt minimum touch targets, safe areas respected, tab bar only on the Practice and Tuner roots (quiz flows are full screen with a close button top left).
8. **Results screens** reuse the quiz header (progress dots + score) and end with a pedal ("Done" or "Practise these").

Design pass order: each screen is designed in SwiftUI previews at the start of the milestone that needs it, checked at iPhone SE and Pro Max widths and with Dynamic Type at its largest supported size.

---

## 11. Accessibility
- VoiceOver labels already sketched in the mockup's aria attributes; tuner announces "E, 6 cents flat" at most every 1.5 s (`AccessibilityNotification.Announcement`), not every frame.
- Never rely on colour alone: in‑tune shows text + check; wrong answers show text.
- Reduce Motion disables loops (blink, knob, flip, bars, vib) and keeps state changes.
- Left‑handed mode for the headstock and diagrams.

---

## 12. Testing strategy
- **Unit:** RiffleTheory (spelling, scales, voicing generator), scheduler and planner (deterministic seeds), streak logic across time zones/DST.
- **DSP regression corpus:** record ~300 clips (each string in tune / ±10 / ±25 ¢, every level‑1–5 chord in 2–3 voicings, typical mistakes: wrong 3rd, dead string, extra bass note; acoustic + electric through an amp, all via the built‑in mic; quiet + noisy room). Tests run detectors on the WAVs and assert the accuracy targets in §5.4 and §6.6. This corpus is the most important engineering asset in the project.
- **UI:** snapshot tests of each screen state (light content in dark UI only), XCUITest for the main flows with a fake `MicrophoneInput`.
- **Devices:** iPhone SE (small screen, older CPU), a mid‑range model, and a Pro; plus an AirPods route (to verify the built‑in mic is still used). Audio interfaces are not tested (D4).
- **Instruments:** CPU, audio callback time, memory during a 10‑minute session.

---

## 13. Milestones (v1 = core three + free practice)

| # | Milestone | Scope | Est. |
|---|---|---|---|
| M0 | Foundations | Xcode project + packages, design tokens/fonts/components, RiffleTheory with tests (incl. degree spelling), SwiftData schema, tab shell | 1 wk |
| M1 | DSP core | Record the clip corpus; MPM pitch detector; chord verifier; tune thresholds on device. **Status:** detectors, synthetic tests, in-app clip recorder and corpus test runner done; waiting on the 116 recordings (`Corpus/README.md`) to tune thresholds | 1 wk |
| M2 | Tuner | Full tuner screen, presets + custom tuning editor, A4, auto/manual, built‑in‑mic routing, permission flows. **Status:** built; verified in the simulator with synthetic plucks (debug `-tunerDemo` launch argument). Real-guitar accuracy is confirmed by the tuner clips in the M1 corpus | 1.5 wk |
| M3 | Ear check | Sampler, cadence scheduling, degree/name/solfège answer modes, new difficulty ladder + staircase, rounds, results. **Status:** built with synthesised guitar (Karplus–Strong) and piano (additive) instead of SoundFonts, both tested in tune; `ToneEngine` is the seam for swapping in recorded samples later. Rounds for long ear sessions come with the M5 planner | 1.5 wk |
| M4 | Chord quiz + reveal | Live verification UI, feedback generator, voicing data + generator, reveal screen, results | 2.5 wk |
| M5 | Personalisation | Item states, grading, scheduler, **minutes‑based planner** with self‑calibrating time costs, levels, Today screen wired to real data, streaks | 1.5 wk |
| M6 | Free practice | Practice hub section, chord library + search, chord sets, custom ear session, "Practise these" from results | 1 wk |
| M7 | Polish & ship | Onboarding (minutes, goal, placement), progress screen, settings, reminders, export/import, accessibility pass, App Store assets, TestFlight | 1.5 wk |
| Post‑launch | Backlog | Fretboard finder → Chord changes → Play what you hear → chord quality / intervals by ear; widget; iCloud sync option | — |

≈ 11.5 weeks for one experienced iOS developer to TestFlight. Chord detection uses the simple approach (D12). Missing screens are designed inside the milestone that builds them, using §10.1 (D11).

---

## 14. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Polyphonic chord detection is unreliable in noisy rooms or with cheap guitars | Verification (not recognition), harmonic attribution, noise‑floor calibration, corpus‑tuned thresholds; always allow "I played it" self‑report after 2 failed tries so users are never stuck |
| Major/minor confusion from overtones | Harmonic summation + suppression (§6.2 step 3); dedicated A/Am, E/Em, D/Dm corpus cases |
| App audio leaking into the mic (Hear it → listening) | Never listen while playing; 300 ms guard after playback |
| `.measurement` mode lowers speaker volume | Switch the session mode per screen (measurement for listening, default for playback) |
| Bluetooth mic quality / latency | Detect HFP route and warn; prefer built‑in mic |
| Alternate tunings break hard‑coded diagrams | `VoicingGenerator`; quiz checks pitch classes, so any voicing still passes |
| Local‑only data loss | JSON export/import; consider opt‑in iCloud sync (CloudKit with SwiftData) later — still no accounts |

---

## 15. Info.plist / App Store notes
- `NSMicrophoneUsageDescription`: "Riffle listens to your guitar to tune it and check the chords you play. Audio never leaves your phone."
- No background audio, no tracking, no network → Privacy nutrition label: **Data Not Collected**.
- iPhone only, `UISupportedInterfaceOrientations` = portrait (D7); App Store screenshots for iPhone sizes only.
- Bundle the OFL licence for Bricolage Grotesque, DM Sans, DM Mono and the SoundFont's licence in an Acknowledgements screen.

---

## 16. Open questions
None right now. All product questions so far are settled (D1–D10). New questions from design or the DSP spike (M1) go here.
