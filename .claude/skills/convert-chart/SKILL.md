---
name: convert-chart
description: Convert a chart (PDF, photo or screenshot of a big-band part, lead sheet or Real Book page) into ChordPro for the Improvista app. Use when the user gives a chart file and asks to convert, transcribe or import it, or says "make this playable" or "chordpro this".
---

# Convert a chart to Improvista ChordPro

The app only needs **chord changes, form, style and tempo**. Never transcribe the melody.

## 1. Read the chart, then decide what kind of chart it is

Look at every page of the chart (PDF or image). Then work out what you are looking at:

- **Lead sheet / Real Book page**: chords run all the way through. Convert the whole tune.
  - Name the sections after the form, e.g. `{section: AA}`, `{section: Bridge}`, `{section: Last A}`.
- **Big-band part (horn, etc.)**: chords usually appear only in the **solo sections**. The head and ensemble passages have none, so skip them.
  - Give each solo its own `{section:}`, named after rehearsal letters or bar numbers, e.g. `{section: Solo 1 (A)}` or `{section: Solo 2 (E-H)}`.
  - Mention that the piano or guitar part would carry the full changes.
- **Rhythm-section part (piano, guitar, bass)**: these carry chords throughout. Treat them like a lead sheet, and use the rehearsal letters as section names.

**Section names must be unique.** Each one becomes a button in the app.

## 2. Header

```
{title: Body and Soul}
{artist: Johnny Green}
{tempo: 60}
{style: Ballad}
```

- **title**: as printed.
- **artist**: the composer if known, otherwise whoever is credited. Leave it out if nothing is legible.
- **tempo**: the marked tempo. If none is marked, use a typical tempo for the style: Ballad ~60, Fusion Ballad ~75, Bossa ~130, Medium Swing ~140.
- **time**: `{time: 3/4}` etc. Only needed when the meter isn't 4/4.
- **style**: see the table below.
- **transpose**: only for transposing parts. See below.

**Transpose.** Write the chords **exactly as they appear on the part**. Never transpose them yourself. Instead, set `{transpose:}` from the instrument named on the part, and the app converts to concert pitch.

| Part | `{transpose:}` |
|---|---|
| Trumpet, flugelhorn, cornet, tenor sax, soprano sax, clarinet, bass clarinet | `Bb` |
| Alto sax, baritone sax | `Eb` |
| French horn | `F` |
| Piano, guitar, bass, trombone, vibes, flute, vocal, C lead sheet, bass-clef Real Book | omit it |

**Style.** Pick exactly one of the values the app knows:

| Chart says | `{style:}` |
|---|---|
| swing, medium swing, up, bebop | `Medium Swing` |
| swing ballad, or just "ballad" | `Ballad` |
| ballad with even/straight 8ths, ECM-ish | `Fusion Ballad` |
| bossa, samba, latin | `Bossa Nova` |
| rock or pop ballad | `Rock Ballad` |
| funk, fusion, 16ths groove | `Fusion` |

## 3. Bars

- Separate every bar with `|`. **Follow the chart's own line breaks**, so each line can be checked against the page.
- **Every bar needs at least one chord.** Slash marks, `%` signs, or a bar with no new symbol all mean "the chord that is still sounding", so write that chord in.
  - The parser silently drops chordless bars, and the form shrinks.
- **Slashes after a chord inside a bar** only show how long that chord lasts. For example, `Db6 / E-7 A7` means 2+1+1 beats.
- **A solo that starts mid-bar** (a pickup after rests) gets that bar's chord for the **whole** bar. There is no N.C.
- **Rests inside a solo** (multi-bar rests, backgrounds with no changes): leave them out. Mark them with a comment, e.g. `{c: D - 12 bars rest}` or `{c: bars 119-123 - 5 bars rest}`.
  - **A rest also starts a new section** when the music after it is a different solo, or another rehearsal letter you'd want to practise on its own.
  - A short break inside the same solo stays in one section.
  - When unsure, keep one section and mention it under Unsure.
- **Leave out entirely:** rubato sections, cadenzas, "open piano solo", the head of a horn part, and a `Fine` that just marks the end.
- **Durations in 4/4:**
  - 1 chord fills the bar. 2 chords get 2+2 beats. 3 chords get **2+1+1**. 4 chords get 1 each.
  - For any other split, give **every chord in that bar** an explicit length: `[C7:1] [B7:1] [Bb7:2]`, or `[Dm7:3] [G7:1]`.
  - More than 4 chords in a bar always needs explicit lengths, or the bar is dropped.
- **Other meters:** give every chord an explicit length in beats.
- Use `{c: ...}` for rehearsal letters inside a section, e.g. `{c: F}`.

## 4. Repeats: copy them as written

The parser unrolls these, so do not write the repeats out yourself:

```
|: [A] | [B] :|             repeat once (plays twice)
|: [A] :| x4                pass count: x4, 4x or (4x)
|: [A] |1 [B] :|2 [C] ||    1st ending plays on every pass but the last
:|:                         end one repeat, start the next
```

- A repeat can span several lines, but it must **start and end inside one `{section:}`**.
- `|1` and `|2` go where the barline is, in place of `|`.

The parser does **not** support **3rd endings, D.S., D.C. or Coda**. Write those sections out in playing order yourself, with a `{c:}` noting what you unrolled.

## 5. Chord spellings: copy them as printed

Copy the chart's own spellings: `AΔ7♯11`, `FΔ7+5`, `Eb-7`, `C-7b5`, `E°7`, `Bbø`, `FMaj6`, `C7(b9)`.
- `♭`/`♯` and plain `b`/`#` both work. So do `Δ` and `△`.
- **Slash chords** (`Gm11/F`, `D/F#`) are supported: the bass plays the note after the slash.

The app standardises the quality, the part after the root and before any slash, as follows, in order:

- Spaces, parentheses and commas are dropped. `6/9` becomes `69`. `♭` becomes `b` and `♯` becomes `#`.
- `Δ` (or `△`) followed by a digit becomes `maj` (so `Δ7` → `maj7`). A `Δ` on its own becomes `maj7`.
- `ø` or `ø7` becomes `m7b5`.
- A leading `°` or `o` becomes `dim`.
- A leading `-` becomes `m`.
- A leading `M`, `Maj`, `MAJ` or `ma` becomes `maj`.
- A leading `min` or `mi` becomes `m`.
- A leading `+` becomes `aug`. A `+` before a digit becomes `#` (`+5` → `#5`). A trailing `+` becomes `#5`.
- A `-` between digits becomes `b` (`7-9` → `7b9`).
- `maj`, `maj6`, `maj69` and `majadd9` lose the `maj`.

The result must be one of these qualities. This is a snapshot; the source of truth is `chordQualities` in `improvista_app/lib/utils/chord_utils.dart`, so read that file instead when it is available.

```
(major)  add9  6  69  m  madd9  m6  m69  dim  dim7  aug  sus  sus4  sus2
maj7  maj9  maj13  maj7#11  maj9#11  maj7#5  maj7b5  maj7sus4  maj7sus
m7  m9  m11  m13  m7b5  mmaj7
7  9  13  11  7sus4  7sus  9sus4  9sus  13sus4  13sus  sus7  sus9  7b9sus4  7b9sus
7b9  13b9  7#9  7b5  7#5  aug7  7#11  9#11  13#11  7b13  7alt  alt
7b9b5  7b9#5  7#9b5  7#9#5  7b9#11  7#9#11  7b9b13  7#9b13
```

Before finishing, check every **distinct** quality on the chart against that list.

If a quality isn't covered, the app falls back to its longest known start (e.g. `7b9#13` plays as `7b9`). Don't silently respell it. Instead, tell the user the closest supported quality, and offer to add the missing one to `chordQualities` in the app.

Chords inside parentheses on the chart (optional turnarounds such as `(Bb7b9)`) can be kept as a normal chord when they help the loop. Otherwise drop them.

## 6. Check the form against the chart

1. For each section, count the **written** bars, before unrolling repeats.
2. Compare that with the printed bar numbers, minus any rests you skipped. Charts number repeated bars only once.
3. On pages without bar numbers, check the form instead: AABA should come to 32 bars after unrolling, a blues to 12, and so on.

Fix any mismatch before handing the chart over.

## 7. Deliver

1. Give the ChordPro in one code block.
2. Add a short **Unsure** list: the bars where you guessed a chord, a duration, a repeat or a section split. Use the printed bar numbers, or the position in the form (e.g. "bridge bar 8") when there are none.
3. Add one line saying which sections you made and which parts you skipped (rests, head, cadenza).
4. If you can write files, offer to save it as `<title>.cho` next to the source file.

The user loads charts with **Paste ChordPro**, or with **Load from File** (`.cho`/`.txt`). Do **not** save charts into the repo. It is public, and the charts are copyrighted.

## Example

An invented tenor-sax part with two solo sections: a rest, and a repeat with endings.

```
{title: Example Tune}
{artist: A. Composer}
{tempo: 160}
{style: Medium Swing}
{transpose: Bb}
{section: Solo 1 (C)}
|: [D-7] | [G7] | [CΔ7] | [A7b9] |
| [D-7] | [G7] |1 [CΔ7] | [A7b9] :|2 [CΔ7] | [CΔ7] ||
{c: D - 8 bars rest, trumpet solo}
{section: Solo 2 (E, open)}
|: [F-7] | [B♭7sus4] :| x4
```
