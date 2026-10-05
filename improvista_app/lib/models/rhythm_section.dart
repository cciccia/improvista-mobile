// lib/models/rhythm_section.dart
import 'drum_note.dart';

class RhythmSection {
  final List<int> bass;
  final List<List<DrumNote>> drums;
  final List<List<int>> piano;
  final int totalSteps;
  final bool swing; // play off-beat 8ths late (triplet feel)

  RhythmSection({
    required this.bass,
    required this.drums,
    required this.piano,
    required this.totalSteps,
    this.swing = false,
  });
}
