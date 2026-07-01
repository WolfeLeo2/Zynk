import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:ota_update/ota_update.dart';
import 'package:zynk/core/services/app_update_service.dart';

/// Bottom sheet offering to download + install a newer version. Shows download
/// progress; the OS installer takes over once the APK is downloaded.
Future<void> showUpdatePrompt(BuildContext context, AppUpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UpdateSheet(info: info),
  );
}

class _UpdateSheet extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  double? _progress; // null = not started
  String? _error;

  void _start() {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      startAppUpdate(widget.info.apkUrl).listen(
        (event) {
          if (!mounted) return;
          if (event.status == OtaStatus.DOWNLOADING) {
            final p = int.tryParse(event.value ?? '');
            if (p != null) setState(() => _progress = p / 100);
          } else if (event.status == OtaStatus.INSTALLING) {
            // OS installer launched — the sheet can close.
            if (mounted) Navigator.of(context).maybePop();
          } else if (event.status != OtaStatus.DOWNLOADING) {
            setState(() => _error = 'Update failed. Please try again.');
          }
        },
        onError: (_) {
          if (mounted) setState(() => _error = 'Update failed. Please try again.');
        },
      );
    } catch (_) {
      setState(() => _error = 'Update failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final downloading = _progress != null && _error == null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PhosphorIcon(PhosphorIconsDuotone.arrowCircleUp, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  'Update available',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${widget.info.version}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (widget.info.notes != null &&
                widget.info.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.notes!.trim(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (downloading) ...[
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 8),
              Text(
                'Downloading… ${((_progress ?? 0) * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: cs.error)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _start,
                      child: Text(_error == null ? 'Update now' : 'Retry'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
