import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../models/anime_item.dart';
import '../models/conversation.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/watch_room.dart';
import '../network/api_client.dart';
import '../services/supabase_service.dart';

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
  bool needsProfileRecovery = false;
  String authError = '';
  String authMessage = '';
  String feedError = '';
  String animeError = '';
  String roomError = '';

  String userId = '';
  String username = 'Anime Friend';
  String displayName = '';
  String handle = '@animefriend';
  String bio = '';
  String? avatarUrl;

  final List<Post> _posts = [];
  List<Post> get posts => List.unmodifiable(_posts);

  final Map<String, List<PostComment>> _commentsByPost = {};
  String commentError = '';

  List<PostComment> commentsForPost(String postId) =>
      List.unmodifiable(_commentsByPost[postId] ?? []);

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
      if (!SupabaseService.isInitialized) {
        authError = SupabaseService.isConfigured
            ? 'Supabase initialization failed. Check the configuration.'
            : 'Supabase is not configured yet. Add the project URL and '
              'publishable key to the app build.';
        return;
      }

      final user = SupabaseService.currentUser;
      if (user != null) {
        await _loadSupabaseProfile(user.id);
        isAuthenticated = true;
        await loadFeed();
      }
    } catch (_) {
      isAuthenticated = false;
      needsProfileRecovery = SupabaseService.currentUser != null;
      authError = needsProfileRecovery
          ? 'Your account is signed in, but your profile could not be loaded. Check your connection and retry.'
          : 'Could not restore your account session. Please sign in again.';
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadSupabaseProfile(String id) async {
    final profile = await SupabaseService.client
        .from('profiles')
        .select('id, username, display_name, bio, avatar_url')
        .eq('id', id)
        .maybeSingle();

    if (profile == null) {
      throw StateError('Your profile has not been created yet.');
    }

    userId = '${profile['id']}';
    username = '${profile['username'] ?? 'Anime Friend'}';
    displayName = '${profile['display_name'] ?? ''}';
    handle = '@$username';
    bio = '${profile['bio'] ?? ''}';
    avatarUrl = profile['avatar_url']?.toString();
  }

  Future<void> retryProfileRecovery() async {
    final user = SupabaseService.currentUser;

    if (user == null) {
      needsProfileRecovery = false;
      authError = 'Your session has expired. Please sign in again.';
      notifyListeners();
      return;
    }

    isBusy = true;
    authError = '';
    notifyListeners();

    try {
      await _loadSupabaseProfile(user.id);
      isAuthenticated = true;
      needsProfileRecovery = false;
      authError = '';
      await loadFeed();
    } catch (_) {
      isAuthenticated = false;
      needsProfileRecovery = true;
      authError =
          'Your profile is still unavailable. Check your connection and try again.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signUp(
    String email,
    String password,
    String usernameInput, [
    String displayName = '',
  ]) async {
    authError = '';
    authMessage = '';

    final normalizedUsername = usernameInput.trim().toLowerCase();

    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalizedUsername)) {
      authError = 'Username must be 3–24 characters using letters, numbers or underscores.';
      notifyListeners();
      return;
    }

    await _performAuth(() async {
      final response = await SupabaseService.instance.signUp(
        email: email,
        password: password,
        username: normalizedUsername,
        displayName: displayName,
      );

      if (response.user == null) {
        throw StateError('Supabase did not return a new user.');
      }

      if (response.session == null) {
        authMessage =
            'Account created. Check your email to verify your address, '
            'then sign in.';
        return;
      }

      await _loadSupabaseProfile(response.user!.id);
      isAuthenticated = true;
      await loadFeed();
    });
  }

  Future<void> signIn(String email, String password) async {
    authError = '';
    authMessage = '';

    await _performAuth(() async {
      final response = await SupabaseService.instance.signIn(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw StateError('Sign-in did not return a user.');
      }

      await _loadSupabaseProfile(user.id);
      isAuthenticated = true;
      await loadFeed();
    });
  }

  Future<void> sendPasswordReset(String email) async {
    authError = '';
    authMessage = '';

    if (email.trim().isEmpty) {
      authError = 'Enter your email address first.';
      notifyListeners();
      return;
    }

    await _performAuth(() async {
      await SupabaseService.instance.sendPasswordReset(email);
      authMessage = 'If the account exists, a password reset email has been sent.';
    });
  }

  Future<void> _performAuth(Future<void> Function() action) async {
    isBusy = true;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      final message = error.toString().toLowerCase();
      needsProfileRecovery = SupabaseService.currentUser != null;

      if (needsProfileRecovery) {
        authError =
            'Your account is signed in, but your profile could not be loaded. Retry below.';
      } else if (message.contains('invalid login credentials') ||
          message.contains('invalid_credentials')) {
        authError = 'Incorrect email or password.';
      } else if (message.contains('email not confirmed')) {
        authError = 'Please verify your email before signing in.';
      } else if (message.contains('user already registered') ||
          message.contains('already been registered')) {
        authError = 'An account with these details already exists.';
      } else if (message.contains('password should be at least') ||
          message.contains('weak_password')) {
        authError = 'Choose a stronger password.';
      } else if (message.contains('23505') ||
          message.contains('profiles_username_lower_unique')) {
        authError = 'That username is already taken.';
      } else if (message.contains('socketexception') ||
          message.contains('failed host lookup') ||
          message.contains('network is unreachable') ||
          message.contains('connection refused')) {
        authError = 'Check your internet connection and try again.';
      } else {
        authError = 'Authentication failed. Please check your details and try again.';
      }
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _applyUser(Map<String, dynamic> user) {
    userId = '${user['id'] ?? ''}';
    username = '${user['username'] ?? 'Anime Friend'}';
    displayName = '${user['display_name'] ?? ''}';
    handle = '@$username';
    bio = '${user['bio'] ?? ''}';
    avatarUrl = (user['avatar_url'] ?? user['avatar'])?.toString();
  }

  Future<void> loadData() async {
    if (!isAuthenticated) {
      return;
    }

    await Future.wait([
      _loadLibrary(),
      _loadRooms(),
      _loadChats(),
      _loadFriends(),
    ]);
    notifyListeners();
  }

  Future<void> loadFeed() async {
    if (!isAuthenticated || !SupabaseService.isInitialized) {
      return;
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_feed_posts',
        params: {'p_limit': 30},
      );

      final rows = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Post.fromSupabase)
          .toList();

      _posts
        ..clear()
        ..addAll(rows);
      feedError = '';
    } catch (_) {
      feedError = 'Could not load the Feed. Please try again.';
    }

    notifyListeners();
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
    if (value.isEmpty || value.length > 4000) {
      return;
    }

    if (!isAuthenticated ||
        userId.isEmpty ||
        !SupabaseService.isInitialized) {
      feedError = 'Please sign in to create a post.';
      notifyListeners();
      return;
    }

    try {
      await SupabaseService.client.from('posts').insert({
        'user_id': userId,
        'content': value,
      });
      await loadFeed();
    } catch (_) {
      feedError = 'Could not publish your post. Please try again.';
      notifyListeners();
    }
  }

  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0 ||
        !isAuthenticated ||
        userId.isEmpty ||
        !SupabaseService.isInitialized) {
      return;
    }

    final wasLiked = _posts[index].liked;

    try {
      final likes = SupabaseService.client.from('post_likes');

      if (wasLiked) {
        await likes
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);
      } else {
        await likes.insert({
          'post_id': postId,
          'user_id': userId,
          'value': 1,
        });
      }

      await loadFeed();
    } catch (_) {
      feedError = 'Could not update your like. Please try again.';
      notifyListeners();
    }
  }


  Future<void> loadComments(String postId) async {
    if (!isAuthenticated || !SupabaseService.isInitialized) {
      commentError = 'Please sign in to view comments.';
      notifyListeners();
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('post_comments')
          .select('*, profiles!post_comments_user_id_fkey(username, display_name)')
          .eq('post_id', postId)
          .order('created_at');

      _commentsByPost[postId] = (response as List)
          .whereType<Map<String, dynamic>>()
          .map(PostComment.fromSupabase)
          .toList();

      commentError = '';
    } catch (_) {
      commentError = 'Could not load comments. Please try again.';
    }
    notifyListeners();
  }

  Future<bool> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    final value = content.trim();

    if (value.isEmpty || value.length > 1500) {
      commentError = 'Comments must be between 1 and 1500 characters.';
      notifyListeners();
      return false;
    }

    if (!isAuthenticated || userId.isEmpty ||
        !SupabaseService.isInitialized) {
      commentError = 'Please sign in to comment.';
      notifyListeners();
      return false;
    }

    commentError = '';

    try {
      await SupabaseService.client.from('post_comments').insert({
        'post_id': postId,
        'user_id': userId,
        'content': value,
        'parent_comment_id': parentCommentId,
      });

      // Saving succeeded, even if a later refresh fails.
      await loadComments(postId);
      await loadFeed();
      return true;
    } catch (_) {
      commentError = 'Could not add your comment. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> editComment(
    String commentId, String postId, String content,
  ) async {
    final value = content.trim();
    if (value.isEmpty || value.length > 1500) return;
    if (!isAuthenticated || !SupabaseService.isInitialized) return;

    try {
      await SupabaseService.client
          .from('post_comments')
          .update({'content': value})
          .eq('id', commentId)
          .eq('user_id', userId);
      await loadComments(postId);
    } catch (_) {
      commentError = 'Could not edit your comment. Please try again.';
      notifyListeners();
    }
  }

  Future<void> deleteComment(String commentId, String postId) async {
    if (!isAuthenticated || !SupabaseService.isInitialized) return;

    try {
      await SupabaseService.client
          .from('post_comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);
      await loadComments(postId);
      await loadFeed();
    } catch (_) {
      commentError = 'Could not delete your comment. Please try again.';
      notifyListeners();
    }
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

  Future<bool> updateProfile({
    required String newUsername,
    required String newDisplayName,
    required String newBio,
  }) async {
    authError = '';

    final normalizedUsername = newUsername.trim().toLowerCase();
    final normalizedDisplayName = newDisplayName.trim();
    final normalizedBio = newBio.trim();

    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalizedUsername)) {
      authError =
          'Username must be 3–24 characters using letters, numbers or underscores.';
      notifyListeners();
      return false;
    }

    if (normalizedDisplayName.length > 40) {
      authError = 'Display name cannot exceed 40 characters.';
      notifyListeners();
      return false;
    }

    if (normalizedBio.length > 150) {
      authError = 'Bio cannot exceed 150 characters.';
      notifyListeners();
      return false;
    }

    if (!SupabaseService.isInitialized || userId.isEmpty) {
      authError = 'Please sign in before editing your profile.';
      notifyListeners();
      return false;
    }

    try {
      final updated = await SupabaseService.client
          .from('profiles')
          .update({
            'username': normalizedUsername,
            'display_name': normalizedDisplayName.isEmpty
                ? null
                : normalizedDisplayName,
            'bio': normalizedBio,
          })
          .eq('id', userId)
          .select('id, username, display_name, bio, avatar_url')
          .single();

      _applyUser(Map<String, dynamic>.from(updated));
      authError = '';
      notifyListeners();
      return true;
    } catch (error) {
      final message = error.toString();

      if (message.contains('23505') ||
          message.contains('profiles_username_lower_unique')) {
        authError = 'That username is already taken.';
      } else {
        authError = 'Could not update your profile. Please try again.';
      }

      notifyListeners();
      return false;
    }
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

    authError = '';
    authMessage = '';

    try {
      if (SupabaseService.isInitialized) {
        await SupabaseService.instance.signOut();

        if (SupabaseService.currentUser != null) {
          authError = 'Your online session is still active. Please try signing out again.';
          notifyListeners();
          return;
        }
      }
    } catch (_) {
      if (SupabaseService.isInitialized &&
          SupabaseService.currentUser != null) {
        authError = 'Could not sign out of your online account. Please try again.';
        notifyListeners();
        return;
      }
    }

    var legacySessionError = '';
    try {
      await api.clearSession();
    } catch (_) {
      legacySessionError = 'Could not clear the previous app session.';
    }

    isAuthenticated = false;
    needsProfileRecovery = false;

    // Clear account-specific state after successful sign-out.
    userId = '';
    username = 'Anime Friend';
    displayName = '';
    handle = '@animefriend';
    bio = '';
    avatarUrl = null;

    authError = legacySessionError;
    authMessage = '';
    feedError = '';
    animeError = '';
    roomError = '';
    roomChatError = '';
    realtimeError = '';
    friendError = '';
    activeRoomId = '';
    roomChatMessages.clear();
    _posts.clear();
    _commentsByPost.clear();
    commentError = '';
    _anime.clear();
    _watchlist.clear();
    _libraryIdsByTitle.clear();
    _rooms.clear();
    _conversations.clear();
    _friends.clear();
    _friendRequests.clear();
    _newsItems.clear();
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    api.dispose();
    super.dispose();
  }
}
