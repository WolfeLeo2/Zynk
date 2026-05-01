import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/staff_model.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';



// ─────────────────────────────────────────────────────────────────────────────
// STAFF MEMBERS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class StaffMembersScreen extends ConsumerWidget {
  const StaffMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(humanStaffProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salespersons'),
        actions: [
          IconButton(
            onPressed: () => _showAddEditStaffSheet(context, ref, null),
            icon: const Icon(PhosphorIconsBold.plus),
          ),
        ],
      ),
      body: staffAsync.when(
        data: (staff) {
          if (staff.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsDuotone.users,
                    size: 64,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No staff members yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first staff member to get started',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddEditStaffSheet(context, ref, null),
                    icon: const Icon(PhosphorIconsRegular.plus),
                    label: const Text('Add Staff Member'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: staff.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final member = staff[i];
              return _StaffMemberCard(
                member: member,
                onEdit: () =>
                    _showAddEditStaffSheet(context, ref, member),
                onDelete: () => _confirmDelete(context, ref, member),
              );
            },
          );
        },
        loading: () => _StaffListSkeleton(),
        error: (err, stack) => Center(child: Text('Error loading staff: $err')),
      ),
      floatingActionButton: staffAsync.hasValue && staffAsync.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditStaffSheet(context, ref, null),
              icon: const Icon(PhosphorIconsBold.plus),
              label: const Text('Add Member'),
            )
          : null,
    );
  }

  void _showAddEditStaffSheet(
    BuildContext context,
    WidgetRef ref,
    StaffMember? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StaffMemberForm(existing: existing),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StaffMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text(
          'Are you sure you want to remove "${member.name}" from your staff list? This will deactivate their record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(repositoryProvider).deleteStaffMember(member.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${member.name} removed')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAFF MEMBER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StaffMemberCard extends ConsumerWidget {
  final StaffMember member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffMemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBlocked = member.status == StaffStatus.inactive || member.status == StaffStatus.blocked;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: cs.surface,
          child: member.profilePictureUrl != null
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: member.profilePictureUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: Text(
                        member.name[0].toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Text(
                        member.name[0].toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                )
              : Text(
                  member.name[0].toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
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
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  member.status == StaffStatus.inactive ? 'BANNED' : 'BLOCKED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.red,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.phone != null && member.phone!.isNotEmpty)
              Text(
                member.phone!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            if (member.email != null && member.email!.isNotEmpty)
              Text(
                member.email!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(PhosphorIconsRegular.dotsThreeVertical, color: cs.onSurfaceVariant),
          onSelected: (value) async {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
            if (value == 'block' || value == 'unblock') {
              final newStatus = value == 'block' ? StaffStatus.blocked : StaffStatus.active;
              try {
                await ref.read(repositoryProvider).updateStaffMemberStatus(
                  memberId: member.id,
                  status: newStatus,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(PhosphorIconsRegular.pencilSimple),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isBlocked ? 'unblock' : 'block',
              child: ListTile(
                leading: Icon(isBlocked ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.prohibit),
                title: Text(isBlocked ? 'Unblock' : 'Block'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(
                  PhosphorIconsRegular.trash,
                  color: Colors.red,
                ),
                title: Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAFF MEMBER FORM (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class _StaffMemberForm extends ConsumerStatefulWidget {
  final StaffMember? existing;

  const _StaffMemberForm({this.existing});

  @override
  ConsumerState<_StaffMemberForm> createState() => _StaffMemberFormState();
}

class _StaffMemberFormState extends ConsumerState<_StaffMemberForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  Uint8List? _imageBytes;
  String? _currentPictureUrl;
  String? _selectedBranchId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _currentPictureUrl = widget.existing?.profilePictureUrl;
    _selectedBranchId = widget.existing?.branchId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<String?> _uploadImage(String memberId, String tenantId) async {
    if (_imageBytes == null) return _currentPictureUrl;

    final path = 'staff/$tenantId/$memberId.jpg';
    await Supabase.instance.client.storage
        .from('avatars')
        .uploadBinary(
          path,
          _imageBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profile = ref.read(currentProfileProvider);
      if (profile == null) throw Exception('No profile found');

      final memberId = widget.existing?.id ?? const Uuid().v4();
      final pictureUrl = await _uploadImage(memberId, profile.tenantId);

      final member = StaffMember(
        id: memberId,
        tenantId: profile.tenantId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        profilePictureUrl: pictureUrl,
        branchId: _selectedBranchId,
        status: StaffStatus.active,
      );

      final repo = ref.read(repositoryProvider);
      if (widget.existing == null) {
        await repo.createStaffMember(member);
      } else {
        await repo.updateStaffMember(member);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEdit ? 'Edit Staff Member' : 'New Staff Member',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Profile Picture
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: _imageBytes != null
                            ? MemoryImage(_imageBytes!)
                            : null,
                        child: _imageBytes == null
                            ? (_currentPictureUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: _currentPictureUrl!,
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                      errorWidget: (context, url, error) => const CircleAvatar(child: Icon(PhosphorIconsRegular.user)),
                                    ),
                                  )
                                : Icon(
                                    PhosphorIconsDuotone.user,
                                    size: 40,
                                    color: cs.onPrimaryContainer,
                                  ))
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            PhosphorIconsBold.camera,
                            size: 16,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(PhosphorIconsRegular.user),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(PhosphorIconsRegular.phone),
                ),
              ),
              const SizedBox(height: 16),

              // Branch Selection
              Consumer(
                builder: (context, ref, child) {
                  final branchesAsync = ref.watch(branchesProvider);
                  return branchesAsync.when(
                    data: (branches) {
                      final filteredBranches =
                          branches.where((b) => b.id != 'all').toList();
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedBranchId,
                        decoration: InputDecoration(
                          labelText: 'Assigned Branch',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(PhosphorIconsRegular.storefront),
                          helperText: 'Leave empty for shared staff',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Shared (All Branches)'),
                          ),
                          ...filteredBranches.map(
                            (b) => DropdownMenuItem<String>(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedBranchId = v),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(PhosphorIconsRegular.envelope),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEdit ? 'Save Changes' : 'Add Staff Member',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON
// ─────────────────────────────────────────────────────────────────────────────

class _StaffListSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
