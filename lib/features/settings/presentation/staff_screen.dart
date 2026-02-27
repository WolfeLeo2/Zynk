import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final staffAsync = ref.watch(staffProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Staff Members',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: staffAsync.when(
        data: (staff) {
          if (staff.isEmpty) {
            return _buildEmptyState(context, colorScheme);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: staff.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = staff[index];
              return _StaffCard(member: member, colorScheme: colorScheme);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/add-staff'),
        icon: const PhosphorIcon(PhosphorIconsBold.plus),
        label: const Text('Add Staff'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(
                PhosphorIconsDuotone.users,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Staff Members Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite team members to help manage your business.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/settings/add-staff'),
              icon: const PhosphorIcon(PhosphorIconsBold.plus),
              label: const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, required this.colorScheme});

  final Profile member;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine a role color
    Color roleColor;
    if (member.role == UserRole.owner) {
      roleColor = colorScheme.primary;
    } else if (member.role == UserRole.manager) {
      roleColor = Colors.orange;
    } else {
      roleColor = colorScheme.secondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: ClipOval(
            child: member.profilePictureUrl != null
                ? CachedNetworkImage(
                    imageUrl: member.profilePictureUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.red),
                  )
                : Center(
                    child: Text(
                      (member.displayName?.isNotEmpty ?? false)
                          ? member.displayName![0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        title: Text(
          member.displayName ?? 'Unknown User',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  member.role.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Could fetch branch name here if needed via branch provider, but currently omitting to keep it simple.
            ],
          ),
        ),
        trailing: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.caretRight),
          onPressed: () {
            // Future: Edit staff
          },
        ),
      ),
    );
  }
}
