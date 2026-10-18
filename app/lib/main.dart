import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'arkiv/js.dart';
import 'config.dart';
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
      backgroundColor: Swa.paper,
      body: Column(
        children: [
          const Masthead(),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Swa.maxWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Hairline(),
          NavigationBar(
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
        ],
      ),
    );
  }
}

class Masthead extends StatelessWidget {
  const Masthead({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Swa.paper,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Swa.maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        width: 40,
                        height: 40,
                        filterQuality: FilterQuality.medium,
                        semanticLabel: 'Swatantra logo',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Swatantra',
                          style: Swa.playfair(size: 30, weight: FontWeight.w700, height: 1.05),
                        ),
                      ),
                      IconButton(
                        tooltip: 'GitHub',
                        onPressed: () => openUrl(Config.repo),
                        icon: const Icon(Icons.code, size: 20, color: Swa.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const DoubleRule(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${editionDateline()}  ·  INDIA',
                            style: Swa.dateline,
                          ),
                        ),
                        Text(Config.tagline, style: Swa.byline),
                      ],
                    ),
                  ),
                  const Hairline(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
