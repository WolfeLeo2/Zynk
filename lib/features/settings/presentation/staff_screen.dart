import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/shared/widgets/shimmer_skeletons.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/shared/widgets/set_pin_dialog.dart';

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
        title: Text(
          'User Accounts',
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
          // Filter out the owner from the user accounts list to keep it focused on staff management
          final humanStaff = staff
              .where((member) => member.role != UserRole.owner)
              .toList();

          if (humanStaff.isEmpty) {
            return _buildEmptyState(context, colorScheme);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: humanStaff.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = humanStaff[index];
              return _StaffCard(member: member, colorScheme: colorScheme);
            },
          );
        },
        loading: () => const ListSkeleton(
          itemCount: 8,
          height: 80,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/add-staff'),
        icon: const PhosphorIcon(PhosphorIconsBold.plus),
        label: const Text('Add Account'),
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
              'No User Accounts Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create workstation or terminal accounts for your branches.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/settings/add-staff'),
              icon: const PhosphorIcon(PhosphorIconsBold.plus),
              label: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard({required this.member, required this.colorScheme});

  final Profile member;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isBlocked =
        member.status == ProfileStatus.inactive ||
        member.status == ProfileStatus.blocked;

    // Determine a role color
    Color roleColor;
    if (member.role == UserRole.owner) {
      roleColor = colorScheme.primary;
    } else if (member.role == UserRole.manager) {
      roleColor = Colors.orange;
    } else {
      roleColor = colorScheme.secondary;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => context.push('/settings/add-staff', extra: member),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.surface,
          child: ClipOval(
            child: member.profilePictureUrl != null
                ? CachedNetworkImage(
                    imageUrl: member.profilePictureUrl!,
                    fit: BoxFit.cover,
                    width: 48,
                    height: 48,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const PhosphorIcon(
                      PhosphorIconsRegular.user,
                      color: Colors.grey,
                    ),
                  )
                : Text(
                    (member.displayName?.isNotEmpty ?? false)
                        ? member.displayName![0].toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.displayName ?? 'Unknown User',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (isBlocked)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  member.status == ProfileStatus.inactive
                      ? 'BANNED'
                      : 'BLOCKED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.red,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (ref.watch(profilesWithPinProvider).value?.contains(member.id) ??
                false)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PIN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            member.role.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: roleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: PhosphorIcon(
            PhosphorIconsRegular.dotsThreeVertical,
            color: colorScheme.onSurfaceVariant,
          ),
          onSelected: (value) async {
            if (value == 'edit') {
              context.push('/settings/add-staff', extra: member);
            } else if (value == 'reset_password') {
              showDialog(
                context: context,
                builder: (ctx) => _ResetPasswordDialog(member: member),
              );
            } else if (value == 'set_pin') {
              showDialog(
                context: context,
                builder: (ctx) => SetPinDialog(member: member),
              );
            } else if (value == 'block' || value == 'unblock') {
              final newStatus = value == 'block'
                  ? ProfileStatus.blocked
                  : ProfileStatus.active;
              try {
                await ref
                    .read(repositoryProvider)
                    .updateProfileStatus(
                      userId: member.userId,
                      status: newStatus,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Account ${value == 'block' ? 'blocked' : 'activated'}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } else if (value == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: Text(
                    'Are you sure you want to delete "${member.displayName}"? This will revoke all access.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                try {
                  await ref
                      .read(repositoryProvider)
                      .deleteProfile(member.userId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: PhosphorIcon(PhosphorIconsRegular.pencilSimple),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isBlocked ? 'unblock' : 'block',
              child: ListTile(
                leading: PhosphorIcon(
                  isBlocked
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.prohibit,
                ),
                title: Text(isBlocked ? 'Unblock' : 'Block'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'reset_password',
              child: ListTile(
                leading: PhosphorIcon(PhosphorIconsRegular.lockKey),
                title: Text('Reset Password'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'set_pin',
              child: ListTile(
                leading: PhosphorIcon(PhosphorIconsRegular.password),
                title: Text('Set Login PIN'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: PhosphorIcon(
                  PhosphorIconsRegular.trash,
                  color: Colors.red,
                ),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  final Profile member;

  const _ResetPasswordDialog({required this.member});

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authServiceProvider)
          .resetStaffPassword(
            userId: widget.member.userId,
            newPassword: _passwordController.text,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password reset successfully for ${widget.member.displayName}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set a new password for ${widget.member.displayName ?? 'this account'}.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                prefixIcon: const PhosphorIcon(PhosphorIconsRegular.lockKey),
                suffixIcon: IconButton(
                  icon: PhosphorIcon(
                    _obscureText
                        ? PhosphorIconsRegular.eyeClosed
                        : PhosphorIconsRegular.eye,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter a password';
                if (v.length < 6)
                  return 'Password must be at least 6 characters';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Reset Password'),
        ),
      ],
    );
  }
}
