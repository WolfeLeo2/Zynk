import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/services/app_update_service.dart';

/// Bottom sheet offering to download + install a newer version. Download state
/// lives in [updateDownloadProvider], so progress survives the sheet being
/// dismissed and reopened, and re-tapping never double-starts the download.
Future<void> showUpdatePrompt(BuildContext context, AppUpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _UpdateSheet(info: info),
  );
}

class _UpdateSheet extends ConsumerWidget {
  final AppUpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final download = ref.watch(updateDownloadProvider);

    ref.listen(updateDownloadProvider, (prev, next) {
      if (next.status == UpdateDownloadStatus.installing) {
        Navigator.of(context).maybePop();
      }
    });

    final downloading = download.status == UpdateDownloadStatus.downloading;
    final error = download.status == UpdateDownloadStatus.error
        ? download.error
        : null;

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
              'Version ${info.version}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (info.notes != null && info.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(
                    info.notes!.trim(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (downloading) ...[
              LinearProgressIndicator(
                value: download.progress == 0 ? null : download.progress,
              ),
              const SizedBox(height: 8),
              Text(
                'Downloading… ${(download.progress * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              if (error != null) ...[
                Text(error, style: TextStyle(color: cs.error)),
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
                      onPressed: () => ref
                          .read(updateDownloadProvider.notifier)
                          .start(info.apkUrl),
                      child: Text(error == null ? 'Update now' : 'Retry'),
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
