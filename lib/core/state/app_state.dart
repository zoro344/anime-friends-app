import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../models/anime_item.dart';
import '../models/manga_item.dart';
import '../models/conversation.dart';
import '../models/post.dart';
import '../models/post_comment.dart';
import '../models/watch_room.dart';
import '../network/api_client.dart';
import '../services/supabase_service.dart';
import '../services/anime_news_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    AnimeFriendsApi? api,
    AnimeNewsService? newsService,
  })  : api = api ?? AnimeFriendsApi(),
        _newsService = newsService ?? AnimeNewsService();

  final AnimeFriendsApi api;
  final AnimeNewsService _newsService;
  int _newsRequestGeneration = 0;
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
  String mangaError = '';
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
  final Map<String, Map<String, dynamic>> _animeLibraryEntriesById = {};
  final Map<String, Map<String, dynamic>> _mangaLibraryEntriesById = {};

  Set<String> get watchlist => Set.unmodifiable(_watchlist);

  List<Map<String, dynamic>> get animeLibraryEntries =>
      _animeLibraryEntriesById.values
          .map((entry) => Map<String, dynamic>.unmodifiable(entry))
          .toList(growable: false);

  List<Map<String, dynamic>> get mangaLibraryEntries =>
      _mangaLibraryEntriesById.values
          .map((entry) => Map<String, dynamic>.unmodifiable(entry))
          .toList(growable: false);

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
      _loadMangaLibrary(),
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
    if (!SupabaseService.isInitialized || userId.isEmpty) return;

    try {
      const pageSize = 200;
      var offset = 0;
      final rows = <Map<String, dynamic>>[];

      while (true) {
        final response = await SupabaseService.client
            .from('anime_library')
            .select(
              'id, anime_id, anime_title, cover_url, status, '
              'episodes_watched, total_episodes, personal_rating, '
              'started_at, completed_at, rewatch_count, priority, notes',
            )
            .eq('user_id', userId)
            .order('id')
            .range(offset, offset + pageSize - 1);

        final page = (response as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList();

        rows.addAll(page);
        if (page.length < pageSize) break;
        offset += pageSize;
      }

      _watchlist.clear();
      _libraryIdsByTitle.clear();
      _animeLibraryEntriesById.clear();

      for (final row in rows) {
        final title = '${row['anime_title'] ?? ''}';
        final animeId = '${row['anime_id'] ?? ''}';
        if (title.isEmpty || animeId.isEmpty) continue;

        _watchlist.add(title);
        _libraryIdsByTitle[title] = animeId;
        _animeLibraryEntriesById[animeId] =
            Map<String, dynamic>.from(row);
      }

      animeError = '';
    } catch (_) {
      animeError = 'Could not load your anime library. Please try again.';
    }
  }

  Future<void> _loadMangaLibrary() async {
    if (!SupabaseService.isInitialized || userId.isEmpty) return;

    try {
      const pageSize = 200;
      var offset = 0;
      final rows = <Map<String, dynamic>>[];

      while (true) {
        final response = await SupabaseService.client
            .from('manga_library')
            .select(
              'id, manga_id, manga_title, cover_url, status, '
              'chapters_read, total_chapters, volumes_read, total_volumes, '
              'personal_rating, started_at, completed_at, '
              'reread_count, priority, notes',
            )
            .eq('user_id', userId)
            .order('id')
            .range(offset, offset + pageSize - 1);

        final page = (response as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList();

        rows.addAll(page);
        if (page.length < pageSize) break;
        offset += pageSize;
      }

      _mangaLibraryEntriesById.clear();

      for (final row in rows) {
        final mangaId = '${row['manga_id'] ?? ''}';
        if (mangaId.isEmpty) continue;

        _mangaLibraryEntriesById[mangaId] =
            Map<String, dynamic>.from(row);
      }

      mangaError = '';
    } catch (_) {
      mangaError = 'Could not load your manga library. Please try again.';
    }
  }

  Future<bool> addMangaToLibrary(MangaItem item) async {
    mangaError = '';

    if (!SupabaseService.isInitialized || userId.isEmpty) {
      mangaError = 'Please sign in before adding manga to your library.';
      notifyListeners();
      return false;
    }

    final mangaId = int.tryParse(item.id);
    if (mangaId == null || mangaId <= 0 || item.name.trim().isEmpty) {
      mangaError = 'This manga has invalid information and cannot be added.';
      notifyListeners();
      return false;
    }

    if (_mangaLibraryEntriesById.containsKey('$mangaId')) {
      mangaError = 'This manga is already in your library.';
      notifyListeners();
      return false;
    }

    try {
      final response = await SupabaseService.client
          .from('manga_library')
          .insert({
            'manga_id': mangaId,
            'manga_title': item.name,
            'cover_url': item.coverUrl,
            'status': 'plan_to_read',
          })
          .select(
            'id, manga_id, manga_title, cover_url, status, '
            'chapters_read, total_chapters, volumes_read, total_volumes, '
            'personal_rating, started_at, completed_at, reread_count, priority, notes',
          )
          .single();

      _mangaLibraryEntriesById['$mangaId'] =
          Map<String, dynamic>.from(response);

      mangaError = '';
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Manga library insert failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      mangaError = 'Could not add this manga. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMangaLibraryEntry({
    required String mangaId,
    String? status,
    int? chaptersRead,
    int? totalChapters,
    int? volumesRead,
    int? totalVolumes,
    int? personalRating,
    int? rereadCount,
    int? priority,
    String? notes,
  }) async {
    mangaError = '';

    if (!SupabaseService.isInitialized || userId.isEmpty) {
      mangaError = 'Please sign in before updating your manga library.';
      notifyListeners();
      return false;
    }

    final parsedId = int.tryParse(mangaId);
    if (parsedId == null || parsedId <= 0) {
      mangaError = 'Invalid manga ID.';
      notifyListeners();
      return false;
    }

    const allowedStatuses = {
      'reading',
      'completed',
      'on_hold',
      'dropped',
      'plan_to_read',
    };

    if (status != null && !allowedStatuses.contains(status)) {
      mangaError = 'Invalid manga reading status.';
      notifyListeners();
      return false;
    }

    if (chaptersRead != null && chaptersRead < 0 ||
        volumesRead != null && volumesRead < 0 ||
        totalChapters != null && totalChapters <= 0 ||
        totalVolumes != null && totalVolumes <= 0 ||
        personalRating != null &&
            (personalRating < 1 || personalRating > 10)) {
      mangaError = 'Check your chapter, volume, and rating values.';
      notifyListeners();
      return false;
    }

    if ((rereadCount != null && rereadCount < 0) ||
        (priority != null && (priority < 1 || priority > 3)) ||
        (notes != null && notes.length > 500)) {
      mangaError = 'Check reread count, priority, and notes (maximum 500 characters).';
      notifyListeners();
      return false;
    }

    final current = _mangaLibraryEntriesById[mangaId];

    if (current == null) {
      mangaError = 'This manga is not in your library.';
      notifyListeners();
      return false;
    }

    final currentChapters = current['chapters_read'] is num
        ? (current['chapters_read'] as num).toInt()
        : 0;
    final currentVolumes = current['volumes_read'] is num
        ? (current['volumes_read'] as num).toInt()
        : 0;
    final effectiveChapters = chaptersRead ?? currentChapters;
    final effectiveVolumes = volumesRead ?? currentVolumes;

    final currentTotalChapters = current['total_chapters'] is num
        ? (current['total_chapters'] as num).toInt()
        : null;
    final currentTotalVolumes = current['total_volumes'] is num
        ? (current['total_volumes'] as num).toInt()
        : null;
    final effectiveTotalChapters =
        totalChapters ?? currentTotalChapters;
    final effectiveTotalVolumes =
        totalVolumes ?? currentTotalVolumes;

    if (effectiveTotalChapters != null &&
            effectiveChapters > effectiveTotalChapters ||
        effectiveTotalVolumes != null &&
            effectiveVolumes > effectiveTotalVolumes) {
      mangaError = 'Reading progress cannot exceed the known total.';
      notifyListeners();
      return false;
    }

    final updates = <String, dynamic>{};

    if (status != null) updates['status'] = status;
    if (chaptersRead != null) updates['chapters_read'] = chaptersRead;
    if (totalChapters != null) updates['total_chapters'] = totalChapters;
    if (volumesRead != null) updates['volumes_read'] = volumesRead;
    if (totalVolumes != null) updates['total_volumes'] = totalVolumes;
    if (personalRating != null) {
      updates['personal_rating'] = personalRating;
    }
    if (rereadCount != null) updates['reread_count'] = rereadCount;
    if (priority != null) updates['priority'] = priority;
    if (notes != null) {
      updates['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    final today = DateTime.now().toIso8601String().split('T').first;
    var effectiveStatus = status ?? current['status']?.toString();

    if (status == null && chaptersRead != null) {
      if (effectiveTotalChapters != null &&
          effectiveChapters >= effectiveTotalChapters) {
        effectiveStatus = 'completed';
      } else if (effectiveStatus == 'completed' &&
          effectiveTotalChapters != null &&
          effectiveChapters < effectiveTotalChapters) {
        effectiveStatus = 'reading';
      } else if (effectiveStatus == 'plan_to_read') {
        effectiveStatus = 'reading';
      }
      if (effectiveStatus != current['status']) {
        updates['status'] = effectiveStatus;
      }
    }

    if ((effectiveStatus == 'reading' ||
            effectiveStatus == 'completed') &&
        current['started_at'] == null) {
      updates['started_at'] = today;
    }

    if (effectiveStatus == 'completed') {
      if (current['completed_at'] == null) {
        updates['completed_at'] = today;
      }
    } else if (status != null ||
        effectiveStatus != current['status']) {
      updates['completed_at'] = null;
    }

    if (updates.isEmpty) return true;

    try {
      final response = await SupabaseService.client
          .from('manga_library')
          .update(updates)
          .eq('manga_id', parsedId)
          .eq('user_id', userId)
          .select('id')
          .maybeSingle();

      if (response == null) {
        mangaError = 'Manga library entry was not found. Please reload.';
        notifyListeners();
        return false;
      }

      _mangaLibraryEntriesById[mangaId] = {
        ...current,
        ...updates,
      };

      mangaError = '';
      notifyListeners();
      return true;
    } catch (_) {
      mangaError = 'Could not update your manga progress. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMangaFromLibrary(String mangaId) async {
    mangaError = '';

    if (!SupabaseService.isInitialized || userId.isEmpty) {
      mangaError = 'Please sign in before editing your manga library.';
      notifyListeners();
      return false;
    }

    final parsedId = int.tryParse(mangaId);
    if (parsedId == null || parsedId <= 0) {
      mangaError = 'Invalid manga ID.';
      notifyListeners();
      return false;
    }

    try {
      await SupabaseService.client
          .from('manga_library')
          .delete()
          .eq('manga_id', parsedId)
          .eq('user_id', userId);

      _mangaLibraryEntriesById.remove(mangaId);
      mangaError = '';
      notifyListeners();
      return true;
    } catch (_) {
      mangaError = 'Could not remove this manga. Please try again.';
      notifyListeners();
      return false;
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
      final client = SupabaseService.client;
      final currentId = SupabaseService.currentUser?.id ?? userId;

      if (currentId.isEmpty) {
        throw StateError('You must be signed in to load friends.');
      }

      final acceptedRows = await client
          .from('friend_requests')
          .select(
            'id,sender_id,receiver_id,'
            'sender:profiles!friend_requests_sender_id_fkey(id,username),'
            'receiver:profiles!friend_requests_receiver_id_fkey(id,username)',
          )
          .eq('status', 'accepted')
          .or('sender_id.eq.$currentId,receiver_id.eq.$currentId');

      final incomingRows = await client
          .from('friend_requests')
          .select(
            'id,sender:profiles!friend_requests_sender_id_fkey(username)',
          )
          .eq('receiver_id', currentId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      _friends
        ..clear()
        ..addAll(acceptedRows.whereType<Map<String, dynamic>>().map((row) {
          final sender = row['sender'] is Map
              ? Map<String, dynamic>.from(row['sender'] as Map)
              : <String, dynamic>{};

          final receiver = row['receiver'] is Map
              ? Map<String, dynamic>.from(row['receiver'] as Map)
              : <String, dynamic>{};

          final otherUser = row['sender_id'] == currentId
              ? receiver
              : sender;

          return {
            'id': '${otherUser['id'] ?? ''}',
            'username': '${otherUser['username'] ?? 'Anime Friend'}',
          };
        }));

      _friendRequests
        ..clear()
        ..addAll(incomingRows.whereType<Map<String, dynamic>>().map((row) {
          final sender = row['sender'] is Map
              ? Map<String, dynamic>.from(row['sender'] as Map)
              : <String, dynamic>{};

          return {
            'id': '${row['id'] ?? ''}',
            'user': sender,
          };
        }));

      friendError = '';
    } catch (error) {
      friendError = 'Could not load friends. Please refresh and try again.';
    }
  }

  Future<bool> sendFriendRequest(String usernameInput) async {
    final targetUsername = usernameInput.trim().toLowerCase();

    if (targetUsername.isEmpty) {
      friendError = 'Enter a username.';
      notifyListeners();
      return false;
    }

    try {
      final client = SupabaseService.client;
      final currentId = SupabaseService.currentUser?.id ?? userId;

      if (currentId.isEmpty) {
        throw StateError('You must be signed in.');
      }

      final target = await client
          .from('profiles')
          .select('id,username')
          .eq('username', targetUsername)
          .maybeSingle();

      if (target == null) {
        friendError = 'No account found with that username.';
        notifyListeners();
        return false;
      }

      final targetId = '${target['id']}';

      if (targetId == currentId) {
        friendError = 'You cannot send a friend request to yourself.';
        notifyListeners();
        return false;
      }

      await client.from('friend_requests').insert({
        'sender_id': currentId,
        'receiver_id': targetId,
      });

      friendError = 'Friend request sent.';
      await _loadFriends();

      if (friendError.isEmpty) {
        friendError = 'Friend request sent.';
      }

      notifyListeners();
      return true;
    } catch (error) {
      final message = error.toString().toLowerCase();

      if (message.contains('friend_requests_unique_active_pair') ||
          message.contains('duplicate key')) {
        friendError = 'A pending request or friendship already exists.';
      } else {
        friendError = 'Could not send friend request. Please try again.';
      }

      notifyListeners();
      return false;
    }
  }

  Future<void> respondToFriendRequest(
    String requestId, {
    required bool accept,
  }) async {
    try {
      final client = SupabaseService.client;
      final currentId = SupabaseService.currentUser?.id ?? userId;

      final updated = await client
          .from('friend_requests')
          .update({'status': accept ? 'accepted' : 'rejected'})
          .eq('id', requestId)
          .eq('receiver_id', currentId)
          .eq('status', 'pending')
          .select('id');

      if (updated.isEmpty) {
        friendError = 'This friend request is no longer available.';
      } else {
        await _loadFriends();
        if (friendError.isEmpty) {
          friendError = accept ? 'Friend request accepted.' : '';
        }
      }
    } catch (error) {
      friendError = 'Could not update this friend request. Please try again.';
    }

    notifyListeners();
  }

  Future<void> removeFriend(String friendId) async {
    try {
      final client = SupabaseService.client;
      final currentId = SupabaseService.currentUser?.id ?? userId;

      if (currentId.isEmpty || friendId.isEmpty || friendId == currentId) {
        friendError = 'Invalid friend selection.';
        notifyListeners();
        return;
      }

      await client
          .from('friend_requests')
          .delete()
          .eq('status', 'accepted')
          .or(
            'and(sender_id.eq.$currentId,receiver_id.eq.$friendId),'
            'and(sender_id.eq.$friendId,receiver_id.eq.$currentId)',
          );

      await _loadFriends();
      if (friendError.isEmpty) {
        friendError = '';
      }
    } catch (error) {
      friendError = 'Could not remove this friend. Please try again.';
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
    final requestId = ++_newsRequestGeneration;

    try {
      final articles = await _newsService.getNews(
        query: query,
        category: category,
      );

      if (requestId != _newsRequestGeneration) return;

      _newsItems
        ..clear()
        ..addAll(articles);
      newsError = '';
    } catch (_) {
      if (requestId != _newsRequestGeneration) return;
      newsError =
          'Could not load anime news. Check your internet connection and retry.';
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

  Future<bool> editPost(String postId, String text) async {
    final value = text.trim();

    if (value.isEmpty || value.length > 4000) {
      feedError = 'Post must contain between 1 and 4000 characters.';
      notifyListeners();
      return false;
    }

    if (!isAuthenticated ||
        userId.isEmpty ||
        !SupabaseService.isInitialized) {
      feedError = 'Please sign in to edit your post.';
      notifyListeners();
      return false;
    }

    try {
      final updated = await SupabaseService.client
          .from('posts')
          .update({'content': value})
          .eq('id', postId)
          .eq('user_id', userId)
          .select('id');

      if (updated.isEmpty) {
        feedError = 'Post not found or you cannot edit it.';
        notifyListeners();
        return false;
      }

      await loadFeed();
      return true;
    } catch (_) {
      feedError = 'Could not edit your post. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    if (!isAuthenticated ||
        userId.isEmpty ||
        !SupabaseService.isInitialized) {
      feedError = 'Please sign in to delete your post.';
      notifyListeners();
      return false;
    }

    try {
      final deleted = await SupabaseService.client
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', userId)
          .select('id');

      if (deleted.isEmpty) {
        feedError = 'Post not found or you cannot delete it.';
        notifyListeners();
        return false;
      }

      await loadFeed();
      return true;
    } catch (_) {
      feedError = 'Could not delete your post. Please try again.';
      notifyListeners();
      return false;
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

    final animeId = int.tryParse(item.id);
    if (!SupabaseService.isInitialized ||
        animeId == null ||
        animeId <= 0 ||
        userId.isEmpty) {
      animeError = 'Could not save this anime. Please try again.';
      notifyListeners();
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('anime_library')
          .insert({
            'anime_id': animeId,
            'anime_title': item.name,
            'cover_url': item.coverUrl,
            'status': 'plan_to_watch',
          })
          .select(
            'id, anime_id, anime_title, cover_url, status, '
            'episodes_watched, total_episodes, personal_rating, '
            'started_at, completed_at, rewatch_count, priority, notes',
          )
          .single();

      _watchlist.add(item.name);
      _libraryIdsByTitle[item.name] = item.id;
      _animeLibraryEntriesById[item.id] =
          Map<String, dynamic>.from(response);

      animeError = '';
    } catch (_) {
      animeError = 'Could not add this anime to your library. Please try again.';
    }

    notifyListeners();
  }

  Future<void> removeFromWatchlist(String title) async {
    final mediaId = _libraryIdsByTitle[title];
    final animeId = int.tryParse(mediaId ?? '');

    if (animeId == null || userId.isEmpty) return;

    try {
      await SupabaseService.client
          .from('anime_library')
          .delete()
          .eq('anime_id', animeId)
          .eq('user_id', userId);

      _watchlist.remove(title);
      _libraryIdsByTitle.remove(title);
      _animeLibraryEntriesById.remove(mediaId);

      animeError = '';
    } catch (_) {
      animeError = 'Could not remove this anime. Please try again.';
    }

    notifyListeners();
  }

  Future<void> updateAnimeLibraryEntry({
    required String animeId,
    String? status,
    int? episodesWatched,
    int? totalEpisodes,
    int? personalRating,
    int? rewatchCount,
    int? priority,
    String? notes,
  }) async {
    animeError = '';

    const allowedStatuses = {
      'watching',
      'completed',
      'on_hold',
      'dropped',
      'plan_to_watch',
    };

    final numericId = int.tryParse(animeId);
    if (!SupabaseService.isInitialized ||
        numericId == null ||
        userId.isEmpty) {
      animeError = 'Please sign in before updating your anime library.';
      notifyListeners();
      return;
    }

    if (status != null && !allowedStatuses.contains(status)) {
      animeError = 'Invalid anime status.';
      notifyListeners();
      return;
    }

    if (episodesWatched != null && episodesWatched < 0) {
      animeError = 'Episode progress cannot be negative.';
      notifyListeners();
      return;
    }

    if (totalEpisodes != null && totalEpisodes <= 0) {
      animeError = 'Total episodes must be greater than zero.';
      notifyListeners();
      return;
    }

    if (personalRating != null &&
        (personalRating < 1 || personalRating > 10)) {
      animeError = 'Rating must be between 1 and 10.';
      notifyListeners();
      return;
    }

    if ((rewatchCount != null && rewatchCount < 0) ||
        (priority != null && (priority < 1 || priority > 3)) ||
        (notes != null && notes.length > 500)) {
      animeError = 'Check rewatch count, priority, and notes (maximum 500 characters).';
      notifyListeners();
      return;
    }

    final currentLibraryEntry = _animeLibraryEntriesById[animeId];
    final currentTotal = currentLibraryEntry?['total_episodes'];
    final currentProgress = currentLibraryEntry?['episodes_watched'];

    final effectiveTotal =
        totalEpisodes ?? (currentTotal is int ? currentTotal : null);
    final effectiveProgress =
        episodesWatched ?? (currentProgress is int ? currentProgress : 0);

    if (effectiveTotal != null && effectiveProgress > effectiveTotal) {
      animeError = 'Watched episodes cannot exceed the total episode count.';
      notifyListeners();
      return;
    }

    final updates = <String, dynamic>{};
    if (status != null) updates['status'] = status;
    if (episodesWatched != null) {
      updates['episodes_watched'] = episodesWatched;
    }
    if (totalEpisodes != null) {
      updates['total_episodes'] = totalEpisodes;
    }
    if (personalRating != null) {
      updates['personal_rating'] = personalRating;
    }
    if (rewatchCount != null) updates['rewatch_count'] = rewatchCount;
    if (priority != null) updates['priority'] = priority;
    if (notes != null) {
      updates['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    final today = DateTime.now().toIso8601String().split('T').first;
    var effectiveStatus =
        status ?? currentLibraryEntry?['status']?.toString();

    if (status == null && episodesWatched != null) {
      if (effectiveTotal != null && effectiveProgress >= effectiveTotal) {
        effectiveStatus = 'completed';
      } else if (effectiveStatus == 'completed' &&
          effectiveTotal != null &&
          effectiveProgress < effectiveTotal) {
        effectiveStatus = 'watching';
      } else if (effectiveStatus == 'plan_to_watch') {
        effectiveStatus = 'watching';
      }
      if (effectiveStatus != currentLibraryEntry?['status']) {
        updates['status'] = effectiveStatus;
      }
    }

    if (effectiveStatus == 'watching' ||
        effectiveStatus == 'completed') {
      if (currentLibraryEntry?['started_at'] == null) {
        updates['started_at'] = today;
      }
    }

    if (effectiveStatus == 'completed') {
      if (currentLibraryEntry?['completed_at'] == null) {
        updates['completed_at'] = today;
      }
    } else if (status != null ||
        effectiveStatus != currentLibraryEntry?['status']) {
      updates['completed_at'] = null;
    }

    if (updates.isEmpty) return;

    try {
      final response = await SupabaseService.client
          .from('anime_library')
          .update(updates)
          .eq('anime_id', numericId)
          .eq('user_id', userId)
          .select('id')
          .maybeSingle();

      if (response == null) {
        animeError = 'Anime not found in your library. Reload and try again.';
        notifyListeners();
        return;
      }

      final entry = _animeLibraryEntriesById[animeId];
      if (entry != null) entry.addAll(updates);

      animeError = '';
    } catch (_) {
      animeError = 'Could not update your anime progress. Please try again.';
    }

    notifyListeners();
  }

  Future<void> markEpisodeWatched({
    required String animeId,
    required int episodeNumber,
  }) async {
    final entry = _animeLibraryEntriesById[animeId];
    final libraryId = entry?['id']?.toString();

    if (libraryId == null || libraryId.isEmpty || userId.isEmpty) {
      animeError = 'Add this anime to your library first.';
      notifyListeners();
      return;
    }

    if (episodeNumber <= 0) {
      animeError = 'Episode number must be greater than zero.';
      notifyListeners();
      return;
    }

    final total = entry?['total_episodes'];
    if (total is num && episodeNumber > total) {
      animeError = 'Episode number exceeds the total episode count.';
      notifyListeners();
      return;
    }

    try {
      animeError = '';
      await SupabaseService.client.from('anime_episode_history').upsert(
        {
          'library_id': libraryId,
          'episode_number': episodeNumber,
        },
        onConflict: 'library_id,episode_number',
        ignoreDuplicates: true,
      );

      final currentProgress = entry?['episodes_watched'];
      final progress =
          currentProgress is num ? currentProgress.toInt() : 0;

      if (episodeNumber > progress) {
        await updateAnimeLibraryEntry(
          animeId: animeId,
          episodesWatched: episodeNumber,
        );
      } else {
        animeError = '';
        notifyListeners();
      }
    } catch (_) {
      animeError = 'Could not record this episode. Please try again.';
      notifyListeners();
    }
  }

  Future<void> markNextEpisodeWatched(String animeId) async {
    final entry = _animeLibraryEntriesById[animeId];
    if (entry == null) {
      animeError = 'Add this anime to your library first.';
      notifyListeners();
      return;
    }

    final current = entry['episodes_watched'];
    final nextEpisode = (current is num ? current.toInt() : 0) + 1;
    await markEpisodeWatched(
      animeId: animeId,
      episodeNumber: nextEpisode,
    );
  }

  Future<void> markChapterRead({
    required String mangaId,
    required int chapterNumber,
  }) async {
    final entry = _mangaLibraryEntriesById[mangaId];
    final libraryId = entry?['id']?.toString();

    if (libraryId == null || libraryId.isEmpty || userId.isEmpty) {
      mangaError = 'Add this manga to your library first.';
      notifyListeners();
      return;
    }

    if (chapterNumber <= 0) {
      mangaError = 'Chapter number must be greater than zero.';
      notifyListeners();
      return;
    }

    final total = entry?['total_chapters'];
    if (total is num && chapterNumber > total) {
      mangaError = 'Chapter number exceeds the total chapter count.';
      notifyListeners();
      return;
    }

    try {
      mangaError = '';
      await SupabaseService.client.from('manga_chapter_history').upsert(
        {
          'library_id': libraryId,
          'chapter_number': chapterNumber,
        },
        onConflict: 'library_id,chapter_number',
        ignoreDuplicates: true,
      );

      final currentProgress = entry?['chapters_read'];
      final progress =
          currentProgress is num ? currentProgress.toInt() : 0;

      if (chapterNumber > progress) {
        await updateMangaLibraryEntry(
          mangaId: mangaId,
          chaptersRead: chapterNumber,
        );
      } else {
        mangaError = '';
        notifyListeners();
      }
    } catch (_) {
      mangaError = 'Could not record this chapter. Please try again.';
      notifyListeners();
    }
  }

  Future<void> markNextChapterRead(String mangaId) async {
    final entry = _mangaLibraryEntriesById[mangaId];
    if (entry == null) {
      mangaError = 'Add this manga to your library first.';
      notifyListeners();
      return;
    }

    final current = entry['chapters_read'];
    final nextChapter = (current is num ? current.toInt() : 0) + 1;
    await markChapterRead(
      mangaId: mangaId,
      chapterNumber: nextChapter,
    );
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
    mangaError = '';
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
    _animeLibraryEntriesById.clear();
    _mangaLibraryEntriesById.clear();
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
    _newsService.dispose();
    api.dispose();
    super.dispose();
  }
}
