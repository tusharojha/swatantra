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

CustomTransitionPage<void> _fadeThrough(GoRouterState state, Widget child, {bool axis = true}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final incoming = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final outgoing = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic);
      final slide = axis
          ? SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(incoming),
              child: child,
            )
          : child;
      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(outgoing),
        child: FadeTransition(opacity: incoming, child: slide),
      );
    },
  );
}

final _router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (c, s) => _fadeThrough(s, const FeedScreen())),
        GoRoute(
          path: '/s/:key',
          pageBuilder: (c, s) => _fadeThrough(s, StoryScreen(entityKey: s.pathParameters['key']!)),
        ),
        GoRoute(
          path: '/verify',
          pageBuilder: (c, s) => _fadeThrough(s, VerifyScreen(root: s.uri.queryParameters['root'])),
        ),
        GoRoute(
          path: '/post',
          pageBuilder: (c, s) => _fadeThrough(s, PostScreen(stage: s.uri.queryParameters['stage']), axis: false),
        ),
        GoRoute(path: '/takedowns', pageBuilder: (c, s) => _fadeThrough(s, const TakedownsScreen())),
        GoRoute(path: '/me', pageBuilder: (c, s) => _fadeThrough(s, const MeScreen())),
        GoRoute(path: '/journalist', pageBuilder: (c, s) => _fadeThrough(s, const JournalistScreen())),
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
              child: const Icon(SwaI.add, size: 28),
            )
          : null,
      body: Column(
        children: [
          if (!composing) Masthead(desktop: desktop, index: index, onNav: (i) => _go(context, i)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
              child: KeyedSubtree(key: ValueKey(location.split('/').take(2).join('/')), child: child),
            ),
          ),
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
                    NavigationDestination(icon: Icon(SwaI.feed), selectedIcon: Icon(SwaI.feedOn), label: 'Feed'),
                    NavigationDestination(icon: Icon(SwaI.verify), selectedIcon: Icon(SwaI.verifyOn), label: 'Verify'),
                    NavigationDestination(icon: Icon(SwaI.post), selectedIcon: Icon(SwaI.postOn), label: 'Post'),
                    NavigationDestination(icon: Icon(SwaI.tracker), selectedIcon: Icon(SwaI.trackerOn), label: 'Tracker'),
                    NavigationDestination(icon: Icon(SwaI.me), selectedIcon: Icon(SwaI.meOn), label: 'Me'),
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
  static const _icons = [SwaI.feed, SwaI.verify, SwaI.post, SwaI.tracker, SwaI.me];
  static const _iconsOn = [SwaI.feedOn, SwaI.verifyOn, SwaI.postOn, SwaI.trackerOn, SwaI.meOn];

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
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    style: Swa.ui(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: index == i ? Swa.magenta : Swa.ink,
                                      spacing: 0.4,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(index == i ? _iconsOn[i] : _icons[i], size: 16, color: index == i ? Swa.magenta : Swa.ink),
                                        const SizedBox(width: 6),
                                        Text(_labels[i]),
                                      ],
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
                        icon: const Icon(SwaI.github, size: 20, color: Swa.ink),
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
