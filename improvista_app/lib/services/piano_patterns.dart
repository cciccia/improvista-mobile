// lib/services/piano_patterns.dart
import '../models/chord.dart';
import '../models/song.dart';
import '../utils/chord_utils.dart';
import 'dart:math';

/// Lowest note of every voicing lands in [pianoLowestNote, pianoLowestNote + 12):
/// C4 to B4. D3 (50) was too muddy against the bass; the pre-table code sat around E5.
const int pianoLowestNote = 60;

/// Notes per voicing. Ballads get fuller two-handed voicings; everything else
/// comps light with four.
const Map<String, int> _voicingSize = {'Ballad': 6, 'Fusion Ballad': 6, 'Rock Ballad': 6};

/// How far the hands move between voicings: every note's distance to the
/// nearest note of the other voicing, both ways. Works for any note counts.
int _voicingDistance(List<int> a, List<int> b) {
  int nearest(int n, List<int> other) => other.map((o) => (n - o).abs()).reduce(min);
  return a.fold(0, (s, n) => s + nearest(n, b)) + b.fold(0, (s, n) => s + nearest(n, a));
}

/// Appends each pitch class as the next note above the last one.
List<int> _stackAbove(List<int> notes, List<int> pitchClasses) {
  final out = [...notes];
  for (final pc in pitchClasses) {
    var n = out.isEmpty ? pc : out.last + 1;
    while (n % 12 != pc) n++;
    out.add(n);
  }
  return out;
}

/// A minor 9th between any two voices: the classic wrong-note crunch.
bool _hasMinorNinth(List<int> v) => [
      for (final a in v)
        for (final b in v) b - a > 12 && (b - a) % 12 == 1
    ].any((x) => x);

List<List<int>> _rotations(List<int> xs) =>
    [for (var i = 0; i < xs.length; i++) [...xs.sublist(i), ...xs.sublist(0, i)]];

/// Picks the voicing for [chord] closest to [previous]. Up to four notes are
/// stacked close; bigger voicings put the two guide tones in the left hand and
/// stack the colours above them.
List<int> _findBestVoicing(ParsedChord chord, int size, int transpose, List<int> previous) {
  final pcs = <int>[];
  for (final interval in chord.quality.voicing) {
    final pc = (chord.rootPc + transpose + interval) % 12;
    if (!pcs.contains(pc)) pcs.add(pc);
  }
  pcs.removeRange(min(size, pcs.length), pcs.length);

  // Stack in pitch order above the root so inversions stay close (no stray b9s).
  final root = (chord.rootPc + transpose) % 12;
  List<int> byPitch(List<int> xs) => [...xs]..sort((a, b) => (a - root) % 12 - (b - root) % 12);

  var candidates = pcs.length <= 4
      ? _rotations(byPitch(pcs)).map((r) => _stackAbove([], r)).toList()
      : [
          for (final left in _rotations(pcs.sublist(0, 2)))
            for (final right in _rotations(byPitch(pcs.sublist(2)))) _stackAbove(_stackAbove([], left), right)
        ];
  final clean = candidates.where((v) => !_hasMinorNinth(v)).toList();
  if (clean.isNotEmpty) candidates = clean;

  final placed = candidates.map((v) {
    final shift = pianoLowestNote + (v.first - pianoLowestNote) % 12 - v.first;
    return v.map((n) => n + shift).toList();
  }).toList();

  if (previous.isEmpty) return placed.first;
  return placed.reduce((best, v) => _voicingDistance(v, previous) < _voicingDistance(best, previous) ? v : best);
}

// Comping rhythms. 1 = play, 0 = rest. 8-step patterns are 8th notes and get
// spread onto the 16th grid; 16-step patterns are native 16ths.
const Map<String, List<List<int>>> _compPatterns = {
  'Bossa Nova': [
    [1, 0, 0, 1, 0, 0, 0, 0], // 1, and-of-2
    [1, 0, 1, 0, 0, 1, 0, 1], // 1, 2, and-of-3, and-of-4
    [0, 0, 0, 1, 1, 0, 1, 0], // and-of-2, 3, 4
    [1, 0, 0, 1, 0, 1, 0, 1], // Syncopated
  ],
  'Ballad': [
    [1, 0, 0, 0, 0, 0, 0, 0], // Sustained, once per chord
  ],
  'Rock Ballad': [
    [1, 0, 0, 0, 1, 0, 0, 0], // 1 and 3
    [1, 0, 0, 0, 0, 0, 1, 0], // 1, and re-attack on 4
  ],
  'Fusion': [
    // 1 e & a 2 e & a 3 e & a 4 e & a
    [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
    [0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0],
    [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0],
  ],
  'Fusion Ballad': [
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], // Pad
    [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], // Pad, gentle re-attack on 3
  ],
};

/// How likely a swing pianist comps on each 8th of the bar: 1 & 2 & 3 & 4 &.
/// ponytail: by-ear guess; the shape (pushes on the &s, rarely 2 and 4) matters more than the numbers.
const List<double> _swingHitOdds = [0.30, 0.25, 0.08, 0.45, 0.25, 0.20, 0.08, 0.35];

/// A fresh swing comp for [slots] 8ths starting at 8th [offset] of the bar:
/// 1-2 hits (1 under a full bar), never on neighbouring 8ths (also across the
/// join, via [afterHit]), never the same as [previous].
List<int> _swingComp(Random random, int slots, int offset, List<int>? previous, bool afterHit) {
  final maxHits = slots < 8 ? 1 : 2; // 3 per bar was too busy
  for (var attempt = 0; attempt < 200; attempt++) {
    final comp = List.filled(slots, 0);
    for (var i = 0; i < slots; i++) {
      final blocked = i == 0 ? afterHit : comp[i - 1] == 1;
      if (!blocked && random.nextDouble() < _swingHitOdds[(offset + i) % 8]) comp[i] = 1;
    }
    final hits = comp.where((h) => h == 1).length;
    if (hits >= 1 && hits <= maxHits && comp.join() != previous?.join()) return comp;
  }
  return [1, ...List.filled(slots - 1, 0)]; // tiny chords with no other option
}

List<List<int>> generatePianoTrack(Song song) {
  final random = Random();
  final patterns = _compPatterns[song.style]; // null: generated swing comping
  final voicingSize = _voicingSize[song.style] ?? 4;
  final chords = song.chords;

  // Voice-lead the whole song first, so a push can borrow the next chord's voicing.
  final voicings = <List<int>?>[];
  var lastVoicing = <int>[];
  for (final chord in chords) {
    try {
      lastVoicing = _findBestVoicing(parseChord(chord.name), voicingSize, song.transpose, lastVoicing);
      voicings.add(lastVoicing);
    } catch (e) {
      print('[Piano] ${chord.name}: $e');
      voicings.add(null);
    }
  }

  final List<List<int>> pianoTrack = [];
  int? lastPattern;
  List<int>? lastComp;
  var anticipated = false; // the previous chord's last push already played this one
  double beat = 0; // where this chord starts, in beats from the top

  for (var c = 0; c < chords.length; c++) {
    final chord = chords[c];
    final voicing = voicings[c];
    final List<List<int>> chordSteps = List.generate(chord.steps, (_) => []);
    final wasAnticipated = anticipated;
    anticipated = false;

    if (voicing != null) {
      final List<int> pattern;
      if (patterns == null) {
        // A new comp per bar the chord touches, weighted by where it sits in the bar.
        pattern = [];
        final firstSlot = (beat * 2).round();
        final slots = (chord.steps + 1) ~/ 2;
        while (pattern.length < slots) {
          final offset = (firstSlot + pattern.length) % 8;
          final afterHit = (pattern.isEmpty ? lastComp?.last : pattern.last) == 1;
          final comp = _swingComp(random, min(8 - offset, slots - pattern.length), offset, lastComp, afterHit);
          lastComp = comp;
          pattern.addAll(comp);
        }
      } else {
        // Never the same comp twice in a row.
        var patternIndex = random.nextInt(patterns.length - (lastPattern == null ? 0 : 1));
        if (lastPattern != null && patternIndex >= lastPattern) patternIndex++;
        lastPattern = patterns.length > 1 ? patternIndex : null;
        pattern = patterns[patternIndex];
      }
      final int stepsPerSlot = patterns == null ? 2 : (stepsPerBeat * 4) ~/ pattern.length; // 2 for 8ths, 1 for 16ths
      for (var i = 0; i < chordSteps.length; i++) {
        if (i % stepsPerSlot == 0 && pattern[(i ~/ stepsPerSlot) % pattern.length] == 1) {
          chordSteps[i] = voicing;
        }
      }

      // Swing: a push on the last & before a change plays the next chord early,
      // as long as this chord has already sounded.
      final last = (pattern.length - 1) * 2;
      final next = c + 1 < chords.length ? voicings[c + 1] : null;
      if (patterns == null && next != null && last > 0 && last < chordSteps.length && chordSteps[last].isNotEmpty &&
          (wasAnticipated || chordSteps.sublist(0, last).any((s) => s.isNotEmpty))) {
        chordSteps[last] = next;
        anticipated = true;
      }

      // Very short chords may fall between comp hits; always sound the change.
      if (chordSteps.isNotEmpty && chordSteps.every((s) => s.isEmpty) && chord.duration < 1.0 && !wasAnticipated) {
        chordSteps[0] = voicing;
      }
    }
    pianoTrack.addAll(chordSteps);
    beat += chord.duration;
  }
  return pianoTrack;
}
