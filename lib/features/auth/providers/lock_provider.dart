import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/providers/app_providers.dart';

/// Whether the app is currently PIN-locked (the lock screen is shown over the
/// app while the device session stays active so sync keeps running).
/// Defaults to unlocked on a cold start; locking happens via the drawer action
/// or the idle timer. (Lock-on-cold-start can be added later if desired.)
class LockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

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
