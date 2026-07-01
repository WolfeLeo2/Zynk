import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/auth/providers/lock_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer({
    bool startedWithSession = false,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        appStartedWithSessionProvider.overrideWithValue(startedWithSession),
        sharedPreferencesProvider.overrideWithValue(sp),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('lockProvider (lock-on-cold-start + toggle)', () {
    test('fresh start with no restored session → unlocked', () async {
      final c = await makeContainer(startedWithSession: false);
      expect(c.read(lockProvider), isFalse);
    });

    test('cold start that restored a session → locked (PIN required)', () async {
      final c = await makeContainer(startedWithSession: true);
      expect(c.read(lockProvider), isTrue);
    });

    test('lock() then unlock() toggles the gate', () async {
      final c = await makeContainer(startedWithSession: false);
      final notifier = c.read(lockProvider.notifier);
      notifier.lock();
      expect(c.read(lockProvider), isTrue);
      notifier.unlock();
      expect(c.read(lockProvider), isFalse);
    });
  });

  group('autoLockSecondsProvider', () {
    test('defaults to 120s when unset', () async {
      final c = await makeContainer();
      expect(c.read(autoLockSecondsProvider), 120);
    });

    test('reads a saved valid value', () async {
      final c = await makeContainer(prefs: {'auto_lock_seconds': 300});
      expect(c.read(autoLockSecondsProvider), 300);
    });

    test('ignores an out-of-range saved value', () async {
      final c = await makeContainer(prefs: {'auto_lock_seconds': 45});
      expect(c.read(autoLockSecondsProvider), 120);
    });

    test('setSeconds persists and updates state', () async {
      final c = await makeContainer();
      await c.read(autoLockSecondsProvider.notifier).setSeconds(600);
      expect(c.read(autoLockSecondsProvider), 600);
      expect(
        c.read(sharedPreferencesProvider).getInt('auto_lock_seconds'),
        600,
      );
    });
  });
}
