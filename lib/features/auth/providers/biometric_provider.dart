import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/providers/app_providers.dart';

final biometricSupportedProvider = FutureProvider<bool>((ref) async {
  final auth = LocalAuthentication();
  return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
});

class BiometricEnabledNotifier extends Notifier<bool> {
  static const _key = 'biometric_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
    state = value;
  }
}

final biometricEnabledProvider =
    NotifierProvider<BiometricEnabledNotifier, bool>(
      BiometricEnabledNotifier.new,
    );

class PinNotifier extends Notifier<String?> {
  static const _key = 'auth_pin';

  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key);
  }

  Future<void> setPin(String pin) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, pin);
    state = pin;
  }

  Future<void> clearPin() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_key);
    state = null;
  }
}

final pinProvider = NotifierProvider<PinNotifier, String?>(PinNotifier.new);

/// Tracks whether biometric auth has been completed this session.
class BiometricCheckedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markChecked() => state = true;
  void reset() => state = false;
}

final biometricCheckedProvider =
    NotifierProvider<BiometricCheckedNotifier, bool>(
      BiometricCheckedNotifier.new,
    );
