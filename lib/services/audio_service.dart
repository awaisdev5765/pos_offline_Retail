import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;

  /// Enable or disable audio feedback
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if audio is enabled
  bool get isEnabled => _isEnabled;

  /// Play beep sound when adding item to cart
  Future<void> playCartBeep() async {
    if (!_isEnabled) return;

    try {
      // Use system click sound for beep - this is the most reliable method
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      // If system sound fails, try alternative system sounds
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (e2) {
        // If all system sounds fail, do nothing
        print('Audio error: $e2');
      }
    }
  }

  /// Play success sound
  Future<void> playSuccessSound() async {
    if (!_isEnabled) return;

    try {
      await _playSound('assets/sounds/success.wav');
    } catch (e) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (e2) {
        print('Audio error: $e2');
      }
    }
  }

  /// Play error sound
  Future<void> playErrorSound() async {
    if (!_isEnabled) return;

    try {
      await _playSound('assets/sounds/error.wav');
    } catch (e) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (e2) {
        print('Audio error: $e2');
      }
    }
  }

  /// Play cash register sound
  Future<void> playCashRegisterSound() async {
    if (!_isEnabled) return;

    try {
      await _playSound('assets/sounds/cash_register.wav');
    } catch (e) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (e2) {
        print('Audio error: $e2');
      }
    }
  }

  /// Play low stock alert sound
  Future<void> playLowStockAlert() async {
    if (!_isEnabled) return;

    try {
      await _playSound('assets/sounds/alert.wav');
    } catch (e) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (e2) {
        print('Audio error: $e2');
      }
    }
  }

  /// Play a sound file
  Future<void> _playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      throw Exception('Failed to play sound: $e');
    }
  }

  /// Dispose audio player
  void dispose() {
    _audioPlayer.dispose();
  }
}
