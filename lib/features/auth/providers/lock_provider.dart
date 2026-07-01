import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/providers/app_providers.dart';

/// True at cold start iff a Supabase session was restored — overridden in
/// main(). Lets the app open to the PIN pad instead of resuming as the last
/// user. An interactive (password) login sets it false for that run.
final appStartedWithSessionProvider = Provider<bool>((ref) => false);

/// Whether the app is currently PIN-locked (the lock screen is shown over the
/// app while the device session stays active so sync keeps running).
/// Starts locked on a cold start that restored a session (see
/// [appStartedWithSessionProvider]); otherwise unlocked.
class LockNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(appStartedWithSessionProvider);

  void lock() => state = true;
  void unlock() => state = false;
}

final lockProvider = NotifierProvider<LockNotifier, bool>(LockNotifier.new);

/// Idle auto-lock timeout in seconds. Owner-configurable; persisted per device.
class AutoLockNotifier extends Notifier<int> {
  static const _prefsKey = 'auto_lock_seconds';

  /// Selectable durations: 1 / 2 / 5 / 10 minutes.
  static const options = <int>[60, 120, 300, 600];
  static const _default = 120;

  @override
  int build() {
    final saved = ref.read(sharedPreferencesProvider).getInt(_prefsKey);
    return (saved != null && options.contains(saved)) ? saved : _default;
  }

  Future<void> setSeconds(int seconds) async {
    await ref.read(sharedPreferencesProvider).setInt(_prefsKey, seconds);
    state = seconds;
  }
}

final autoLockSecondsProvider =
    NotifierProvider<AutoLockNotifier, int>(AutoLockNotifier.new);
