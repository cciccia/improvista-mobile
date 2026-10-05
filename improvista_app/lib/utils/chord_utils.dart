// lib/utils/chord_utils.dart
//
// Chord names -> pitches. Every quality the app understands lives in [chordQualities];
// [standardizeQuality] turns the many ways charts spell a quality into one of its keys.

/// A chord quality, as semitones above the root.
class ChordQuality {
  /// Chord tones the bass walks on. [third] is the 4th/2nd for sus chords; [seventh]
  /// is null for triads.
  final int third, fifth;
  final int? seventh;

  /// Piano notes, most important first: guide tones, then colours. A style
  /// takes as many as its voicing size. Tensions are written above the octave
  /// (14 = 9, 13 = b9, 15 = #9, 17 = 11, 18 = #11, 20 = b13, 21 = 13).
  final List<int> voicing;

  const ChordQuality(this.third, this.fifth, this.seventh, this.voicing);
}

// Triads and sixths
const _major = ChordQuality(4, 7, null, [4, 9, 14, 7]); // comps as 6/9
const _minor = ChordQuality(3, 7, null, [3, 7, 14]);
const _six = ChordQuality(4, 7, 9, [4, 9, 14, 7]);
const _minorSix = ChordQuality(3, 7, 9, [3, 9, 14, 7]);
const _dim7 = ChordQuality(3, 6, 9, [3, 9, 6, 14]);
const _aug = ChordQuality(4, 8, null, [4, 8, 14]);
const _sus4 = ChordQuality(5, 7, null, [5, 7, 14]);
const _sus2 = ChordQuality(2, 7, null, [2, 7, 12]);

// Major sevenths
const _maj7 = ChordQuality(4, 7, 11, [4, 11, 14, 7, 21]);
const _maj13 = ChordQuality(4, 7, 11, [4, 11, 14, 21, 7]);
const _maj7Sharp11 = ChordQuality(4, 7, 11, [4, 11, 14, 18, 21, 7]);
const _maj7Sharp5 = ChordQuality(4, 8, 11, [4, 8, 11, 14, 18]);
const _maj7Flat5 = ChordQuality(4, 6, 11, [4, 6, 11, 14]);
const _maj7Sus4 = ChordQuality(5, 7, 11, [5, 11, 14, 7, 21]);

// Minor sevenths
const _m7 = ChordQuality(3, 7, 10, [3, 10, 14, 7, 17]);
const _m11 = ChordQuality(3, 7, 10, [3, 10, 14, 17, 7]);
const _m7Flat5 = ChordQuality(3, 6, 10, [3, 10, 6, 17]);
const _mMaj7 = ChordQuality(3, 7, 11, [3, 11, 14, 7]);

// Dominants
const _dom7 = ChordQuality(4, 7, 10, [4, 10, 14, 21, 7]);
const _sus7 = ChordQuality(5, 7, 10, [5, 10, 14, 21, 7]);
const _sus7Flat9 = ChordQuality(5, 7, 10, [5, 10, 13, 7]);
const _alt = ChordQuality(4, 8, 10, [4, 10, 15, 20, 13, 18]);

const Map<String, ChordQuality> chordQualities = {
  '': _major,
  'add9': ChordQuality(4, 7, null, [4, 7, 14]),
  '6': _six,
  '69': _six,
  'm': _minor,
  'madd9': _minor,
  'm6': _minorSix,
  'm69': _minorSix,
  'dim': _dim7,
  'dim7': _dim7,
  'aug': _aug,
  'sus': _sus4,
  'sus4': _sus4,
  'sus2': _sus2,

  'maj7': _maj7,
  'maj9': _maj7,
  'maj13': _maj13,
  'maj7#11': _maj7Sharp11,
  'maj9#11': _maj7Sharp11,
  'maj7#5': _maj7Sharp5,
  'maj7b5': _maj7Flat5,
  'maj7sus4': _maj7Sus4,
  'maj7sus': _maj7Sus4,

  'm7': _m7,
  'm9': _m7,
  'm11': _m11,
  'm13': ChordQuality(3, 7, 10, [3, 10, 14, 21, 7]),
  'm7b5': _m7Flat5,
  'mmaj7': _mMaj7,

  '7': _dom7,
  '9': _dom7,
  '13': _dom7,
  '7sus4': _sus7,
  '7sus': _sus7,
  '9sus4': _sus7,
  '9sus': _sus7,
  '13sus4': _sus7,
  '13sus': _sus7,
  '11': _sus7,
  'sus7': _sus7,
  'sus9': _sus7,
  '7b9sus4': _sus7Flat9,
  '7b9sus': _sus7Flat9,
  '7b9': ChordQuality(4, 7, 10, [4, 10, 13, 21, 7]),
  '13b9': ChordQuality(4, 7, 10, [4, 10, 13, 21, 7]),
  '7#9': ChordQuality(4, 7, 10, [4, 10, 15, 7]),
  '7b5': ChordQuality(4, 6, 10, [4, 10, 6, 14]),
  '7#5': ChordQuality(4, 8, 10, [4, 10, 8, 14]),
  'aug7': ChordQuality(4, 8, 10, [4, 10, 8, 14]),
  '7#11': ChordQuality(4, 7, 10, [4, 10, 14, 18, 21]),
  '9#11': ChordQuality(4, 7, 10, [4, 10, 14, 18, 21]),
  '13#11': ChordQuality(4, 7, 10, [4, 10, 21, 18, 14]),
  '7b13': ChordQuality(4, 7, 10, [4, 10, 20, 14]),
  '7alt': _alt,
  'alt': _alt,
  '7b9b5': ChordQuality(4, 6, 10, [4, 10, 13, 6]),
  '7b9#5': ChordQuality(4, 8, 10, [4, 10, 13, 8]),
  '7#9b5': ChordQuality(4, 6, 10, [4, 10, 15, 6]),
  '7#9#5': ChordQuality(4, 8, 10, [4, 10, 15, 8]),
  '7b9#11': ChordQuality(4, 7, 10, [4, 10, 13, 18, 21]),
  '7#9#11': ChordQuality(4, 7, 10, [4, 10, 15, 18]),
  '7b9b13': ChordQuality(4, 7, 10, [4, 10, 13, 20]),
  '7#9b13': ChordQuality(4, 7, 10, [4, 10, 15, 20]),
};

/// Rewrites the many spellings of a quality into [chordQualities] keys:
/// FΔ7+5 -> maj7#5, Maj6 -> 6, ø -> m7b5, -7 -> m7, 7(b9) -> 7b9, °7 -> dim7.
String standardizeQuality(String q) {
  q = q
      .replaceAll(RegExp(r'[\s(),]'), '')
      .replaceAll('6/9', '69')
      .replaceAll('♭', 'b')
      .replaceAll('♯', '#')
      .replaceAll(RegExp(r'[Δ△∆](?=\d)'), 'maj')
      .replaceAll(RegExp(r'[Δ△∆]'), 'maj7')
      .replaceAll(RegExp(r'[øØ]7?'), 'm7b5')
      .replaceAll(RegExp(r'^[°o]'), 'dim')
      .replaceFirst(RegExp(r'^-'), 'm')
      .replaceFirst(RegExp(r'^(MAJ|Maj|maj|Ma(?!dd)|ma(?!dd)|M)'), 'maj')
      .replaceFirst(RegExp(r'^(min|mi)'), 'm')
      .replaceFirst(RegExp(r'^\+'), 'aug')
      .replaceAll(RegExp(r'\+(?=\d)'), '#')
      .replaceAll(RegExp(r'\+$'), '#5')
      .replaceAll(RegExp(r'(?<=\d)-(?=\d)'), 'b')
      .replaceAll('dom', '')
      .replaceAll('add2', 'add9');
  // "maj" only names the 7th; on its own or before a 6/add it just means major.
  if (const {'maj', 'maj6', 'maj69', 'majadd9'}.contains(q)) return q.substring(3);
  return q;
}

const _letters = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

/// Pitch class (C = 0) of a note name like "Bb" or "F#". Null if it isn't one.
int? parseNoteName(String note) {
  final m = RegExp(r'^([A-Ga-g])([#b♯♭]*)$').firstMatch(note.trim());
  if (m == null) return null;
  final acc = m.group(2)!;
  final sharps = RegExp('[#♯]').allMatches(acc).length;
  return (_letters[m.group(1)!.toUpperCase()]! + sharps - (acc.length - sharps)) % 12;
}

class ParsedChord {
  final int rootPc;

  /// Slash note if there is one, otherwise the root.
  final int bassPc;
  final ChordQuality quality;

  /// The [chordQualities] key used; differs from the written quality when the
  /// name had to fall back ([exact] is false).
  final String qualityKey;
  final bool exact;

  const ParsedChord(this.rootPc, this.bassPc, this.quality, this.qualityKey, this.exact);
}

/// Parses "Gm11/F", "BbΔ7+5", "C7(b9)"... Unknown qualities fall back to the
/// longest known prefix (7b9#13 -> 7b9), so a chord is never silent.
/// Throws [FormatException] only when there is no recognisable root.
ParsedChord parseChord(String name) {
  final m = RegExp(r'^\s*([A-Ga-g][#b♯♭]?)(.*?)(?:/([A-Ga-g][#b♯♭]?))?\s*$').firstMatch(name);
  if (m == null) throw FormatException('No chord root in "$name"');
  final root = parseNoteName(m.group(1)!)!;
  final bass = m.group(3) == null ? root : parseNoteName(m.group(3)!)!;
  final q = standardizeQuality(m.group(2)!);

  if (chordQualities.containsKey(q)) return ParsedChord(root, bass, chordQualities[q]!, q, true);
  var fallback = '';
  for (final key in chordQualities.keys) {
    if (q.startsWith(key) && key.length > fallback.length) fallback = key;
  }
  print('[Chord] "$name": unknown quality "$q", playing as "$fallback"');
  return ParsedChord(root, bass, chordQualities[fallback]!, fallback, false);
}
