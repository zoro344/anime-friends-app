import 'package:flutter/material.dart';

void main() {
  runApp(const AnimeFriendsApp());
}

class AnimeFriendsApp extends StatelessWidget {
  const AnimeFriendsApp({super.key});

  static const violet = Color(0xFF9B72FF);
  static const background = Color(0xFF08070B);
  static const surface = Color(0xFF17131F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anime Friends',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: violet,
          brightness: Brightness.dark,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: Color(0xFF39275B),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  static const pages = [
    EmptyPage(
      title: 'Your feed is quiet',
      message: 'Posts from your friends will appear here.',
      icon: Icons.dynamic_feed_outlined,
    ),
    EmptyPage(
      title: 'Anime catalogue',
      message: 'Anime search and real catalogue data are not connected yet.',
      icon: Icons.movie_outlined,
    ),
    EmptyPage(
      title: 'Watch Together',
      message: 'Room creation and playback synchronization are not connected yet.',
      icon: Icons.groups_outlined,
    ),
    EmptyPage(
      title: 'Your chats',
      message: 'Your conversations will appear here after messaging is connected.',
      icon: Icons.chat_bubble_outline,
    ),
    EmptyPage(
      title: 'Your profile',
      message: 'Sign in and profile services are not connected yet.',
      icon: Icons.person_outline,
    ),
  ];

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.dynamic_feed_outlined),
      selectedIcon: Icon(Icons.dynamic_feed),
      label: 'Feed',
    ),
    NavigationDestination(
      icon: Icon(Icons.movie_outlined),
      selectedIcon: Icon(Icons.movie),
      label: 'Anime',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: AnimeFriendsApp.violet,
              size: 25,
            ),
            SizedBox(width: 10),
            Text(
              'Anime Friends',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: pages[selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: destinations,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
      ),
    );
  }
}

class EmptyPage extends StatelessWidget {
  const EmptyPage({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF21182F),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 34,
                color: AnimeFriendsApp.violet,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
