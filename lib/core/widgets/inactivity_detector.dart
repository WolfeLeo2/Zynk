import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/features/auth/providers/lock_provider.dart';

/// Wraps the app and auto-locks after a period of no pointer interaction.
/// Only arms while a session is active and the app is unlocked. The timeout is
/// owner-configurable via [autoLockSecondsProvider].
class InactivityDetector extends ConsumerStatefulWidget {
  final Widget child;
  const InactivityDetector({super.key, required this.child});

  @override
  ConsumerState<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends ConsumerState<InactivityDetector> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    final loggedIn = ref.read(authStateProvider).value != null;
    if (!loggedIn || ref.read(lockProvider)) return; // nothing to auto-lock
    final seconds = ref.read(autoLockSecondsProvider);
    _timer = Timer(Duration(seconds: seconds), () {
      if (ref.read(authStateProvider).value != null && !ref.read(lockProvider)) {
        ref.read(lockProvider.notifier).lock();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-arm whenever lock state, auth, or the configured timeout changes.
    ref.listen(lockProvider, (_, _) => _restart());
    ref.listen(authStateProvider, (_, _) => _restart());
    ref.listen(autoLockSecondsProvider, (_, _) => _restart());

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      child: widget.child,
    );
  }
}
