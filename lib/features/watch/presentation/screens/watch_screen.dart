import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_button.dart';
import '../../../../core/widgets/af_card.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/section_title.dart';
import 'watch_room_chat_screen.dart';

class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});

  void createRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateRoomDialog(
        onCreate: (details) async {
          final state = AppStateScope.of(context);
          final result = await state.createIntegratedWatchRoom(
            roomName: details['roomName']!,
            provider: details['provider']!,
            providerUserId: details['providerUserId']!,
            animeId: details['animeId']!,
            animeTitle: details['animeTitle']!,
            episodeNumber: int.parse(details['episodeNumber']!),
            streamUrl: details['streamUrl']!,
          );
          if (!context.mounted) return false;
          if (result == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.roomError.isEmpty ? 'Room creation failed.' : state.roomError)),
            );
            return false;
          }
          final link = Uri.tryParse(result['deepLink']?.toString() ?? '');
          if (link != null) {
            try {
              final opened = await launchUrl(link, mode: LaunchMode.externalApplication);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room created. Install AnymeX to open the playback room.')),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room created, but AnymeX could not be opened.')),
                );
              }
            }
          }
          return true;
        },
      ),
    );
  }

  Future<void> promptJoinRoom(BuildContext context) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Join by room code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 12,
          decoration: const InputDecoration(hintText: 'Enter room code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.isNotEmpty && context.mounted) {
      await joinRoom(context, code);
    }
  }

  Future<void> joinRoom(BuildContext context, String code) async {
    final result = await AppStateScope.of(context).joinRoom(code);
    if (!context.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not join room.')));
      return;
    }
    final room = result['room'];
    final deepLink = room is Map ? room['anymexDeepLink']?.toString() : null;
    if (deepLink != null && deepLink.isNotEmpty) {
      final uri = Uri.tryParse(deepLink);
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined Anime Friends room $code.')));
    if (room is Map && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WatchRoomChatScreen(
        code: code,
        roomId: '${room['id'] ?? ''}',
        roomName: '${room['name'] ?? 'Watch Room'}',
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final rooms = appState.rooms;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AFCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 36,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 14),
              const Text(
                'Watch anime together.',
                style: AppTypography.headingMedium,
              ),
              const SizedBox(height: 7),
              const Text(
                'Create a room and invite your friends.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AFButton(
                      label: 'Create Room',
                      icon: Icons.add,
                      expanded: true,
                      onPressed: () => createRoom(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => promptJoinRoom(context),
                      icon: const Icon(Icons.login),
                      label: const Text('Join by code'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (appState.roomError.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            appState.roomError,
            style: const TextStyle(color: AppColors.error),
          ),
        ],
        const SizedBox(height: 26),
        SectionTitle(
          title: 'Available Rooms',
          actionLabel: '${rooms.length} rooms',
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          const EmptyView(
            title: 'No rooms available',
            message: 'Create a room and start watching together.',
            icon: Icons.groups_outlined,
          )
        else
          ...rooms.map((room) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AFCard(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: AppColors.border,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.textPrimary,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Code: ${room.code} • ${room.memberCount} members',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AFButton(
                      label: 'Join',
                      outlined: true,
                      onPressed: () => joinRoom(context, room.code),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog({required this.onCreate});
  final Future<bool> Function(Map<String, String>) onCreate;

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _roomName = TextEditingController(text: 'Anime Night');
  final _animeTitle = TextEditingController();
  final _animeId = TextEditingController();
  final _providerUserId = TextEditingController();
  final _episode = TextEditingController(text: '1');
  final _streamUrl = TextEditingController();
  String _provider = 'anilist';
  bool _busy = false;

  @override
  void dispose() {
    _roomName.dispose();
    _animeTitle.dispose();
    _animeId.dispose();
    _providerUserId.dispose();
    _episode.dispose();
    _streamUrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final created = await widget.onCreate({
      'roomName': _roomName.text.trim(),
      'animeTitle': _animeTitle.text.trim(),
      'animeId': _animeId.text.trim(),
      'provider': _provider,
      'providerUserId': _providerUserId.text.trim(),
      'episodeNumber': _episode.text.trim(),
      'streamUrl': _streamUrl.text.trim(),
    });
    if (!mounted) return;
    if (created) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
      isDense: true,
    );

    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: const Text('Create Watch Together room'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _roomName, decoration: decoration('Room name', Icons.groups_outlined), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a room name' : null),
                const SizedBox(height: 10),
                TextFormField(controller: _animeTitle, decoration: decoration('Anime title', Icons.movie_outlined), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the anime title' : null),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _provider,
                  decoration: decoration('Identity provider', Icons.verified_user_outlined),
                  items: const [
                    DropdownMenuItem(value: 'anilist', child: Text('AniList')),
                    DropdownMenuItem(value: 'mal', child: Text('MyAnimeList')),
                    DropdownMenuItem(value: 'simkl', child: Text('Simkl')),
                  ],
                  onChanged: _busy ? null : (value) => setState(() => _provider = value ?? 'anilist'),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _providerUserId, keyboardType: TextInputType.number, decoration: decoration('Your provider user ID', Icons.badge_outlined), validator: (v) => int.tryParse(v ?? '') == null ? 'Enter your numeric provider ID' : null),
                const SizedBox(height: 10),
                TextFormField(controller: _animeId, keyboardType: TextInputType.number, decoration: decoration('Anime ID in selected provider', Icons.tag), validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a numeric anime ID' : null),
                const SizedBox(height: 10),
                TextFormField(controller: _episode, keyboardType: TextInputType.number, decoration: decoration('Episode number', Icons.play_circle_outline), validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter a valid episode number' : null),
                const SizedBox(height: 10),
                TextFormField(controller: _streamUrl, keyboardType: TextInputType.url, decoration: decoration('Public episode stream URL', Icons.link), validator: (v) { final uri = Uri.tryParse((v ?? '').trim()); return uri == null || !['http', 'https'].contains(uri.scheme) || !uri.hasAuthority ? 'Enter a public HTTP(S) stream URL' : null; }),
                const SizedBox(height: 8),
                const Text('The backend must have Watchium configured and your provider identity approved. Local/private proxy streams cannot be shared.', style: AppTypography.bodySmall),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(onPressed: _busy ? null : submit, icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add), label: Text(_busy ? 'Creating…' : 'Create & open AnymeX')),
      ],
    );
  }
}
