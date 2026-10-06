// lib/services/audio_player.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import '../models/chord.dart' show stepsPerBeat;
import '../models/rhythm_section.dart';
import 'drum_patterns.dart' show closedHiHat, crossStick;

class AudioPlayer {
  final _midi = MidiPro();
  final _random = Random();
  int? _bassSfId;
  int? _pianoSfId;
  int? _drumsSfId;

  Timer? _playbackTimer;
  int? _currentBassNote;
  int _bassNoteAge = 0; // how many steps since the current bass note was played
  List<int> _currentPianoNotes = [];

  Future<void> initialize() async {
    const String melodicFont = 'assets/fluidr3_trio.sf2';
    // Brush kit; the only drum kit kept in the trimmed font (see CLAUDE.md > Soundfonts)
    const int drumKit = 40;
    // Android plays through FluidSynth, much quieter at its default gain of 1.0 than the iOS sampler.
    // Tuned by ear to match iOS; too high and loud passages clip.
    const double androidGain = 3.0;

    print('[AudioPlayer] Loading soundfonts...');
    try {
      if (!_midi.isInitialized) await _midi.init();
      if (Platform.isAndroid) await _midi.setMasterGain(androidGain);
      _bassSfId = await _midi.loadSoundfontAsset(assetPath: melodicFont, bank: 0, program: 32);
      _pianoSfId = await _midi.loadSoundfontAsset(assetPath: melodicFont, bank: 0, program: 0);
      _drumsSfId = await _midi.loadSoundfontAsset(assetPath: melodicFont, bank: 128, program: drumKit);
      print('[AudioPlayer] All soundfonts loaded successfully!');
    } catch (e) {
      print('[AudioPlayer] ERROR loading soundfonts: $e');
    }
  }

  void dispose() {
    stop();
  }

  void stop() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (_currentBassNote != null) {
      _midi.stopNote(sfId: _bassSfId!, key: _currentBassNote!, channel: 2);
    }
    for (final note in _currentPianoNotes) {
      _midi.stopNote(sfId: _pianoSfId!, key: note, channel: 0);
    }
    _currentBassNote = null;
    _currentPianoNotes = [];
  }

  /// Calls [onTick] with 0, 1, 2, ... at [timeOf](tick) microseconds after
  /// start, scheduled against a stopwatch so timer jitter doesn't accumulate
  /// into tempo drift. [onTick] returns false to stop.
  void _runClock(double Function(int tick) timeOf, bool Function(int tick) onTick) {
    final clock = Stopwatch()..start();
    var tick = 0;
    void fire() {
      if (!onTick(tick)) return;
      tick++;
      final due = timeOf(tick).round() - clock.elapsedMicroseconds;
      _playbackTimer = Timer(Duration(microseconds: max(0, due)), fire);
    }
    fire();
  }

  void playRhythmSection(
    RhythmSection tracks, {
    double tempo = 120.0,
    bool repeat = false,
    int countInBars = 0,
    int beatsPerBar = 4,
    required Function onFinished,
    Function(int step)? onStepChange,
    Function(int beat, int totalBeats)? onCountInBeat,
  }) {
    stop();

    if (_bassSfId == null || _pianoSfId == null || _drumsSfId == null) {
      print("[AudioPlayer] Soundfonts not fully loaded. Cannot play.");
      onFinished();
      return;
    }

    final double beatMicros = 60e6 / tempo;

    // Where each 16th of a beat lands, as a fraction of the beat. Swing pushes
    // the "&" late towards the last triplet; real players swing lighter as the
    // tempo rises, so the ratio eases from 2/3 (triplet) at 120 BPM toward
    // 0.58 at 300.
    // ponytail: linear guess at the swing curve; tune by ear, or expose a "swing" slider.
    final double swingRatio = tracks.swing ? (2 / 3 - (tempo - 120).clamp(0, 180) * 0.0005) : 0.5;
    final List<double> stepOffsets = [0, swingRatio / 2, swingRatio, (1 + swingRatio) / 2];
    double stepTime(int tick) =>
        (tick ~/ stepsPerBeat + stepOffsets[tick % stepsPerBeat]) * beatMicros;

    bool playStep(int tick) {
      var step = tick;
      if (step >= tracks.totalSteps) {
        if (!repeat || tracks.totalSteps == 0) {
          stop();
          onFinished();
          return false;
        }
        step %= tracks.totalSteps;
      }

      onStepChange?.call(step);

      final newBassNote = tracks.bass[step];
      final newPianoNotes = tracks.piano[step];
      final drumNotes = tracks.drums[step];

      // Bass: cut off after 3 16th-note ticks (~75% of a quarter note)
      if (_currentBassNote != null && (newBassNote > 0 || _bassNoteAge >= 3)) {
        _midi.stopNote(sfId: _bassSfId!, key: _currentBassNote!, channel: 2);
        _currentBassNote = null;
      }
      _bassNoteAge++;

      if (newBassNote > 0) {
        _midi.playNote(sfId: _bassSfId!, key: newBassNote, velocity: 100 + _random.nextInt(15), channel: 2);
        _currentBassNote = newBassNote;
        _bassNoteAge = 0;
      }

      // Piano: only stop previous voicing when a new voicing arrives
      if (newPianoNotes.isNotEmpty) {
        for (final note in _currentPianoNotes) {
          _midi.stopNote(sfId: _pianoSfId!, key: note, channel: 0);
        }
        final velocity = 45 + _random.nextInt(15);
        for (final note in newPianoNotes) {
          _midi.playNote(sfId: _pianoSfId!, key: note, velocity: velocity, channel: 0);
        }
        _currentPianoNotes = newPianoNotes;
      }

      for (final drumNote in drumNotes) {
        _midi.playNote(sfId: _drumsSfId!, key: drumNote.midi, velocity: drumNote.velocity, channel: 9);
      }
      return true;
    }

    void startSong() => _runClock(stepTime, playStep);

    if (countInBars <= 0) {
      startSong();
      return;
    }

    final totalClicks = countInBars * beatsPerBar;
    _runClock((beat) => beat * beatMicros, (beat) {
      if (beat >= totalClicks) {
        startSong();
        return false;
      }
      final isDownbeat = beat % beatsPerBar == 0;
      _midi.playNote(
        sfId: _drumsSfId!,
        key: isDownbeat ? crossStick : closedHiHat,
        velocity: isDownbeat ? 100 : 80,
        channel: 9,
      );
      onCountInBeat?.call(beat, totalClicks);
      return true;
    });
  }
}
