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
import 'widgets/sheets.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.ensureSemantics();
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
      builder: (context, state, child) => AppShell(
        location: state.uri.path,
        preview: state.uri.queryParameters['preview'],
        child: child,
      ),
      routes: [
        GoRoute(path: '/', pageBuilder: (c, s) => _fadeThrough(s, const FeedScreen())),
        GoRoute(
          path: '/s/:key',
          pageBuilder: (c, s) => _fadeThrough(
            s,
            StoryScreen(entityKey: s.pathParameters['key']!, preview: s.uri.queryParameters['preview']),
          ),
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
        GoRoute(
          path: '/journalist',
          pageBuilder: (c, s) => _fadeThrough(s, JournalistScreen(preview: s.uri.queryParameters['preview'])),
        ),
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
  final String? preview;
  const AppShell({super.key, required this.child, required this.location, this.preview});

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
    final compactChrome = location != '/';
    return Scaffold(
      backgroundColor: composing ? const Color(0xFF111111) : Swa.paper,
      floatingActionButton: (!composing && location == '/' && (preview == null || preview!.isEmpty))
          ? FloatingActionButton(
              onPressed: () => context.go('/post'),
              backgroundColor: Swa.magenta,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(SwaI.add, size: 28),
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              if (!composing)
                Masthead(
                  desktop: desktop,
                  compact: compactChrome,
                  index: index,
                  onNav: (i) => _go(context, i),
                ),
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
          if (preview != null && preview!.isNotEmpty) PreviewHost(kind: preview!),
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
  final bool compact;
  final int index;
  final ValueChanged<int>? onNav;
  const Masthead({super.key, this.desktop = false, this.compact = false, this.index = 0, this.onNav});

  static const _labels = ['Feed', 'Verify', 'Post', 'Tracker', 'Me'];
  static const _icons = [SwaI.feed, SwaI.verify, SwaI.post, SwaI.tracker, SwaI.me];
  static const _iconsOn = [SwaI.feedOn, SwaI.verifyOn, SwaI.postOn, SwaI.trackerOn, SwaI.meOn];

  Widget _nav(BuildContext context) {
    return SingleChildScrollView(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final padH = desktop ? 24.0 : 22.0;
    if (compact) {
      return ColoredBox(
        color: Swa.paper,
        child: SafeArea(
          bottom: false,
          child: PageWidth(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padH, 8, padH - 8, 8),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        width: 28,
                        height: 28,
                        filterQuality: FilterQuality.medium,
                        semanticLabel: 'Swatantra logo',
                      ),
                      const SizedBox(width: 10),
                      Text('Swatantra', style: Swa.playfair(size: 20, weight: FontWeight.w700, height: 1)),
                      const Spacer(),
                      if (desktop)
                        Flexible(child: Align(alignment: Alignment.centerRight, child: _nav(context)))
                      else
                        IconButton(
                          tooltip: 'GitHub',
                          onPressed: () => openUrl(Config.repo),
                          icon: const Icon(SwaI.github, size: 20, color: Swa.ink),
                        ),
                    ],
                  ),
                ),
                const Hairline(),
              ],
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: Swa.paper,
      child: SafeArea(
        bottom: false,
        child: PageWidth(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padH, 16, padH, 0),
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
                      Flexible(child: _nav(context))
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

class PreviewHost extends StatelessWidget {
  final String kind;
  const PreviewHost({super.key, required this.kind});

  static Future<Map<String, dynamic>> _noop(String amount) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return {
      'transferTx': '0xff040c5cbe0064826853e148cafff798cfba75f40cadc83f051cf14d9914b396',
      'entityKey': '0x1aa80cf578f59c6249d054cb452d094141932a6869845c7cb5f1725bbcb30f78',
      'amount': amount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Widget sheet;
    switch (kind) {
      case 'signin':
        sheet = const SignInSheet(action: 'tip this desk');
      case 'tip':
        sheet = TipSheet(storyKey: 'preview', to: '0x68f0ee5526e28e9072a9fa398d91a5a867001645', send: _noop);
      case 'tip-custom':
        sheet = TipSheet(
          storyKey: 'preview',
          to: '0x68f0ee5526e28e9072a9fa398d91a5a867001645',
          send: _noop,
          startCustom: true,
        );
      case 'tip-pending':
        sheet = TipSheet(
          storyKey: 'preview',
          to: '0x68f0ee5526e28e9072a9fa398d91a5a867001645',
          send: _noop,
          previewPending: true,
        );
      case 'tip-success':
        sheet = TipSheet(
          storyKey: 'preview',
          to: '0x68f0ee5526e28e9072a9fa398d91a5a867001645',
          send: _noop,
          previewTx: '0xff040c5cbe0064826853e148cafff798cfba75f40cadc83f051cf14d9914b396',
          previewEntity: '0x1aa80cf578f59c6249d054cb452d094141932a6869845c7cb5f1725bbcb30f78',
        );
      case 'tip-error':
        sheet = TipSheet(
          storyKey: 'preview',
          to: '0x68f0ee5526e28e9072a9fa398d91a5a867001645',
          send: _noop,
          previewError: 'Insufficient funds for GLM transfer on Arkiv Tiramisu.',
        );
      case 'report':
        sheet = const ReportSheet();
      case 'filters':
        sheet = FiltersSheet(
          states: const ['', 'Maharashtra', 'Delhi', 'Karnataka', 'Himachal Pradesh', 'Assam', 'Telangana', 'Uttar Pradesh', 'Tamil Nadu'],
          cats: const ['', 'civic', 'labour', 'environment', 'protest', 'conflict', 'other'],
          state: '',
          category: '',
          corroboratedOnly: false,
          onApply: (s, c, corr) {},
        );
      default:
        return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: sheet,
      ),
    );
  }
}
