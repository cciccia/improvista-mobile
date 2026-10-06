// lib/services/chord_parser.dart
import '../models/chord.dart';
import '../models/song.dart';

// Maps instrument transpositions to semitones (relative to concert pitch)
// Bb instruments sound a whole step lower than written, so we transpose DOWN 2
// Eb instruments sound a minor 6th lower than written, so we transpose DOWN 9
const Map<String, int> instrumentTranspositions = {
  'Bb': -2,
  'bb': -2,
  'B♭': -2,
  'Eb': -9,
  'eb': -9,
  'E♭': -9,
  'F': -7, // French horn
  'f': -7,
  'C': 0, // Concert pitch (no transposition)
  'c': 0,
};

int parseTranspose(String value) {
  // First check if it's a known instrument key
  if (instrumentTranspositions.containsKey(value)) {
    return instrumentTranspositions[value]!;
  }
  // Otherwise try to parse as an integer (semitones)
  return int.tryParse(value) ?? 0;
}

/// Default beat splits for a 4/4 measure with N chords and no explicit durations.
const Map<int, List<double>> _defaultDurations = {
  1: [4.0],
  2: [2.0, 2.0],
  3: [2.0, 1.0, 1.0],
  4: [1.0, 1.0, 1.0, 1.0],
};

final RegExp chordRegex = RegExp(r'\[([^\]:]+)(?::\s*([\d.]+))?\]');

// Barlines: | || |: :| :|: |1 :|2, and a pass count after a closing repeat (:| x4, :| 4x, :| (4x)).
final RegExp _barline = RegExp(r'(:?)\|(:|\d+\.?)?(?:\s*\(?\s*(?:[x×]\s*(\d+)|(\d+)\s*[x×])\s*\)?)?');

class _Bar {
  final String text;
  final bool repeatStart;
  final int? ending;
  int passes = 0; // > 0 when a :| closes the repeat after this bar
  _Bar(this.text, this.repeatStart, this.ending);
}

/// Splits chord text into bars in playing order, unrolling repeats and 1st/2nd
/// endings. A :| with no |: goes back to the start (or the previous repeat).
/// ponytail: two endings only; 3rd endings and D.S./coda are not unrolled.
List<String> expandRepeats(String text) {
  final bars = <_Bar>[];
  var repeatStart = false;
  int? ending;
  var pos = 0;

  void addBar(String segment) {
    if (!chordRegex.hasMatch(segment)) return; // empty bar between || and the like
    bars.add(_Bar(segment, repeatStart, ending));
    repeatStart = false;
  }

  for (final m in _barline.allMatches(text)) {
    addBar(text.substring(pos, m.start));
    pos = m.end;
    final closes = m.group(1) == ':';
    final mark = m.group(2);
    if (closes && bars.isNotEmpty) {
      bars.last.passes = int.tryParse(m.group(3) ?? m.group(4) ?? '') ?? 2;
      ending = null;
    }
    if (mark == ':') {
      repeatStart = true;
      ending = null;
    } else if (mark != null) {
      ending = int.parse(mark.replaceAll('.', ''));
    }
  }
  addBar(text.substring(pos));

  final out = <String>[];
  var pending = <_Bar>[];
  for (final bar in bars) {
    if (bar.repeatStart) {
      out.addAll(pending.map((b) => b.text));
      pending = [];
    }
    pending.add(bar);
    if (bar.passes > 0) {
      for (var pass = 1; pass <= bar.passes; pass++) {
        final last = pass == bar.passes;
        out.addAll(pending.where((b) => !(last && b.ending == 1)).map((b) => b.text));
      }
      pending = [];
    }
  }
  out.addAll(pending.map((b) => b.text));
  return out;
}

Song parseChordPro(String content) {
  final List<Chord> chords = [];
  String? title, artist, style;
  double tempo = 120.0;
  String timeSignature = '4/4';
  int transpose = 0;

  final RegExp directiveRegex = RegExp(r'\{(\w+):\s*(.*?)\}');

  // 1. Parse metadata
  for (final match in directiveRegex.allMatches(content)) {
    final key = match.group(1)?.toLowerCase();
    final value = match.group(2)?.trim();
    if (value == null) continue;
    switch (key) {
      case 'title':
        title = value;
      case 'artist':
        artist = value;
      case 'style':
        style = value;
      case 'tempo':
        tempo = double.tryParse(value) ?? tempo;
      case 'time':
        timeSignature = value;
      case 'transpose':
        transpose = parseTranspose(value);
    }
  }

  // 2. Parse chords: [Name] or [Name:beats], per {section:} so each section
  // knows its chord range after repeats unroll.
  void addMeasures(String text) {
    for (final measure in expandRepeats(text.replaceAll(directiveRegex, ''))) {
      final matches = chordRegex.allMatches(measure).toList();
      if (matches.isEmpty) continue;

      final explicit = matches.map((m) => double.tryParse(m.group(2) ?? '')).toList();
      final List<double> durations;
      if (explicit.any((d) => d != null)) {
        // Unspecified chords split whatever is left of the bar.
        final used = explicit.whereType<double>().fold(0.0, (a, b) => a + b);
        final missing = explicit.where((d) => d == null).length;
        final share = missing == 0 ? 0.0 : ((4.0 - used) / missing).clamp(0.0, 4.0);
        durations = explicit.map((d) => d ?? share).toList();
      } else {
        final defaults = _defaultDurations[matches.length];
        if (defaults == null) continue; // >4 chords with no durations: ambiguous, skip
        durations = defaults;
      }

      for (var i = 0; i < matches.length; i++) {
        if (durations[i] <= 0) continue;
        chords.add(Chord(name: matches[i].group(1)!.trim(), duration: durations[i]));
      }
    }
  }

  final List<SongSection> sections = [];
  String? sectionName;
  var pos = 0;
  void addChunk(String text) {
    final start = chords.length;
    addMeasures(text);
    if (sectionName != null && chords.length > start) {
      sections.add(SongSection(sectionName!, start, chords.length));
    }
  }

  for (final m in RegExp(r'\{section:\s*(.*?)\}', caseSensitive: false).allMatches(content)) {
    addChunk(content.substring(pos, m.start));
    sectionName = m.group(1)!.trim();
    pos = m.end;
  }
  addChunk(content.substring(pos));

  return Song(
    title: title,
    artist: artist,
    style: style ?? 'Medium Swing',
    tempo: tempo,
    timeSignature: timeSignature,
    transpose: transpose,
    chords: chords,
    sections: sections,
  );
}
