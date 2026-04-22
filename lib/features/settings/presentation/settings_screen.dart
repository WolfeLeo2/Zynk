import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/core/theme/app_tokens.dart';
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
          final measurementSystem = ref.watch(measurementSystemProvider);
          final isOwner = ref.watch(isOwnerProvider);
          if (_nameController.text.isEmpty && profile != null) {
            _nameController.text = profile.displayName ?? '';
          }

          return SettingsList(
            maxWidth: 960,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
                                color: AppTokens.bgSurfaceHighlightDark,
                              ),
                              child: ClipOval(
                                child: profile?.profilePictureUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: profile!.profilePictureUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.error,
                                              color: Colors.red,
                                            ),
                                      )
                                    : Center(
                                        child: Text(
                                          (displayName.isNotEmpty)
                                              ? displayName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(fontSize: 32),
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
                                icon: const Icon(
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
                                prefixIcon: Icon(PhosphorIconsDuotone.user),
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
                                prefixIcon: Icon(PhosphorIconsDuotone.envelope),
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
                  (profile?.hasPermission(Permission.manageBranches) == true) || 
                  (profile?.hasPermission(Permission.manageStaff) == true))
                SettingsSection(
                  title: const Text('Business'),
                  tiles: <SettingsTile>[
                    if (isOwner)
                      SettingsTile.navigation(
                        leading: const Icon(PhosphorIconsDuotone.image),
                        title: const Text('Business Logo'),
                        description: const Text('Update your shop\'s logo'),
                        trailing: _isLoading
                            ? Text(
                                'Updating',
                                style: Theme.of(context).textTheme.labelSmall,
                              )
                            : null,
                        enabled: !_isLoading,
                        onPressed: (_) => _updateBusinessLogo(),
                      ),
                    if (profile?.hasPermission(Permission.manageBranches) == true)
                      SettingsTile.navigation(
                        leading: const Icon(PhosphorIconsDuotone.storefront),
                        title: const Text('Branches'),
                        description: const Text('Manage your business locations'),
                        onPressed: (_) => context.push('/settings/branches'),
                      ),
                    if (profile?.hasPermission(Permission.manageStaff) == true)
                      SettingsTile.navigation(
                        leading: const Icon(PhosphorIconsDuotone.userList),
                        title: const Text('People'),
                        description: const Text(
                          'Manage salespersons and adjusters',
                        ),
                        onPressed: (_) => context.push('/settings/staff-members'),
                      ),
                    if (profile?.hasPermission(Permission.manageStaff) == true)
                      SettingsTile.navigation(
                        leading: const Icon(PhosphorIconsDuotone.users),
                        title: const Text('Staff'),
                        description: const Text('Manage your team and roles'),
                        onPressed: (_) => context.push('/settings/staff'),
                      ),
                  ],
                ),

              SettingsSection(
                title: const Text('App Settings'),
                bottomInfo: const Text(
                  'Used for product dimensions and weight',
                ),
                tiles: <SettingsTile>[
                  SettingsTile<MeasurementSystem>.radioTile(
                    leading: const Icon(PhosphorIconsDuotone.ruler),
                    title: const Text('Metric (cm, kg)'),
                    radioValue: MeasurementSystem.metric,
                    groupValue: measurementSystem,
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(measurementSystemProvider.notifier)
                            .setSystem(value);
                      }
                    },
                  ),
                  SettingsTile<MeasurementSystem>.radioTile(
                    leading: const Icon(PhosphorIconsDuotone.ruler),
                    title: const Text('Imperial (in, lb)'),
                    radioValue: MeasurementSystem.imperial,
                    groupValue: measurementSystem,
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(measurementSystemProvider.notifier)
                            .setSystem(value);
                      }
                    },
                  ),
                  SettingsTile.navigation(
                    leading: const Icon(PhosphorIconsDuotone.palette),
                    title: const Text('Theme'),
                    description: const Text('System Default'),
                    onPressed: (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Theme settings coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SettingsSection(
                title: const Text('Account'),
                tiles: <SettingsTile>[
                  SettingsTile.navigation(
                    leading: const Icon(
                      PhosphorIconsDuotone.signOut,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
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
                              onPressed: () => Navigator.pop(context, false),
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
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
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
