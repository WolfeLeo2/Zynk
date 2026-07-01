import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/config/powersync.dart'; // PowerSync config
import 'core/providers/app_providers.dart';
import 'core/routes.dart';
import 'core/widgets/inactivity_detector.dart';
import 'features/auth/providers/lock_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Initialize Supabase (throws if SUPABASE_URL/ANON_KEY weren't compiled in)
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    // 2. Initialize PowerSync (local SQLite + backend connection)
    await openPowerSyncDatabase();

    // 3. SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Cold start with a restored session → open locked (PIN required).
    final restoredSession =
        Supabase.instance.client.auth.currentSession != null;

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appStartedWithSessionProvider.overrideWithValue(restoredSession),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, st) {
    // Never fail to a blank screen: show what went wrong + which build-time
    // config values are missing (values are never printed, only present/absent).
    debugPrint('Zynk startup failed: $e\n$st');
    runApp(_StartupErrorApp(error: e.toString()));
  }
}

/// Shown when `main()` init throws — usually missing `--dart-define` build config.
class _StartupErrorApp extends StatelessWidget {
  final String error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    // Compile-time presence check (does NOT expose the secret values).
    const hasSupabaseUrl = String.fromEnvironment('SUPABASE_URL') != '';
    const hasSupabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY') != '';
    const hasPowerSyncUrl = String.fromEnvironment('POWERSYNC_URL') != '';

    Widget row(String name, bool present) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '${present ? '✓' : '✗'}  $name',
        style: TextStyle(
          color: present ? Colors.green : Colors.red,
          fontFamily: 'monospace',
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Couldn't start Zynk",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(error),
                  const SizedBox(height: 20),
                  const Text('Build configuration:'),
                  const SizedBox(height: 6),
                  row('SUPABASE_URL', hasSupabaseUrl),
                  row('SUPABASE_ANON_KEY', hasSupabaseKey),
                  row('POWERSYNC_URL', hasPowerSyncUrl),
                  if (!hasSupabaseUrl || !hasSupabaseKey || !hasPowerSyncUrl) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'A ✗ means that value was not compiled into this build '
                      '(--dart-define). Check the CI build step / dart_defines.json.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  // PowerSync handles sync automatically, no need to manually init SyncService

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Zynk POS',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          InactivityDetector(child: child ?? const SizedBox.shrink()),
    );
  }
}
