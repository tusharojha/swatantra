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
  Config.applyLaunch();
  await WalletStore.init();
  if (arkivJsAvailable) {
    try {
      await arkivJs('setNetwork', {'network': Config.network});
    } catch (_) {}
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
        GoRoute(
          path: '/post',
          builder: (_, s) => PostScreen(stage: s.uri.queryParameters['stage']),
        ),
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
    if (location.startsWith('/post')) return 2;
    if (location.startsWith('/takedowns')) return 3;
    if (location.startsWith('/me') || location.startsWith('/journalist')) return 4;
    return 0;
  }

  void _go(BuildContext context, int i) {
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
  }

  @override
  Widget build(BuildContext context) {
    final desktop = Swa.isDesktop(context);
    final composing = location.startsWith('/post');
    return Scaffold(
      backgroundColor: composing ? const Color(0xFF111111) : Swa.paper,
      floatingActionButton: (!composing && location == '/')
          ? FloatingActionButton(
              onPressed: () => context.go('/post'),
              backgroundColor: Swa.magenta,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      body: Column(
        children: [
          if (!composing) Masthead(desktop: desktop, index: index, onNav: (i) => _go(context, i)),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: desktop || composing
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Hairline(),
                NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => _go(context, i),
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
  final bool desktop;
  final int index;
  final ValueChanged<int>? onNav;
  const Masthead({super.key, this.desktop = false, this.index = 0, this.onNav});

  static const _labels = ['Feed', 'Verify', 'Post', 'Tracker', 'Me'];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Swa.paper,
      child: SafeArea(
        bottom: false,
        child: PageWidth(
          child: Padding(
            padding: EdgeInsets.fromLTRB(desktop ? 24 : 22, 16, desktop ? 24 : 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: desktop ? 48 : 40,
                      height: desktop ? 48 : 40,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: 'Swatantra logo',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Swatantra',
                            style: Swa.playfair(size: desktop ? 34 : 30, weight: FontWeight.w700, height: 1.05),
                          ),
                          Text(
                            'स्वतंत्र',
                            style: Swa.serif(size: 15, height: 1.2, color: Swa.muted),
                          ),
                        ],
                      ),
                    ),
                    if (desktop)
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < _labels.length; i++)
                                TextButton(
                                  onPressed: () => onNav?.call(i),
                                  child: Text(
                                    _labels[i],
                                    style: Swa.ui(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: index == i ? Swa.magenta : Swa.ink,
                                      spacing: 0.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'GitHub',
                        onPressed: () => openUrl(Config.repo),
                        icon: const Icon(Icons.code, size: 20, color: Swa.ink),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const DoubleRule(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${editionDateline()}  ·  INDIA',
                              style: Swa.dateline,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${editionDatelineHi()}  ·  भारत',
                              style: Swa.serif(size: 13, color: Swa.muted, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                      Text(Config.tagline, style: Swa.byline),
                    ],
                  ),
                ),
                const DemoLine(),
                const SizedBox(height: 12),
                const Hairline(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
