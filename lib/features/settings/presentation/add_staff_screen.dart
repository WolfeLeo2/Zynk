import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  /// If non-null, the screen enters edit mode and prefills from this profile.
  final Profile? existingProfile;

  const AddStaffScreen({super.key, this.existingProfile});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late UserRole _selectedRole;
  late Set<String> _selectedBranchIds;
  bool _isLoading = false;
  bool _initialized = false;
  late Set<Permission> _permissions;

  bool get _isEditMode => widget.existingProfile != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProfile;
    _selectedRole = existing?.role ?? UserRole.cashier;
    _permissions = existing != null
        ? Set.from(existing.permissions)
        : Set.from(_selectedRole.defaultPermissions);
    _selectedBranchIds = <String>{};

    _nameController = TextEditingController(text: existing?.displayName ?? '');
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onRoleChanged(UserRole role) {
    setState(() {
      _selectedRole = role;
      _permissions = Set.from(role.defaultPermissions);
    });
  }

  /// Create new staff via Edge Function (sends invite email).
  Future<void> _inviteStaff() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranchIds.isEmpty) {
      _showError('Please select at least one branch');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-staff-user',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'name': _nameController.text.trim(),
          'role': _selectedRole.toShortString(),
          'branch_ids': _selectedBranchIds.toList(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'permissions': _permissions.map((p) => p.value).toList(),
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Failed to create staff');
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff invited successfully!')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Error creating staff: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Update existing staff profile locally (no email sent).
  Future<void> _updateStaff() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranchIds.isEmpty) {
      _showError('Please select at least one branch');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final existing = widget.existingProfile!;
      final repo = ref.read(repositoryProvider);
      await repo.updateStaffProfile(
        profileId: existing.id,
        userId: existing.userId,
        tenantId: existing.tenantId,
        displayName: _nameController.text.trim(),
        role: _selectedRole.toShortString(),
        permissions: Permission.toJsonList(_permissions),
        primaryBranchId: _selectedBranchIds.first,
        branchIds: _selectedBranchIds.toList(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );

      // Sync with Supabase Auth metadata
      await repo.updateStaffRemote(
        userId: existing.userId,
        name: _nameController.text.trim(),
        role: _selectedRole.toShortString(),
        primaryBranchId: _selectedBranchIds.first,
        branchIds: _selectedBranchIds.toList(),
        permissions: _permissions.map((p) => p.value).toList(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Staff member updated!')));
      }
    } catch (e) {
      if (mounted) _showError('Error updating staff: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.onError),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.x),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditMode ? 'Edit User Account' : 'Create Account',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: branchesAsync.when(
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsDuotone.storefront,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Branches Found',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You must create at least one branch before adding accounts.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Seed the selected branches once
          if (!_initialized && branches.isNotEmpty) {
            if (_isEditMode) {
              final profileBranches = ref.watch(
                profileBranchesProvider(widget.existingProfile!.id),
              );
              profileBranches.whenData((ids) {
                if (!_initialized) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      final primaryId = widget.existingProfile?.branchId;
                      if (primaryId != null) {
                        _selectedBranchIds.add(primaryId);
                      }
                      if (ids.isNotEmpty) {
                        _selectedBranchIds.addAll(ids);
                      }
                      _initialized = true;
                    });
                  });
                }
              });
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _selectedBranchIds.add(branches.first.id);
                  _initialized = true;
                });
              });
            }
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Header icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: PhosphorIcon(
                      _isEditMode
                          ? PhosphorIconsDuotone.userGear
                          : PhosphorIconsDuotone.userPlus,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Name Field
                _FieldLabel(label: 'Account Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditMode,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g., Main Register or Branch Cashier',
                    prefixIcon: const PhosphorIcon(PhosphorIconsRegular.user),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Email & Password — only shown in create mode
                if (!_isEditMode) ...[
                  _FieldLabel(label: 'Email Address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'e.g., staff@example.com',
                      prefixIcon: const PhosphorIcon(
                        PhosphorIconsRegular.envelope,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _FieldLabel(label: 'Initial Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'At least 6 characters',
                      prefixIcon: const PhosphorIcon(
                        PhosphorIconsRegular.lockKey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (value.length < 6) {
                        return 'Must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Phone Field
                _FieldLabel(label: 'Phone Number'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'e.g., +254 700 123 456 (Optional)',
                    prefixIcon: const PhosphorIcon(PhosphorIconsRegular.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  validator: (value) => null,
                ),
                const SizedBox(height: 24),

                // Address Field (Optional)
                _FieldLabel(label: 'Physical Address (Optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g., Branch Location or Station Spot',
                    prefixIcon: const PhosphorIcon(PhosphorIconsRegular.mapPin),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  validator: (value) => null,
                ),
                const SizedBox(height: 24),

                // Role chips — Owner cannot be assigned here
                _FieldLabel(label: 'Role'),
                const SizedBox(height: 8),
                Row(
                  children: [UserRole.cashier, UserRole.manager].map((role) {
                    final isSelected = _selectedRole == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(role.label),
                        selected: isSelected,
                        showCheckmark: false,
                        avatar: PhosphorIcon(
                          role == UserRole.manager
                              ? PhosphorIconsRegular.crown
                              : PhosphorIconsRegular.user,
                          size: 18,
                        ),
                        onSelected: (_) => _onRoleChanged(role),
                        selectedColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Branch Multi-select
                _FieldLabel(label: 'Assigned Branches'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: colorScheme.surface,
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: branches.map((branch) {
                      final selected = _selectedBranchIds.contains(branch.id);
                      return FilterChip(
                        label: Text(branch.name),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (enabled) {
                          setState(() {
                            if (enabled) {
                              _selectedBranchIds.add(branch.id);
                            } else {
                              _selectedBranchIds.remove(branch.id);
                            }
                          });
                        },
                        selectedColor: colorScheme.primary,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.7),
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Permissions
                _FieldLabel(label: 'Permissions'),
                const SizedBox(height: 4),
                Text(
                  'Customize what can be done with this account. '
                  'Changing the role resets to defaults.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...PermissionCategory.values.map(
                  (cat) => _PermissionCategoryCard(
                    category: cat,
                    permissions: _permissions,
                    colorScheme: colorScheme,
                    theme: theme,
                    onToggle: (perm, enabled) {
                      setState(() {
                        if (enabled) {
                          _permissions.add(perm);
                        } else {
                          _permissions.remove(perm);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // CTA Button
                FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : (_isEditMode ? _updateStaff : _inviteStaff),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isLoading
                      ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const PhosphorIcon(PhosphorIconsBold.check),
                  label: Text(
                    _isLoading
                        ? (_isEditMode ? 'Saving...' : 'Creating Account...')
                        : (_isEditMode ? 'Save Changes' : 'Create Account'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error loading branches: $err')),
      ),
    );
  }
}

// ── Helper Widgets ──

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// A card that shows permissions grouped by category with toggle switches.
class _PermissionCategoryCard extends StatelessWidget {
  final PermissionCategory category;
  final Set<Permission> permissions;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final void Function(Permission, bool) onToggle;

  const _PermissionCategoryCard({
    required this.category,
    required this.permissions,
    required this.colorScheme,
    required this.theme,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final catPerms = category.permissions;
    final allEnabled = catPerms.every((p) => permissions.contains(p));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Category header with "select all" toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _categoryIcon(category),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        category.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: allEnabled,
                  onChanged: (enabled) {
                    for (final p in catPerms) {
                      onToggle(p, enabled);
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Individual toggles
          ...catPerms.map(
            (perm) => SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              dense: true,
              title: Text(perm.displayName, style: theme.textTheme.bodyMedium),
              subtitle: Text(
                perm.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: permissions.contains(perm),
              onChanged: (enabled) => onToggle(perm, enabled),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryIcon(PermissionCategory cat) {
    switch (cat) {
      case PermissionCategory.sales:
        return PhosphorIcon(
          PhosphorIconsDuotone.shoppingCart,
          color: Colors.blue,
          size: 20,
        );
      case PermissionCategory.inventory:
        return PhosphorIcon(
          PhosphorIconsDuotone.package,
          color: Colors.orange,
          size: 20,
        );
      case PermissionCategory.reports:
        return PhosphorIcon(
          PhosphorIconsDuotone.chartBar,
          color: Colors.purple,
          size: 20,
        );
      case PermissionCategory.people:
        return PhosphorIcon(
          PhosphorIconsDuotone.users,
          color: Colors.green,
          size: 20,
        );
      case PermissionCategory.settings:
        return PhosphorIcon(
          PhosphorIconsDuotone.gear,
          color: Colors.grey,
          size: 20,
        );
    }
  }
}
