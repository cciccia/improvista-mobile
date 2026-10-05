import 'package:tonic/tonic.dart' as tonic;

// This is our dictionary for translating common chord names.
// Maps chord qualities to names the tonic library understands.
const Map<String, String> normalizationMap = {
  // Basic triads
  'm': 'min',
  'min': 'min',
  '-': 'min',
  'M': 'maj',
  'maj': 'maj',
  'dim': 'dim',
  'o': 'dim',
  'aug': 'aug',
  '+': 'aug',

  // Seventh chords
  'm7': 'min7',
  'min7': 'min7',
  '-7': 'min7',
  'maj7': 'maj7',
  'M7': 'maj7',
  'Δ7': 'maj7',
  'Δ': 'maj7',
  '7': 'dom7',
  'dom7': 'dom7',
  'm7b5': 'ø',
  'min7b5': 'ø',
  '-7b5': 'ø',
  'ø': 'ø',
  'ø7': 'ø',
  'dim7': 'dim7',
  'o7': 'dim7',
  '°7': 'dim7',

  // Extended chords - map to base seventh chord that tonic understands
  '9': 'dom7',
  '7b9': 'dom7',
  '7#9': 'dom7',
  '7b5': 'dom7',
  '7#5': 'dom7',
  '7alt': 'dom7',
  '7b9b5': 'dom7',
  '7#9#5': 'dom7',
  '7b9#5': 'dom7',
  '7#9b5': 'dom7',
  '13': 'dom7',
  '7b13': 'dom7',
  '11': 'dom7',
  '7#11': 'dom7',
  'sus4': 'sus4',
  'sus2': 'sus2',
  '7sus4': 'dom7',
  '7sus': 'dom7',
  'sus': 'sus4',

  // Minor extended
  'm9': 'min7',
  'min9': 'min7',
  'm11': 'min7',
  'min11': 'min7',

  // Major extended
  'maj9': 'maj7',
  'M9': 'maj7',
  'maj13': 'maj7',
  'maj7#11': 'maj7',

  // Add chords - treat as base triad
  'add9': 'maj',
  'add2': 'maj',
  'madd9': 'min',

  // 6th chords
  '6': 'maj6',
  'maj6': 'maj6',
  'm6': 'min6',
  'min6': 'min6',
};

/// Returns the bass note of a slash chord ("Cmaj7/E" -> "E"), or null.
String? getSlashBassNote(String name) {
  final i = name.indexOf('/');
  return i < 0 ? null : name.substring(i + 1).trim();
}

/// Parses a bare note name ("E", "Bb") into a pitch in the same octave
/// tonic uses for chord roots, so it can stand in for a chord root.
tonic.Pitch? parseNoteName(String note) {
  try {
    return tonic.Chord.parse('${note}maj').root;
  } catch (_) {
    return null;
  }
}

String normalizeChordName(String name) {
  // Slash bass is handled separately (getSlashBassNote); tonic only sees the chord.
  final slash = name.indexOf('/');
  if (slash >= 0) name = name.substring(0, slash);

  // Regex to separate the root note (e.g., "C#", "Bb") from the quality (e.g., "m7b5")
  final rootExp = RegExp(r'^([a-gA-G][#b♭♯]*)');
  final match = rootExp.firstMatch(name);

  if (match == null) {
    // If we can't even find a root note, return the name as-is
    return name;
  }

  final String root = match.group(0)!;
  final String quality = name.substring(root.length);

  // Look up the quality in our map. If we find a match, use it.
  // Otherwise, use the original quality.
  final String normalizedQuality = normalizationMap[quality] ?? quality;

  return root + normalizedQuality;
}

tonic.Pitch getThird(tonic.Chord chord) {
  if (chord.intervals.any((i) => i.number == 3)) {
    for (final interval in chord.intervals) {
      if (interval.number == 3) return chord.root + interval;
    }
  }
  return chord.root;
}

tonic.Pitch getFifth(tonic.Chord chord) {
  if (chord.intervals.any((i) => i.number == 5)) {
    for (final interval in chord.intervals) {
      if (interval.number == 5) return chord.root + interval;
    }
  }
  return chord.root + tonic.Interval.P5;
}

tonic.Pitch getSeventh(tonic.Chord chord) {
  if (chord.intervals.any((i) => i.number == 7)) {
    for (final interval in chord.intervals) {
      if (interval.number == 7) return chord.root + interval;
    }
  }
  return chord.root;
}

tonic.Pitch getNinth(tonic.Chord chord) {
  if (chord.intervals.any((i) => i.number == 9)) {
    for (final interval in chord.intervals) {
      if (interval.number == 9) return chord.root + interval;
    }
  }
  return chord.root;
}
