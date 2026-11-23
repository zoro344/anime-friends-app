import 'package:flutter/material.dart';

import 'features/auth/presentation/screens/auth_screen.dart';

import 'app/app_theme.dart';
import 'core/state/app_state.dart';
import 'core/services/supabase_service.dart';
import 'core/state/app_state_scope.dart';
import 'features/feed/presentation/screens/feed_screen.dart';
import 'features/anime/presentation/screens/anime_screen.dart';
import 'features/watch/presentation/screens/watch_screen.dart';
import 'features/chats/presentation/screens/chats_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'features/news/presentation/screens/news_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.initialize();
  } catch (error) {
    debugPrint('Supabase initialization failed: $error');
  }

  runApp(const AnimeFriendsApp());
}

class AnimeFriendsApp extends StatefulWidget {
  const AnimeFriendsApp({
    super.key,
    this.appState,
  });

  final AppState? appState;

  @override
  State<AnimeFriendsApp> createState() => _AnimeFriendsAppState();
}

class _AnimeFriendsAppState extends State<AnimeFriendsApp> {
  late final AppState _appState;
  late final bool _ownsAppState;

  @override
  void initState() {
    super.initState();

    _ownsAppState = widget.appState == null;
    _appState = widget.appState ?? AppState();

    if (_ownsAppState) {
      _appState.initialize();
    }
  }

  @override
  void dispose() {
    if (_ownsAppState) {
      _appState.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anime Friends',
      theme: AppTheme.dark,
      home: AppStateScope(
        state: _appState,
        child: Builder(
          builder: (context) {
            final state = AppStateScope.of(context);

            if (state.isInitializing) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return state.isAuthenticated
                ? const MainScreen()
                : const AuthScreen();
          },
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  static const List<Widget> _pages = [
    FeedScreen(),
    AnimeScreen(),
    WatchScreen(),
    ChatsScreen(),
    ProfileScreen(),
  ];

  static const List<String> _titles = [
    'Anime Friends',
    'Discover Anime',
    'Watch Together',
    'Messages',
    'Your Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Center(
                child: Text(
                  'AF',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _titles[selectedIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Anime News',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NewsScreen(),
              ),
            ),
            icon: const Icon(Icons.newspaper_outlined),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Anime',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Watch',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
