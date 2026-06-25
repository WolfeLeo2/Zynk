import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/shared/widgets/branch_dropdown.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/auth/providers/lock_provider.dart';
import 'package:zynk/shared/widgets/set_pin_dialog.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/core/models/user_role.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = ref.read(currentUserProfileProvider).value;

      if (profile == null) throw Exception('Profile not found');

      final fileExt = pickedFile.path.split('.').last;
      final fileName =
          '${profile.userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'avatars/$fileName';

      final bytes = await pickedFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      final repo = ref.read(repositoryProvider);

      await repo.updateProfile(profile.userId, {
        'profile_picture_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating picture: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile == null) return;

      final repo = ref.read(repositoryProvider);

      await repo.updateProfile(profile.userId, {
        'display_name': _nameController.text,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error causing update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBusinessLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final profile = ref.read(currentUserProfileProvider).value;

      if (profile?.tenantId == null) {
        throw Exception('Tenant not found');
      }

      final tenantId = profile!.tenantId;
      final fileExt = pickedFile.path.split('.').last;
      final fileName =
          '${tenantId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'tenant_logos/$fileName';

      final bytes = await pickedFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('logos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('logos')
          .getPublicUrl(path);

      final repo = ref.read(repositoryProvider);

      await repo.updateTenant(tenantId, {'logo_url': imageUrl});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Business logo updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating logo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final canSwitch = ref.watch(canSwitchBranchProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const PhosphorIcon(PhosphorIconsDuotone.list),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Settings'),
      ),
      body: profileAsync.when(
        data: (profile) {
          final displayName = profile?.displayName ?? user?.email ?? '';
          final isOwner = ref.watch(isOwnerProvider);
          if (_nameController.text.isEmpty && profile != null) {
            _nameController.text = profile.displayName ?? '';
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: SettingsList(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                lightTheme: SettingsThemeData(
                  settingsListBackground: Theme.of(context).colorScheme.surface,
                  settingsSectionBackground: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLow,
                  dividerColor: Theme.of(context).colorScheme.outlineVariant,
                  tileDescriptionTextColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  leadingIconsColor: Theme.of(context).colorScheme.primary,
                ),
                darkTheme: SettingsThemeData(
                  settingsListBackground: Theme.of(context).colorScheme.surface,
                  settingsSectionBackground: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLow,
                  dividerColor: Theme.of(context).colorScheme.outlineVariant,
                  tileDescriptionTextColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  leadingIconsColor: Theme.of(context).colorScheme.primary,
                ),
                sections: [
                  CustomSettingsSection(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _SettingsSection(
                        title: 'Profile',
                        children: [
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cs.surfaceContainerHighest,
                                  ),
                                  child: ClipOval(
                                    child: profile?.profilePictureUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                profile!.profilePictureUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (
                                                  context,
                                                  url,
                                                  error,
                                                ) => const PhosphorIcon(
                                                  PhosphorIconsBold.sealWarning,
                                                  color: Colors.red,
                                                ),
                                          )
                                        : Center(
                                            child: Text(
                                              (displayName.isNotEmpty)
                                                  ? displayName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 32,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: IconButton.filled(
                                    onPressed: _isLoading
                                        ? null
                                        : _updateProfilePicture,
                                    icon: const PhosphorIcon(
                                      PhosphorIconsBold.camera,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Display Name',
                                    border: OutlineInputBorder(),
                                    prefixIcon: PhosphorIcon(
                                      PhosphorIconsDuotone.user,
                                    ),
                                  ),
                                  validator: (v) =>
                                      v?.isEmpty == true ? 'Required' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: user?.email,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                    prefixIcon: PhosphorIcon(
                                      PhosphorIconsDuotone.envelope,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonal(
                                    onPressed: _isLoading ? null : _saveProfile,
                                    child: Text(
                                      _isLoading
                                          ? 'Updating...'
                                          : 'Update Profile Info',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isOwner ||
                      (profile?.hasPermission(Permission.manageBranches) ==
                          true) ||
                      (profile?.hasPermission(Permission.manageStaff) ==
                          true) ||
                      (profile?.hasPermission(Permission.manageCustomers) ==
                          true))
                    SettingsSection(
                      title: Text(
                        'Business',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      tiles: [
                        if (isOwner)
                          SettingsTile.navigation(
                            leading: const PhosphorIcon(
                              PhosphorIconsDuotone.image,
                            ),
                            title: Text(
                              'Business Logo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            description: Text(
                              'Update your shop\'s logo',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: _isLoading
                                ? Text(
                                    'Updating',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  )
                                : null,
                            enabled: !_isLoading,
                            onPressed: (_) => _updateBusinessLogo(),
                          ),
                        if (profile?.hasPermission(Permission.manageBranches) ==
                            true)
                          SettingsTile.navigation(
                            leading: const PhosphorIcon(
                              PhosphorIconsDuotone.storefront,
                            ),
                            title: Text(
                              'Branches',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            description: Text(
                              'Manage your business locations',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onPressed: (_) =>
                                context.push('/settings/branches'),
                          ),
                        if (profile?.hasPermission(Permission.manageStaff) ==
                            true)
                          SettingsTile.navigation(
                            leading: const PhosphorIcon(
                              PhosphorIconsDuotone.userList,
                            ),
                            title: Text(
                              'Salespersons',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            description: Text(
                              'Manage actual employees',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onPressed: (_) =>
                                context.push('/settings/staff-members'),
                          ),
                        if (profile?.hasPermission(Permission.manageStaff) ==
                            true)
                          SettingsTile.navigation(
                            leading: const PhosphorIcon(
                              PhosphorIconsDuotone.users,
                            ),
                            title: Text(
                              'User Accounts',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            description: Text(
                              'Manage branch logins and permissions',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onPressed: (_) => context.push('/settings/staff'),
                          ),
                        if (profile?.hasPermission(
                              Permission.manageCustomers,
                            ) ==
                            true)
                          SettingsTile.navigation(
                            leading: const PhosphorIcon(
                              PhosphorIconsDuotone.usersFour,
                            ),
                            title: Text(
                              'Customers',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            description: Text(
                              'Manage your customer directory',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onPressed: (_) =>
                                context.push('/settings/customers'),
                          ),
                      ],
                    ),

                  SettingsSection(
                    title: Text(
                      'Security',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    tiles: [
                      SettingsTile.navigation(
                        leading: const PhosphorIcon(
                          PhosphorIconsDuotone.password,
                        ),
                        title: Text(
                          'Change Password',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        description: Text(
                          'Update your login password',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onPressed: (_) =>
                            context.push('/settings/change-password'),
                      ),
                    ],
                  ),

                  SettingsSection(
                    title: Text(
                      'App Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    tiles: [
                      /*
                  SettingsTile.navigation(
                    leading: const PhosphorIcon(PhosphorIconsDuotone.ruler),
                    title: Text('Measurement System', style: Theme.of(context).textTheme.titleMedium),
                    description: Text(
                      measurementSystem == MeasurementSystem.metric ? 'Metric (cm, kg)' : 'Imperial (in, lb)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onPressed: (context) {
                      // Logic for switching measurement system can be added here
                    },
                  ),
                  */
                      SettingsTile(
                        leading: const PhosphorIcon(
                          PhosphorIconsDuotone.palette,
                        ),
                        title: Text(
                          'Theme',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        trailing: DropdownButton<ThemeMode>(
                          value: ref.watch(themeModeProvider),
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          onChanged: (ThemeMode? mode) {
                            if (mode != null) {
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(mode);
                            }
                          },
                          items: [
                            DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text(
                                'System',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text(
                                'Light',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text(
                                'Dark',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SettingsTile(
                        leading: const PhosphorIcon(
                          PhosphorIconsDuotone.storefront,
                        ),
                        title: Text(
                          canSwitch ? 'Default Branch' : 'Assigned Branch',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        trailing: const BranchDropdown(),
                      ),
                      SettingsTile(
                        leading: const PhosphorIcon(
                          PhosphorIconsDuotone.lockKey,
                        ),
                        title: Text(
                          'Auto-lock',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        trailing: DropdownButton<int>(
                          value: ref.watch(autoLockSecondsProvider),
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor:
                              Theme.of(context).colorScheme.surfaceContainerHigh,
                          onChanged: (seconds) {
                            if (seconds != null) {
                              ref
                                  .read(autoLockSecondsProvider.notifier)
                                  .setSeconds(seconds);
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 60, child: Text('1 min')),
                            DropdownMenuItem(value: 120, child: Text('2 min')),
                            DropdownMenuItem(value: 300, child: Text('5 min')),
                            DropdownMenuItem(value: 600, child: Text('10 min')),
                          ],
                        ),
                      ),
                      // Owner's own login PIN — the owner is hidden from the
                      // User Accounts list, so this is their path to set it.
                      if (isOwner && profile != null)
                        SettingsTile.navigation(
                          leading: const PhosphorIcon(
                            PhosphorIconsDuotone.password,
                          ),
                          title: Text(
                            'My Login PIN',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          description: Text(
                            'Set or change your sign-in PIN',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onPressed: (_) => showDialog(
                            context: context,
                            builder: (_) => SetPinDialog(member: profile),
                          ),
                        ),
                    ],
                  ),

                  SettingsSection(
                    tiles: [
                      SettingsTile.navigation(
                        leading: PhosphorIcon(
                          PhosphorIconsDuotone.signOut,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Sign Out',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        onPressed: (_) async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text(
                                'Are you sure you want to sign out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await _signOut();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const _SettingsLoadingView(),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _SettingsLoadingView extends StatelessWidget {
  const _SettingsLoadingView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}
