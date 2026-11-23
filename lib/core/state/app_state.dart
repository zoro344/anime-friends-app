import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../models/anime_item.dart';
import '../models/conversation.dart';
import '../models/post.dart';
import '../models/watch_room.dart';
import '../network/api_client.dart';

class AppState extends ChangeNotifier {
  AppState({AnimeFriendsApi? api}) : api = api ?? AnimeFriendsApi();

  final AnimeFriendsApi api;
  socket_io.Socket? _socket;
  String realtimeError = '';
  int chatEventRevision = 0;
  int roomChatRevision = 0;
  final List<Map<String, dynamic>> roomChatMessages = [];
  String activeRoomId = '';
  String roomChatError = '';

  bool isInitializing = true;
  bool isAuthenticated = false;
  bool isBusy = false;
  String authError = '';
  String feedError = '';
  String animeError = '';
  String roomError = '';

  String userId = '';
  String username = 'Anime Friend';
  String handle = '@animefriend';
  String bio = '';
  String? avatarUrl;

  final List<Post> _posts = [];
  List<Post> get posts => List.unmodifiable(_posts);

  final List<AnimeItem> _anime = [];
  int _animeSearchGeneration = 0;
  List<AnimeItem> get anime => List.unmodifiable(_anime);

  final Set<String> _watchlist = {};
  final Map<String, String> _libraryIdsByTitle = {};
  Set<String> get watchlist => Set.unmodifiable(_watchlist);

  final List<WatchRoom> _rooms = [];
  List<WatchRoom> get rooms => List.unmodifiable(_rooms);

  final List<Conversation> _conversations = [];
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  final List<Map<String, dynamic>> _friends = [];
  final List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> get friendRequests => List.unmodifiable(_friendRequests);
  String friendError = '';
  final List<Map<String, dynamic>> _newsItems = [];
  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationCount => _notifications.where((item) => item['readAt'] == null).length;
  List<Map<String, dynamic>> get newsItems => List.unmodifiable(_newsItems);
  String newsError = '';
  List<Map<String, dynamic>> get friends => List.unmodifiable(_friends);
  int get friendCount => _friends.length;

  int get postCount => _posts.where((post) => post.user == username).length;
  int get animeCount => _watchlist.length;
  String get backendUrl => api.baseUrl;
  bool get isBackendConfigured => api.isConfigured;

  Future<void> initialize() async {
    try {
      await api.restoreSession();
      if (api.isAuthenticated && api.isConfigured) {
        try {
          final response = await api.get('/api/me');
          _applyUser(response['user'] as Map<String, dynamic>);
          isAuthenticated = true;
          await loadData();
          _connectRealtime();
        } on ApiException {
          await api.clearSession();
          isAuthenticated = false;
        }
      }
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> configureBackend(String url) async {
    await api.configure(url);
    authError = '';
    notifyListeners();
  }

  Future<void> signIn(String usernameInput, String password) =>
      _authenticate('/api/auth/login', usernameInput, password);

  Future<void> signUp(String usernameInput, String password) =>
      _authenticate('/api/auth/signup', usernameInput, password);

  Future<void> _authenticate(
    String path,
    String usernameInput,
    String password,
  ) async {
    authError = '';
    if (!api.isConfigured) {
      authError = 'Enter your backend URL first.';
      notifyListeners();
      return;
    }
    isBusy = true;
    notifyListeners();
    try {
      final response = await api.post(path, body: {
        'username': usernameInput.trim(),
        'password': password,
      });
      final token = response['token']?.toString() ?? '';
      if (token.isEmpty || response['user'] is! Map<String, dynamic>) {
        throw const ApiException('The backend returned an incomplete sign-in response.');
      }
      await api.setToken(token);
      _applyUser(response['user'] as Map<String, dynamic>);
      isAuthenticated = true;
      await loadData();
      _connectRealtime();
    } on ApiException catch (error) {
      authError = error.message;
    } catch (_) {
      authError = 'Something went wrong while signing in.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _applyUser(Map<String, dynamic> user) {
    userId = '${user['id'] ?? ''}';
    username = '${user['username'] ?? 'Anime Friend'}';
    handle = '@$username';
    bio = '${user['bio'] ?? ''}';
    avatarUrl = user['avatar']?.toString();
  }

  void _connectRealtime() {
    _socket?.dispose();
    if (!api.isAuthenticated || !api.isConfigured) {
      return;
    }
    final socket = socket_io.io(
      api.baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': api.token})
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      realtimeError = '';
      socket.emit('feed:subscribe');
      notifyListeners();
    });
    socket.onConnectError((_) {
      realtimeError = 'Live updates are temporarily unavailable.';
      notifyListeners();
    });
    socket.on('feed:new-post', (dynamic payload) {
      if (payload is Map) {
        final post = Post.fromJson(Map<String, dynamic>.from(payload));
        if (!_posts.any((item) => item.id == post.id)) {
          _posts.insert(0, post);
        }
        notifyListeners();
      }
    });
    socket.on('feed:post-updated', (dynamic payload) {
      if (payload is Map) {
        final post = Post.fromJson(Map<String, dynamic>.from(payload));
        final index = _posts.indexWhere((item) => item.id == post.id);
        if (index >= 0) {
          final previous = _posts[index];
          _posts[index] = post.copyWith(
            likes: previous.likes,
            comments: previous.comments,
            liked: previous.liked,
          );
        }
        notifyListeners();
      }
    });
    socket.on('feed:post-deleted', (dynamic payload) {
      if (payload is Map && payload['id'] != null) {
        _posts.removeWhere((item) => item.id == '${payload['id']}');
        notifyListeners();
      }
    });
    socket.on('chat:new-message', (_) {
      chatEventRevision++;
      _loadChats().then((_) => notifyListeners());
      loadNotifications();
      notifyListeners();
    });
    socket.on('watch:chat-message', (dynamic payload) {
      if (payload is Map) {
        final message = Map<String, dynamic>.from(payload);
        if ('${message['roomId'] ?? ''}' == activeRoomId &&
            !roomChatMessages.any((item) => item['id'] == message['id'])) {
          roomChatMessages.add(message);
          roomChatRevision++;
          notifyListeners();
        }
      }
    });
    socket.on('watch:closed', (_) {
      roomChatError = 'This room has been closed.';
      notifyListeners();
    });
    socket.on('friend:request', (_) {
      _loadFriends().then((_) => notifyListeners());
      loadNotifications();
    });
    socket.connect();
  }

  Future<void> loadData() async {
    if (!isAuthenticated) {
      return;
    }
    await Future.wait([
      _loadFeed(),
      _loadLibrary(),
      _loadRooms(),
      _loadChats(),
      _loadFriends(),
    ]);
    notifyListeners();
  }

  Future<void> _loadFeed() async {
    try {
      final response = await api.get('/api/posts', query: {'page': '1', 'limit': '30'});
      _posts
        ..clear()
        ..addAll((response['posts'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Post.fromJson));
      feedError = '';
    } on ApiException catch (error) {
      feedError = error.message;
    }
  }

  Future<void> _loadLibrary() async {
    try {
      final response = await api.get('/api/library');
      _watchlist.clear();
      _libraryIdsByTitle.clear();
      for (final item in (response['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()) {
        final title = '${item['title'] ?? ''}';
        final mediaId = '${item['mediaId'] ?? ''}';
        if (title.isNotEmpty && mediaId.isNotEmpty) {
          _watchlist.add(title);
          _libraryIdsByTitle[title] = mediaId;
        }
      }
    } on ApiException {
      // The feed and account remain usable if the library endpoint is unavailable.
    }
  }

  Future<void> _loadRooms() async {
    try {
      final response = await api.get('/api/watch/rooms');
      _rooms
        ..clear()
        ..addAll((response['rooms'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(WatchRoom.fromJson));
      roomError = '';
    } on ApiException catch (error) {
      roomError = error.message;
    }
  }

  Future<void> _loadChats() async {
    try {
      final response = await api.get('/api/chats');
      _conversations
        ..clear()
        ..addAll((response['chats'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Conversation.fromJson));
    } on ApiException {
      // Chat history is an independent feature.
    }
  }

  Future<void> _loadFriends() async {
    try {
      final response = await api.get('/api/friends');
      _friends
        ..clear()
        ..addAll((response['friends'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>());
      final requests = await api.get('/api/friends/requests');
      _friendRequests
        ..clear()
        ..addAll((requests['requests'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>());
      friendError = '';
    } on ApiException catch (error) {
      friendError = error.message;
    }
  }

  Future<bool> sendFriendRequest(String usernameInput) async {
    try {
      await api.post('/api/friends/request', body: {'username': usernameInput.trim()});
      await _loadFriends();
      friendError = 'Friend request sent.';
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      friendError = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> respondToFriendRequest(String requestId, {required bool accept}) async {
    try {
      if (accept) {
        await api.post('/api/friends/requests/${Uri.encodeComponent(requestId)}/accept');
      } else {
        await api.post('/api/friends/requests/${Uri.encodeComponent(requestId)}/reject');
      }
      await _loadFriends();
    } on ApiException catch (error) {
      friendError = error.message;
    }
    notifyListeners();
  }

  Future<void> removeFriend(String friendId) async {
    try {
      await api.delete('/api/friends/${Uri.encodeComponent(friendId)}');
      await _loadFriends();
    } on ApiException catch (error) {
      friendError = error.message;
    }
    notifyListeners();
  }

  Future<void> searchAnime(String query) async {
    final value = query.trim();
    final generation = ++_animeSearchGeneration;
    if (value.isEmpty) {
      _anime.clear();
      animeError = '';
      notifyListeners();
      return;
    }
    try {
      final response = await api.get('/api/anime/search', query: {'q': value});
      if (generation != _animeSearchGeneration) {
        return;
      }
      _anime
        ..clear()
        ..addAll((response['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AnimeItem.fromJson));
      animeError = '';
    } on ApiException catch (error) {
      if (generation == _animeSearchGeneration) {
        animeError = error.message;
      }
    }
    if (generation == _animeSearchGeneration) {
      notifyListeners();
    }
  }

  Future<void> loadNotifications() async {
    try {
      final response = await api.get('/api/notifications');
      _notifications
        ..clear()
        ..addAll((response['notifications'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>());
    } on ApiException {
      // Notifications are optional and must not block the rest of the app.
    }
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    try {
      await api.post('/api/notifications/read');
      for (final item in _notifications) {
        item['readAt'] ??= DateTime.now().toUtc().toIso8601String();
      }
    } on ApiException {
      // Leave unread state intact if the server cannot be reached.
    }
    notifyListeners();
  }

  Future<void> loadNews({String query = '', String category = ''}) async {
    try {
      final parameters = <String, String>{'page': '1', 'limit': '30'};
      if (query.trim().isNotEmpty) parameters['q'] = query.trim();
      if (category.isNotEmpty) {
        parameters['category'] = category;
      }
      final response = await api.get('/api/news', query: parameters);
      _newsItems
        ..clear()
        ..addAll((response['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>());
      newsError = '';
    } on ApiException catch (error) {
      newsError = error.message;
    }
    notifyListeners();
  }

  Future<void> createPost(String text) async {
    final value = text.trim();
    if (value.isEmpty) {
      return;
    }
    try {
      final response = await api.post('/api/posts', body: {'text': value});
      final post = response['post'];
      if (post is Map<String, dynamic>) {
        _posts.insert(0, Post.fromJson(post));
        feedError = '';
      }
    } on ApiException catch (error) {
      feedError = error.message;
    }
    notifyListeners();
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) {
      return;
    }
    try {
      final response = await api.post('/api/posts/$postId/vote', body: {'value': 1});
      final score = (response['score'] as num?)?.toInt() ?? _posts[index].likes;
      _posts[index] = _posts[index].copyWith(
        likes: score,
        liked: !_posts[index].liked,
      );
    } on ApiException catch (error) {
      feedError = error.message;
    }
    notifyListeners();
  }

  Future<void> toggleWatchlist(AnimeItem item) async {
    if (_watchlist.contains(item.name)) {
      await removeFromWatchlist(item.name);
      return;
    }
    try {
      await api.post('/api/library', body: {
        'mediaId': item.id,
        'title': item.name,
        'cover': item.coverUrl,
      });
      _watchlist.add(item.name);
      _libraryIdsByTitle[item.name] = item.id;
      animeError = '';
    } on ApiException catch (error) {
      animeError = error.message;
    }
    notifyListeners();
  }

  Future<void> removeFromWatchlist(String title) async {
    final mediaId = _libraryIdsByTitle[title];
    if (mediaId == null) {
      return;
    }
    try {
      await api.delete('/api/library/${Uri.encodeComponent(mediaId)}');
      _watchlist.remove(title);
      _libraryIdsByTitle.remove(title);
    } on ApiException catch (error) {
      animeError = error.message;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> createIntegratedWatchRoom({
    required String roomName,
    required String provider,
    required String providerUserId,
    required String animeId,
    required String animeTitle,
    required int episodeNumber,
    required String streamUrl,
  }) async {
    roomError = '';
    try {
      final uri = Uri.tryParse(streamUrl.trim());
      if (uri == null || !['http', 'https'].contains(uri.scheme) || !uri.hasAuthority) {
        throw const ApiException('Enter a valid public HTTP(S) episode stream URL.');
      }
      final normalizedProvider = provider.toLowerCase();
      final numericProviderId = int.tryParse(providerUserId.trim());
      final numericAnimeId = int.tryParse(animeId.trim());
      if (numericProviderId == null || numericAnimeId == null) {
        throw const ApiException('Provider user ID and anime ID must be numeric.');
      }
      if (episodeNumber < 1) {
        throw const ApiException('Episode number must be at least 1.');
      }

      // The server keeps the Watchium API secret off the Android client.
      final external = await api.post('/api/watchium/rooms', body: {
        'provider': normalizedProvider,
        'providerUserId': '$numericProviderId',
        'username': username,
        'avatarUrl': avatarUrl,
        'content': {
          'animeId': '$numericAnimeId',
          'animeTitle': animeTitle.trim(),
          'episodeNumber': episodeNumber,
          if (normalizedProvider == 'anilist') 'anilistId': numericAnimeId,
          if (normalizedProvider == 'mal') 'malId': numericAnimeId,
          if (normalizedProvider == 'simkl') 'simklId': numericAnimeId,
          'availableServers': [
            {
              'serverId': 'anime-friends-stream',
              'serverName': 'Selected episode stream',
              'quality': 'Source',
              'type': 'other',
              'url': uri.toString(),
              'originalUrl': uri.toString(),
            }
          ],
        },
      });

      final deepLink = external['deepLink']?.toString() ?? '';
      final watchiumCode = external['code']?.toString() ?? '';
      if (deepLink.isEmpty || watchiumCode.isEmpty) {
        throw const ApiException('Watchium did not return a room code and AnymeX link.');
      }

      // Create the Anime Friends social room and attach the AnymeX room details.
      final social = await api.post('/api/watch/rooms', body: {
        'name': roomName.trim(),
        'animeTitle': animeTitle.trim(),
        'episodeNumber': episodeNumber,
        'watchiumCode': watchiumCode,
        'anymexDeepLink': deepLink,
      });
      final room = social['room'];
      if (room is Map<String, dynamic>) {
        _rooms.insert(0, WatchRoom.fromJson(room));
      }
      roomError = '';
      notifyListeners();
      return {
        'room': room,
        'watchiumCode': watchiumCode,
        'deepLink': deepLink,
      };
    } on ApiException catch (error) {
      roomError = error.message;
    } catch (_) {
      roomError = 'Could not create the integrated Watch Together room.';
    }
    notifyListeners();
    return null;
  }

  Future<void> createRoom(String name) async {
    try {
      final response = await api.post('/api/watch/rooms', body: {'name': name.trim()});
      final room = response['room'];
      if (room is Map<String, dynamic>) {
        _rooms.insert(0, WatchRoom.fromJson(room));
      }
      roomError = '';
    } on ApiException catch (error) {
      roomError = error.message;
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> joinRoom(String code) async {
    try {
      return await api.post('/api/watch/rooms/${Uri.encodeComponent(code.trim())}/join');
    } on ApiException catch (error) {
      roomError = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> openWatchRoomChat(String code, String roomId) async {
    roomChatError = '';
    activeRoomId = roomId;
    roomChatMessages.clear();
    try {
      // Join the live channel before loading history so new messages are not
      // missed between the history request and Socket.IO subscription.
      if (_socket == null || !_socket!.connected) {
        roomChatError = 'Live connection unavailable. Reconnect to use live room chat.';
      } else {
        _socket!.emit('watch:join', {'code': code});
      }
      final response = await api.get('/api/watch/rooms/${Uri.encodeComponent(code)}/messages');
      for (final item in (response['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()) {
        if (!roomChatMessages.any((message) => message['id'] == item['id'])) {
          roomChatMessages.add(item);
        }
      }
      roomChatRevision++;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      roomChatError = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendWatchRoomMessage(String code, String text) async {
    final messageText = text.trim();
    if (messageText.isEmpty) return false;
    if (_socket == null || !_socket!.connected) {
      roomChatError = 'Live connection is unavailable. Message was not sent.';
      notifyListeners();
      return false;
    }
    final completer = Completer<bool>();
    try {
      _socket!.emitWithAck('watch:chat', {'code': code, 'text': messageText},
          ack: (dynamic response) {
        if (response is Map && response['ok'] == true && response['message'] is Map) {
          final message = Map<String, dynamic>.from(response['message'] as Map);
          if (!roomChatMessages.any((item) => item['id'] == message['id'])) {
            roomChatMessages.add(message);
            roomChatRevision++;
          }
          roomChatError = '';
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        } else {
          roomChatError = response is Map
              ? '${response['message'] ?? 'Could not send room message.'}'
              : 'Could not send room message.';
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
        }
      });
      return await completer.future.timeout(const Duration(seconds: 12), onTimeout: () {
        roomChatError = 'The server did not confirm the message. Check your connection.';
        notifyListeners();
        return false;
      });
    } catch (_) {
      roomChatError = 'Could not send room message.';
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({
    required String newUsername,
    required String newBio,
  }) async {
    try {
      final response = await api.patch('/api/me', body: {
        'username': newUsername.trim(),
        'bio': newBio.trim(),
      });
      if (response['user'] is Map<String, dynamic>) {
        _applyUser(response['user'] as Map<String, dynamic>);
      }
    } on ApiException catch (error) {
      authError = error.message;
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> loadMessages(String userId) async {
    try {
      final response = await api.get('/api/chats/${Uri.encodeComponent(userId)}/messages');
      return (response['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } on ApiException catch (error) {
      authError = error.message;
      notifyListeners();
      return [];
    }
  }

  Future<bool> sendMessage(String userId, String text) async {
    try {
      await api.post('/api/chats/${Uri.encodeComponent(userId)}/messages',
          body: {'text': text.trim()});
      return true;
    } on ApiException catch (error) {
      authError = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> markConversationRead(String userId) async {
    try {
      await api.post('/api/chats/${Uri.encodeComponent(userId)}/read');
    } on ApiException {
      // Read receipts are best-effort when offline.
    }
  }

  Future<void> signOut() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    await api.clearSession();
    isAuthenticated = false;
    _posts.clear();
    _anime.clear();
    _watchlist.clear();
    _libraryIdsByTitle.clear();
    _rooms.clear();
    _conversations.clear();
    _friends.clear();
    _friendRequests.clear();
    _newsItems.clear();
    _notifications.clear();
    authError = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    api.dispose();
    super.dispose();
  }
}
