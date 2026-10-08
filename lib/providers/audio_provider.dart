import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

final audioEnabledProvider = StateProvider<bool>((ref) {
  return true; // Default to enabled
});

// Provider to control audio settings
final audioSettingsProvider =
    StateNotifierProvider<AudioSettingsNotifier, AudioSettings>((ref) {
  return AudioSettingsNotifier();
});

class AudioSettings {
  final bool cartBeepEnabled;
  final bool successSoundEnabled;
  final bool errorSoundEnabled;
  final bool cashRegisterSoundEnabled;
  final bool lowStockAlertEnabled;

  const AudioSettings({
    this.cartBeepEnabled = true,
    this.successSoundEnabled = true,
    this.errorSoundEnabled = true,
    this.cashRegisterSoundEnabled = true,
    this.lowStockAlertEnabled = true,
  });

  AudioSettings copyWith({
    bool? cartBeepEnabled,
    bool? successSoundEnabled,
    bool? errorSoundEnabled,
    bool? cashRegisterSoundEnabled,
    bool? lowStockAlertEnabled,
  }) {
    return AudioSettings(
      cartBeepEnabled: cartBeepEnabled ?? this.cartBeepEnabled,
      successSoundEnabled: successSoundEnabled ?? this.successSoundEnabled,
      errorSoundEnabled: errorSoundEnabled ?? this.errorSoundEnabled,
      cashRegisterSoundEnabled:
          cashRegisterSoundEnabled ?? this.cashRegisterSoundEnabled,
      lowStockAlertEnabled: lowStockAlertEnabled ?? this.lowStockAlertEnabled,
    );
  }
}

class AudioSettingsNotifier extends StateNotifier<AudioSettings> {
  AudioSettingsNotifier() : super(const AudioSettings());

  void toggleCartBeep() {
    state = state.copyWith(cartBeepEnabled: !state.cartBeepEnabled);
  }

  void toggleSuccessSound() {
    state = state.copyWith(successSoundEnabled: !state.successSoundEnabled);
  }

  void toggleErrorSound() {
    state = state.copyWith(errorSoundEnabled: !state.errorSoundEnabled);
  }

  void toggleCashRegisterSound() {
    state = state.copyWith(
        cashRegisterSoundEnabled: !state.cashRegisterSoundEnabled);
  }

  void toggleLowStockAlert() {
    state = state.copyWith(lowStockAlertEnabled: !state.lowStockAlertEnabled);
  }

  void setAllEnabled(bool enabled) {
    state = AudioSettings(
      cartBeepEnabled: enabled,
      successSoundEnabled: enabled,
      errorSoundEnabled: enabled,
      cashRegisterSoundEnabled: enabled,
      lowStockAlertEnabled: enabled,
    );
  }
}
