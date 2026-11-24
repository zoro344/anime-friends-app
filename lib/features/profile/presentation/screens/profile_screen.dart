import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_avatar.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../friends/presentation/screens/friends_screen.dart';
import '../../../library/presentation/screens/library_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 15),
        Center(
          child: Column(
            children: [
              AFAvatar(label: appState.username, radius: 50),
              const SizedBox(height: 15),
              Text(
                appState.displayName.trim().isEmpty
                    ? appState.username
                    : appState.displayName,
                style: AppTypography.headingMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                appState.handle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                appState.bio,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            Expanded(child: _stat('${appState.postCount}', 'Posts')),
            Expanded(child: _stat('${appState.friendCount}', 'Friends')),
            Expanded(child: _stat('${appState.animeCount}', 'Anime')),
          ],
        ),
        const SizedBox(height: 25),
        const SectionTitle(title: 'Library'),
        _profileTile(
          Icons.library_books_outlined,
          'Anime & Manga Library',
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LibraryScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionTitle(title: 'Account'),
        _profileTile(
          Icons.person_outline,
          'Edit Profile',
          () => _editProfile(context, appState),
        ),
        _profileTile(
          Icons.logout,
          'Sign out',
          () => _confirmSignOut(context, appState),
        ),
        _profileTile(
          Icons.people_outline,
          'Friends',
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FriendsScreen()),
          ),
        ),
        _profileTile(
          Icons.settings_outlined,
          'Settings',
          () => _showMessage(context, 'Settings'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'ANIME FRIENDS',
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: AppTypography.headingMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _profileTile(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AFCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: AppColors.iconMuted),
          title: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.iconMuted,
          ),
        ),
      ),
    );
  }

  void _editProfile(BuildContext context, dynamic appState) {
    showDialog(
      context: context,
      builder: (_) => _EditProfileDialog(appState: appState),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, dynamic appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Sign out?'),
        content: const Text('You can sign in again with your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await appState.signOut();
  }

  void _showMessage(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title will be implemented next.')),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.appState});

  final dynamic appState;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController nameController;
  late final TextEditingController displayNameController;
  late final TextEditingController bioController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.appState.username,
    );
    displayNameController = TextEditingController(
      text: widget.appState.displayName,
    );
    bioController = TextEditingController(
      text: widget.appState.bio,
    );
  }

  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final success = await widget.appState.updateProfile(
      newUsername: nameController.text,
      newDisplayName: displayNameController.text,
      newBio: bioController.text,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (!success) {
      final message = widget.appState.authError as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Could not update your profile.' : message,
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully.')),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    displayNameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      scrollable: true,
      title: Text(
        'Edit Profile',
        style: AppTypography.headingSmall.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            maxLength: 24,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: displayNameController,
            maxLength: 40,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Display name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bioController,
            maxLength: 150,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
