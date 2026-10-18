import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'arkiv/js.dart';
import 'screens/feed.dart';
import 'screens/journalist.dart';
import 'screens/me.dart';
import 'screens/post.dart';
import 'screens/story.dart';
import 'screens/takedowns.dart';
import 'screens/verify.dart';
import 'theme.dart';
import 'wallet.dart';
import 'widgets/bits.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await WalletStore.init();
  if (arkivJsAvailable) {
    try {
      await arkivJs('watchFeed');
    } catch (_) {}
  }
  runApp(const SwatantraApp());
}

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const FeedScreen()),
        GoRoute(
          path: '/s/:key',
          builder: (_, s) => StoryScreen(entityKey: s.pathParameters['key']!),
        ),
        GoRoute(
          path: '/verify',
          builder: (_, s) => VerifyScreen(root: s.uri.queryParameters['root']),
        ),
        GoRoute(path: '/post', builder: (_, __) => const PostScreen()),
        GoRoute(path: '/takedowns', builder: (_, __) => const TakedownsScreen()),
        GoRoute(path: '/me', builder: (_, __) => const MeScreen()),
        GoRoute(path: '/journalist', builder: (_, __) => const JournalistScreen()),
      ],
    ),
  ],
);

class SwatantraApp extends StatelessWidget {
  const SwatantraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Swatantra',
      debugShowCheckedModeBanner: false,
      theme: swatantraTheme(),
      routerConfig: _router,
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  int get index {
    if (location.startsWith('/verify')) return 1;
    if (location.startsWith('/post') || location.startsWith('/journalist')) return 2;
    if (location.startsWith('/takedowns')) return 3;
    if (location.startsWith('/me')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 44,
                      height: 44,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: 'Swatantra logo',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Swatantra', style: Theme.of(context).textTheme.titleLarge),
                        const Text('Ground truth, unerasable.',
                            style: TextStyle(color: Swa.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'GitHub',
                    onPressed: () => openUrl('https://github.com/tusharojha/swatantra'),
                    icon: const Icon(Icons.code),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/verify');
            case 2:
              context.go('/post');
            case 3:
              context.go('/takedowns');
            case 4:
              context.go('/me');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified), label: 'Verify'),
          NavigationDestination(icon: Icon(Icons.edit_outlined), selectedIcon: Icon(Icons.edit), label: 'Post'),
          NavigationDestination(icon: Icon(Icons.policy_outlined), selectedIcon: Icon(Icons.policy), label: 'Tracker'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
