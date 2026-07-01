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

  // 1. Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // 3. Initialize PowerSync
  // This sets up the local SQLite db and connects to Supabase for auth
  await openPowerSyncDatabase();

  // 4. Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Cold start with a restored session → open locked (PIN required), rather
  // than resuming as the last signed-in user.
  final restoredSession = Supabase.instance.client.auth.currentSession != null;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appStartedWithSessionProvider.overrideWithValue(restoredSession),
      ],
      child: const MyApp(),
    ),
  );
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
