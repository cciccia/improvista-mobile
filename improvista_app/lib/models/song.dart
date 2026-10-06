// lib/models/song.dart
import 'chord.dart';

class Song {
  final String? title;
  final String? artist;
  final String? style;
  final double tempo; // BPM
  final String timeSignature;
  final int transpose; // Semitones to transpose (negative = down)
  final List<Chord> chords;

  /// Practice sections from {section: Name}, as chord index ranges.
  final List<SongSection> sections;

  Song({
    this.title,
    this.artist,
    this.style,
    this.tempo = 120.0,
    this.timeSignature = '4/4',
    this.transpose = 0,
    required this.chords,
    this.sections = const [],
  });

  /// Just [s]'s chords, everything else unchanged.
  Song section(SongSection s) => Song(
        title: title,
        artist: artist,
        style: style,
        tempo: tempo,
        timeSignature: timeSignature,
        transpose: transpose,
        chords: chords.sublist(s.start, s.end),
      );

  Song withTranspose(int t) => Song(
        title: title,
        artist: artist,
        style: style,
        tempo: tempo,
        timeSignature: timeSignature,
        transpose: t,
        chords: chords,
        sections: sections,
      );

  /// Total length in 16th-note steps. Every track must be exactly this long.
  int get totalSteps => chords.fold(0, (sum, chord) => sum + chord.steps);

  int get beatsPerMeasure => int.tryParse(timeSignature.split('/').first) ?? 4;
  int get beatUnit => int.tryParse(timeSignature.split('/').last) ?? 4;
}

class SongSection {
  final String name;
  final int start, end; // chord indices, end exclusive

  const SongSection(this.name, this.start, this.end);
}
