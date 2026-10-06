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
  'Medium Swing': [
    [0, 0, 0, 1, 0, 0, 0, 1], // and-of-2, and-of-4
    [1, 0, 0, 1, 0, 0, 0, 0], // Charleston: 1, and-of-2
    [0, 1, 0, 0, 1, 0, 0, 0], // Reverse Charleston: and-of-1, 3
    [0, 0, 0, 1, 0, 1, 0, 0], // and-of-2, and-of-3
    [0, 0, 0, 1, 0, 0, 0, 0], // single push on and-of-2
    [1, 0, 0, 0, 0, 0, 0, 0], // single hit on 1
  ],
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

List<List<int>> generatePianoTrack(Song song) {
  final List<List<int>> pianoTrack = [];
  List<int> lastVoicing = [];
  final random = Random();
  final transpose = song.transpose;
  final patterns = _compPatterns[song.style] ?? _compPatterns['Medium Swing']!;
  final voicingSize = _voicingSize[song.style] ?? 4;
  int? lastPattern;

  for (final chord in song.chords) {
    final List<List<int>> chordSteps = List.generate(chord.steps, (_) => []);
    try {
      final midiVoicing = _findBestVoicing(parseChord(chord.name), voicingSize, transpose, lastVoicing);
      lastVoicing = midiVoicing;

      // Never the same comp twice in a row.
      var patternIndex = random.nextInt(patterns.length - (lastPattern == null ? 0 : 1));
      if (lastPattern != null && patternIndex >= lastPattern) patternIndex++;
      lastPattern = patterns.length > 1 ? patternIndex : null;
      final pattern = patterns[patternIndex];
      final int stepsPerSlot = (stepsPerBeat * 4) ~/ pattern.length; // 2 for 8ths, 1 for 16ths
      for (var i = 0; i < chordSteps.length; i++) {
        if (i % stepsPerSlot == 0 && pattern[(i ~/ stepsPerSlot) % pattern.length] == 1) {
          chordSteps[i] = midiVoicing;
        }
      }
      // Very short chords may fall between comp hits; always sound the change.
      if (chordSteps.isNotEmpty && chordSteps.every((s) => s.isEmpty) && chord.duration < 1.0) {
        chordSteps[0] = midiVoicing;
      }
    } catch (e) {
      print('[Piano] ${chord.name}: $e');
    }
    pianoTrack.addAll(chordSteps);
  }
  return pianoTrack;
}
