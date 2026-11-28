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
    final displayName = appState.displayName.trim().isEmpty
        ? appState.username
        : appState.displayName.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR SPACE',
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Profile',
                    style: AppTypography.headingLarge,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => _editProfile(context, appState),
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.textPrimary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _buildProfileHeader(
          displayName: displayName,
          username: appState.username,
          handle: appState.handle,
          bio: appState.bio,
          avatarUrl: appState.avatarUrl,
        ),

        const SizedBox(height: 16),

        _buildStats(
          posts: appState.postCount,
          friends: appState.friendCount,
          anime: appState.animeCount,
        ),

        const SizedBox(height: 28),

        const SectionTitle(title: 'Your collection'),
        const SizedBox(height: 10),
        _buildLibraryCard(context),

        const SizedBox(height: 26),

        const SectionTitle(title: 'Account'),
        const SizedBox(height: 10),

        _ProfileActionTile(
          icon: Icons.person_outline_rounded,
          title: 'Edit profile',
          subtitle: 'Update your username, name and bio',
          onTap: () => _editProfile(context, appState),
        ),
        const SizedBox(height: 9),
        _ProfileActionTile(
          icon: Icons.people_outline_rounded,
          title: 'Friends',
          subtitle: 'View your connections',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FriendsScreen(),
            ),
          ),
        ),
        const SizedBox(height: 9),
        _ProfileActionTile(
          icon: Icons.logout_rounded,
          title: 'Sign out',
          subtitle: 'Sign out of your Anime Friends account',
          iconColor: AppColors.error,
          onTap: () => _confirmSignOut(context, appState),
        ),

        const SizedBox(height: 30),

        Center(
          child: Column(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary.withValues(alpha: 0.8),
                size: 21,
              ),
              const SizedBox(height: 8),
              Text(
                'ANIME FRIENDS',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your anime community',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader({
    required String displayName,
    required String username,
    required String handle,
    required String bio,
    required String? avatarUrl,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.75),
                width: 2,
              ),
            ),
            child: AFAvatar(
              imageUrl: avatarUrl,
              label: username,
              radius: 43,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headingMedium,
          ),
          const SizedBox(height: 5),
          Text(
            handle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (bio.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: 42,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bio.trim(),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'ANIME FRIENDS MEMBER',
                  style: AppTypography.label.copyWith(
                    color: AppColors.primary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats({
    required int posts,
    required int friends,
    required int anime,
  }) {
    return AFCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 17,
      ),
      child: Row(
        children: [
          Expanded(child: _ProfileStat(value: posts, label: 'Posts')),
          _statDivider(),
          Expanded(child: _ProfileStat(value: friends, label: 'Friends')),
          _statDivider(),
          Expanded(child: _ProfileStat(value: anime, label: 'Anime')),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      height: 35,
      width: 1,
      color: AppColors.divider,
    );
  }

  Widget _buildLibraryCard(BuildContext context) {
    return AFCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const LibraryScreen(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.collections_bookmark_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anime & Manga Library',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explore your saved collection',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.iconMuted,
              ),
            ],
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

  Future<void> _confirmSignOut(
    BuildContext context,
    dynamic appState,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          'Sign out?',
          style: AppTypography.headingSmall,
        ),
        content: Text(
          'You can sign in again with your account.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await appState.signOut();
    }
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: AppTypography.headingMedium.copyWith(
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.iconMuted;

    return AFCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 5,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        title: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: title == 'Sign out'
                ? AppColors.error
                : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.iconMuted,
        ),
      ),
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

  bool _isSaving = false;

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
            message.isEmpty
                ? 'Could not update your profile.'
                : message,
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully.'),
      ),
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
        style: AppTypography.headingSmall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            maxLength: 24,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: displayNameController,
            maxLength: 40,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'Display name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bioController,
            maxLength: 150,
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'Bio',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
