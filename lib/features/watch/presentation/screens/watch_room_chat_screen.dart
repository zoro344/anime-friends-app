import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/state/app_state_scope.dart';

class WatchRoomChatScreen extends StatefulWidget {
  const WatchRoomChatScreen({super.key, required this.code, required this.roomId, required this.roomName});
  final String code;
  final String roomId;
  final String roomName;

  @override
  State<WatchRoomChatScreen> createState() => _WatchRoomChatScreenState();
}

class _WatchRoomChatScreenState extends State<WatchRoomChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  AppState? _state;
  int _revision = -1;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (_state == null) {
      _state = state;
      state.addListener(_changed);
      state.openWatchRoomChat(widget.code, widget.roomId);
    }
  }

  void _changed() {
    if (!mounted || _state == null || _revision == _state!.roomChatRevision) return;
    _revision = _state!.roomChatRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
    setState(() {});
  }

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final text = _controller.text;
    final ok = await _state!.sendWatchRoomMessage(widget.code, text);
    if (mounted) {
      if (ok) _controller.clear();
      setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_changed);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final messages = state.roomChatMessages;
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName), bottom: PreferredSize(
        preferredSize: const Size.fromHeight(24),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('ROOM ${widget.code}', style: const TextStyle(color: AppColors.textSecondary, letterSpacing: 1.4)),
        ),
      )),
      body: SafeArea(child: Column(children: [
        if (state.roomChatError.isNotEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(10), color: AppColors.surfaceElevated,
            child: Text(state.roomChatError, style: const TextStyle(color: AppColors.error))),
        Expanded(child: messages.isEmpty
          ? const Center(child: Text('No room messages yet. Say hello!'))
          : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(14), itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final mine = '${message['userId'] ?? ''}' == state.userId;
                return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(color: mine ? AppColors.surfaceElevated : AppColors.surface,
                      border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(15)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${message['username'] ?? 'Member'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 3), Text('${message['text'] ?? ''}'),
                    ]),
                  ));
              })),
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
          Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 4,
            textInputAction: TextInputAction.send, onSubmitted: (_) => _send(),
            decoration: const InputDecoration(hintText: 'Message the room...', border: OutlineInputBorder()))),
          const SizedBox(width: 8), IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
        ])),
      ])),
    );
  }
}
