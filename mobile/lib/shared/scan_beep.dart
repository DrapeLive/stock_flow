import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

AudioPlayer? _beepPlayer;

Future<void> _playBeep() async {
  try {
    final player = _beepPlayer ??= AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.stop();
    await player.play(AssetSource('audio/scan_beep.wav'), volume: 1.0);
  } catch (_) {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // No playback available; ignore silently.
    }
  }
}

/// Plays a short beep when a QR code is successfully decoded by a scanner.
Future<void> playScanBeep() => _playBeep();

/// Plays the same confirmation tone for an action that completed successfully.
Future<void> playConfirmBeep() => _playBeep();