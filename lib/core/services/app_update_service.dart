import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Owner/repo whose GitHub Releases carry the signed APK (public repo → no token).
const _releasesApi =
    'https://api.github.com/repos/WolfeLeo2/Zynk/releases/latest';

class AppUpdateInfo {
  final String version; // e.g. "1.2.0"
  final String apkUrl;
  final String? notes;
  const AppUpdateInfo({
    required this.version,
    required this.apkUrl,
    this.notes,
  });
}

/// Checks the latest GitHub Release for a newer Android build. Returns null when
/// up to date, on non-Android/web, or if the check fails (updates are best-effort
/// and must never block app use).
Future<AppUpdateInfo?> checkForAppUpdate({http.Client? client}) async {
  // ota_update installs an Android APK; nothing to do elsewhere (web auto-updates
  // on deploy, iOS updates via the App Store).
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

  final c = client ?? http.Client();
  try {
    final res = await c.get(
      Uri.parse(_releasesApi),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?) ?? '';
    final assets = (json['assets'] as List?) ?? const [];

    String? apkUrl;
    for (final a in assets) {
      final name = (a as Map)['name'] as String?;
      if (name != null && name.toLowerCase().endsWith('.apk')) {
        apkUrl = a['browser_download_url'] as String?;
        break;
      }
    }
    if (apkUrl == null) return null;

    final current = (await PackageInfo.fromPlatform()).version;
    if (!isNewerVersion(tag, current)) return null;

    return AppUpdateInfo(
      version: _clean(tag),
      apkUrl: apkUrl,
      notes: json['body'] as String?,
    );
  } catch (_) {
    return null; // best-effort
  } finally {
    if (client == null) c.close();
  }
}

/// Streams download progress and triggers the Android installer for [apkUrl].
Stream<OtaEvent> startAppUpdate(String apkUrl) {
  return OtaUpdate().execute(apkUrl, destinationFilename: 'zynk-update.apk');
}

/// Strip a leading `v` and any build metadata (`1.2.0+9` → `1.2.0`).
String _clean(String v) =>
    v.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first.split('-').first;

/// True if [tag] is a strictly higher semver than [current] (build number ignored).
@visibleForTesting
bool isNewerVersion(String tag, String current) {
  final a = _clean(tag).split('.');
  final b = _clean(current).split('.');
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? (int.tryParse(a[i]) ?? 0) : 0;
    final y = i < b.length ? (int.tryParse(b[i]) ?? 0) : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Runs the update check once per app launch.
final appUpdateProvider = FutureProvider.autoDispose<AppUpdateInfo?>(
  (ref) => checkForAppUpdate(),
);

/// Whether the "update available" prompt has already been shown this launch
/// (so it doesn't reappear on every rebuild).
bool updatePromptShown = false;
