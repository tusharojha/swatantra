import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';

class Kicker extends StatelessWidget {
  final String label;
  final Color color;
  const Kicker(this.label, {super.key, this.color = Swa.magenta});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Swa.kicker.copyWith(color: color),
    );
  }
}

/// Newspaper kicker; kept as AccentChip so older call sites still compile.
class AccentChip extends StatelessWidget {
  final String label;
  final Color color;
  const AccentChip(this.label, {super.key, this.color = Swa.magenta});

  @override
  Widget build(BuildContext context) => Kicker(label, color: color);
}

class ProofBadge extends StatelessWidget {
  const ProofBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return const Kicker('Capture proof');
  }
}

class TestModeBanner extends StatelessWidget {
  final String text;
  const TestModeBanner(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Swa.paper,
        border: Border(
          left: BorderSide(color: Swa.magenta, width: 3),
          top: BorderSide(color: Swa.line),
          right: BorderSide(color: Swa.line),
          bottom: BorderSide(color: Swa.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTE', style: Swa.kicker),
          const SizedBox(height: 8),
          Text(text, style: Swa.serif(size: 14, height: 1.45)),
        ],
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const SoftCard({super.key, required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: Swa.paper,
        border: Border(
          top: BorderSide(color: Swa.line),
          bottom: BorderSide(color: Swa.line),
        ),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

class SectionHead extends StatelessWidget {
  final String kicker;
  final String title;
  final String? dek;
  const SectionHead({super.key, required this.kicker, required this.title, this.dek});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(kicker),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (dek != null) ...[
          const SizedBox(height: 8),
          Text(dek!, style: Swa.serif(size: 15, color: Swa.muted, height: 1.45)),
        ],
      ],
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key});
  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 1, color: Swa.line);
}

class DoubleRule extends StatelessWidget {
  const DoubleRule({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Divider(height: 2, thickness: 2, color: Swa.ink),
        SizedBox(height: 2),
        Divider(height: 1, thickness: 1, color: Swa.ink),
      ],
    );
  }
}

class Mono extends StatelessWidget {
  final String text;
  final int maxLines;
  const Mono(this.text, {super.key, this.maxLines = 2});
  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Swa.muted, height: 1.4),
    );
  }
}

class StoryImage extends StatelessWidget {
  final ArkivEntity story;
  final double? height;
  final double? width;
  final BoxFit fit;
  const StoryImage(this.story, {super.key, this.height, this.width, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final url = story.mediaUrl;
    if (url.isEmpty) return const SizedBox.shrink();
    final w = width ?? double.infinity;
    if (url.startsWith('asset:')) {
      return Image.asset(
        url.substring(6),
        height: height,
        width: w,
        fit: fit,
        filterQuality: FilterQuality.medium,
      );
    }
    return Image.network(
      url,
      height: height,
      width: w,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

String editionDateline([DateTime? now]) {
  now ??= DateTime.now().toUtc();
  const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  const months = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
}

String relativeTime(int ms) {
  if (ms == 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

String journalistByline(ArkivEntity s) {
  final place = s.city.isNotEmpty ? s.city : (s.state.isNotEmpty ? s.state : 'India');
  return 'Verified Journalist · $place · ${relativeTime(s.createdAtMs)}';
}

String standfirst(String body) {
  var clean = body.trim();
  clean = clean.replaceFirst(RegExp(r'^SYNTHETIC[^\n]*\n+'), '');
  final para = clean.split(RegExp(r'\n\s*\n')).first.replaceAll('\n', ' ').trim();
  if (para.length <= 200) return para;
  return '${para.substring(0, 197).trim()}…';
}

Future<void> copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }
}

Future<void> openUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

String shortAddr(String a) {
  if (a.length < 12) return a;
  return '${a.substring(0, 6)}…${a.substring(a.length - 4)}';
}

String explorerTx(String hash) => '${Config.explorer}/tx/$hash';
String explorerAddr(String a) => '${Config.explorer}/address/$a';
String explorerEntity(String key) => '${Config.explorer}/entity/$key';
String protectedLink(String key) => '${Config.pagesBase}/s/$key';
