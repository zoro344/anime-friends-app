import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/state/app_state_scope.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  final String userId;
  final String username;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String _error = '';
  bool _started = false;
  AppState? _appState;
  int _lastChatRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (!_started) {
      _started = true;
      _appState = state;
      _lastChatRevision = state.chatEventRevision;
      state.addListener(_onAppStateChanged);
      _refresh();
    }
  }

  void _onAppStateChanged() {
    final revision = _appState!.chatEventRevision;
    if (revision != _lastChatRevision && mounted) {
      _lastChatRevision = revision;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final state = AppStateScope.of(context);
    setState(() {
      _loading = true;
      _error = '';
    });
    final messages = await state.loadMessages(widget.userId);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
      _error = messages.isEmpty ? state.authError : '';
    });
    await state.markConversationRead(widget.userId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await AppStateScope.of(context).sendMessage(widget.userId, text);
    if (!mounted) return;
    if (sent) {
      _controller.clear();
      await _refresh();
    } else {
      setState(() => _error = AppStateScope.of(context).authError);
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AppStateScope.of(context).userId;
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty && _error.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Start the conversation.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_error.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_error.isNotEmpty && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _error,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            );
                          }
                          final offset = _error.isNotEmpty ? 1 : 0;
                          final message = _messages[index - offset];
                          final mine = message['fromUserId'] == currentUserId;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? AppColors.surfaceElevated
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '${message['text'] ?? ''}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
