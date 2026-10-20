# Recording the M1 test clips

These recordings are how we check that Riffle hears a **real guitar through a real iPhone** correctly. The synthetic tests already pass. Real strings, a real room and a phone mic are what's left to measure.

- **116 short clips**, 5–8 seconds each, in 5 groups. The full list is in [SHOTLIST.md](SHOTLIST.md).
- **About 45–60 minutes** in total. You can stop at any time: progress is saved, and you carry on where you left off.
- You record with the **Clip recorder** built into the debug build of Riffle. It names and saves every file for you.

---

## 1. What you need

| | |
|---|---|
| **Guitar** | The one you practise on. Acoustic is ideal for this first pass. Use the same guitar for every clip. |
| **Reference tuner** | A clip-on tuner, a pedal, or a tuner app **on a different device**, ideally one that shows cents. Don't use Riffle itself. |
| **iPhone** | The one you'll use Riffle on, with the debug build installed (step 2). |
| **Quiet room** | No fan, air-con, TV or music, except for the clips that ask for background noise. |
| **Mac** | With Xcode, to install the build and receive the files. |

## 2. Install the debug build on your iPhone (once)

1. Connect the iPhone to the Mac with a cable, unlock it, and tap **Trust** if asked.
2. On the iPhone, turn on **Settings › Privacy & Security › Developer Mode**. The phone restarts.
3. Open `Riffle.xcodeproj` in Xcode.
4. Select the **Riffle** target › **Signing & Capabilities** › **Team**, and pick your Apple ID. A free "Personal Team" is fine; add your Apple ID first under **Xcode › Settings › Accounts** if needed.
   - If Xcode says the bundle identifier is unavailable, change `app.riffle.Riffle` to something unique, for example `com.yourname.riffle`.
5. Choose your iPhone as the run destination at the top of the window and press **⌘R**.
6. With a free Personal Team, the first launch is blocked. Go to **Settings › General › VPN & Device Management**, tap your developer profile, then **Trust**. Launch Riffle again.
   - Free builds expire after 7 days. If the app stops opening, run it from Xcode again.
7. In Riffle, scroll to the bottom of the **Practice** tab and open **Clip recorder** (it only appears in debug builds). Allow microphone access when asked.

## 3. Set up

- **Phone position:** lay it flat on a table or put it on a stand, **about 40 cm** from where the neck meets the body. Point the **bottom edge** (the main mic) at the guitar. Keep it in that exact spot for every clip, except the group that asks you to move it.
- **Silence the phone:** turn on Do Not Disturb and Silent mode. A notification sound ruins a clip.
- **No Bluetooth headset:** disconnect AirPods and similar. The recorder warns you if a headset mic is active.
- **Tune up:** tune the guitar with your reference tuner. The chord groups need it in tune.
- **Guitar name:** type your guitar's name in the field at the top of the recorder (for example "Yamaha F310 acoustic"). It goes into `manifest.json`.

## 4. Recording each clip

1. Open the clip and read the instruction. It gives the exact shape, using one character per string from **low E to high e**; `x` means "don't play that string".
2. Get your hands in position, then tap **Record**.
3. After the **3-2-1** count, the screen says **Play now**. Play within about a second.
4. **Let it ring.** Don't touch the strings until the progress bar finishes.
5. Tap **Play back** if you're unsure, then **Keep & next**. The next clip opens automatically.

**Retake** a clip if you bumped the phone, spoke, heard a notification, fumbled the shape, or a string buzzed when it shouldn't (only the "buzz" clips should buzz).

The **Live** panel shows what Riffle's detector currently hears: the note and cents for single strings, or which chord tones lit up and "Would pass ✓ / Wouldn't pass" for chords. **Don't play to the readout.** If you played the chord correctly and it says "Wouldn't pass", keep the clip anyway. Those clips are exactly the cases we need to find and fix.

## 5. The five groups, in order

| Group | Clips | Time | What it's for |
|---|---|---|---|
| **Chords** | 49 | ~15 min | Open chords (two takes, normal and gentle), 7ths and sus, power chords, barre chords, top-string triads, 7th chords. Checks that correct chords pass. |
| **Mistakes on purpose** | 9 | ~5 min | Dead strings, a finger on the wrong fret, extra strings, buzzing. Checks that wrong chords fail, and for the right reason. |
| **Noise and non-chords** | 5 | ~3 min | Silence, talking, one string, tapping, a muted strum. Nothing here should ever pass. |
| **Distance and background noise** | 8 | ~5 min | The phone 1 m away, a TV or music on, strumming twice, fingerpicking. |
| **Single strings (tuner)** | 45 | ~20 min | Each string at −25, −10, 0, +10 and +25 cents (set with your reference tuner), then the 5th and 12th frets, soft picks and Drop D. |

The tuner group comes last because it means re-tuning. Work string by string, from flat to sharp: −25, −10, 0, +10, +25. Get your reference tuner's needle **steady on the exact value** before you record. **Re-tune to pitch** before the fretted clips and when you finish.

## 6. Send the clips to the Mac

Either:

- **AirDrop:** in the Clip recorder, tap **Make zip of all clips** › **Share zip** › AirDrop to your Mac. Unzip it.
- **Finder:** with the iPhone connected, select it in Finder's sidebar › **Files** › **Riffle**, and drag the `Corpus` folder to the Mac.

Then put **all the `.wav` files and `manifest.json`** into this folder:

```
riffle/Corpus/recordings/
```

That folder is in `.gitignore`. The clips are about 60 MB, so they stay out of git.

## 7. Run the tests

```bash
cd Packages/RiffleKit && swift test --filter CorpusTests
```

This writes **`Corpus/last-report.md`**: pass rates against the plan's targets, plus every clip the detector got wrong. Or just tell Claude the clips are in place, and it will run the tests and tune the detector.

| Target (plan §5.4 and §6.6) | |
|---|---|
| Correct chords that pass | ≥ 95 % |
| Wrong chords, confusions (A vs Am…) and noise that pass | ≤ 5 % |
| Tuner median error on in-tune strings | < 2 cents |
| Tuner clips within each clip's tolerance | all |
