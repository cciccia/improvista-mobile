// lib/models/drum_note.dart
class DrumNote {
  final int midi;
  final int velocity;

  DrumNote(this.midi, {this.velocity = 100});
}