import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';

/// Outlined Material icons, Lucide-style stroke, one size.
class SwaI {
  static const size = 18.0;
  static const feed = Icons.auto_stories_outlined;
  static const feedOn = Icons.auto_stories;
  static const verify = Icons.verified_outlined;
  static const verifyOn = Icons.verified;
  static const post = Icons.edit_outlined;
  static const postOn = Icons.edit;
  static const tracker = Icons.gavel_outlined;
  static const trackerOn = Icons.gavel;
  static const me = Icons.person_outline;
  static const meOn = Icons.person;
  static const corroborated = Icons.groups_outlined;
  static const journalist = Icons.verified_user_outlined;
  static const hash = Icons.link;
  static const sealed = Icons.check_circle_outlined;
  static const tip = Icons.payments_outlined;
  static const takedown = Icons.report_outlined;
  static const place = Icons.location_on_outlined;
  static const time = Icons.schedule_outlined;
  static const copy = Icons.content_copy_outlined;
  static const open = Icons.open_in_new;
  static const extend = Icons.update_outlined;
  static const wallet = Icons.account_balance_wallet_outlined;
  static const key = Icons.vpn_key_outlined;
  static const camera = Icons.photo_camera_outlined;
  static const add = Icons.add;
  static const back = Icons.arrow_back;
  static const close = Icons.close;
  static const github = Icons.code;
  static const faucet = Icons.water_drop_outlined;
  static const rotate = Icons.sync_outlined;
}

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

class CorroborationStamp extends StatelessWidget {
  final Corroboration cluster;
  const CorroborationStamp(this.cluster, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!cluster.ok) return const SizedBox.shrink();
    final times = cluster.witnesses.map((w) => w.captureTs).toList()..sort();
    final t = DateTime.fromMillisecondsSinceEpoch(times.isEmpty ? 0 : times.first).toUtc();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final line =
        'Corroborated · ${cluster.count} independent witnesses · ${cluster.district} · ${t.day} ${months[t.month - 1]} $hh:$mm';
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(SwaI.corroborated, size: 16, color: Swa.magenta),
          const SizedBox(width: 6),
          Expanded(
            child: Text(line.toUpperCase(), style: Swa.kicker),
          ),
        ],
      ),
    );
  }
}

class ProofBadge extends StatelessWidget {
  const ProofBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return const Kicker('Capture proof');
  }
}

class DemoLine extends StatelessWidget {
  const DemoLine({super.key});
  static const text =
      '';

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class TestModeBanner extends StatelessWidget {
  final String text;
  const TestModeBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Swa.serif(size: 14, color: Swa.muted, height: 1.45)),
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
          const SizedBox(height: 12),
          Text(dek!, style: Swa.serif(size: 16.5, color: Swa.muted, height: 1.5)),
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

/// Compact icon + label pill for actions (tip, verify, notice).
class ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool accent;
  const ActionPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? Swa.magenta
        : (selected ? Swa.ink : Swa.muted);
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? (accent ? const Color(0x14DC2460) : Swa.wash) : Swa.paper,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? (accent ? Swa.magenta : Swa.ink) : Swa.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Swa.ui(size: 13, weight: FontWeight.w600, color: color, spacing: 0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BylineRow extends StatelessWidget {
  final ArkivEntity story;
  const BylineRow(this.story, {super.key});

  @override
  Widget build(BuildContext context) {
    final district = story.district.isNotEmpty ? story.district : (story.city.isNotEmpty ? story.city : 'India');
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(deskIdFor(story.creator), style: Swa.byline),
        _meta(SwaI.place, '$district district'),
        _meta(SwaI.time, relativeTime(story.createdAtMs)),
      ],
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Swa.muted),
        const SizedBox(width: 4),
        Text(text, style: Swa.byline),
      ],
    );
  }
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
      style: Swa.ui(size: 12, color: Swa.muted, weight: FontWeight.w400, height: 1.4, spacing: 0),
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
    Widget image;
    if (url.startsWith('asset:')) {
      image = Image.asset(
        url.substring(6),
        height: height,
        width: w,
        fit: fit,
        filterQuality: FilterQuality.medium,
      );
    } else {
      image = Image.network(
        url,
        height: height,
        width: w,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) {
          final asset = assetForStory(story);
          if (asset == null) return const SizedBox.shrink();
          return Image.asset(asset, height: height, width: w, fit: fit, filterQuality: FilterQuality.medium);
        },
      );
    }
    return Hero(
      tag: 'still-${story.key}',
      flightShuttleBuilder: (context, anim, direction, from, to) => to.widget,
      child: Material(type: MaterialType.transparency, child: image),
    );
  }
}

String? assetForStory(ArkivEntity s) {
  final m = s.mediaUrl;
  final name = m.split('/').last;
  if (RegExp(r'^s\d+\.jpg$').hasMatch(name)) return 'web/seed/$name';
  final id = RegExp(r's(\d+)').firstMatch(s.key);
  if (id != null) return 'web/seed/s${id.group(1)}.jpg';
  return null;
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

/// Devanagari dateline so Noto Serif Devanagari is exercised on every page.
String editionDatelineHi([DateTime? now]) {
  now ??= DateTime.now().toUtc();
  const days = ['सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार'];
  const months = [
    'जनवरी',
    'फ़रवरी',
    'मार्च',
    'अप्रैल',
    'मई',
    'जून',
    'जुलाई',
    'अगस्त',
    'सितंबर',
    'अक्तूबर',
    'नवंबर',
    'दिसंबर',
  ];
  const digits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
  String dn(int n) => n.toString().split('').map((c) => digits[int.parse(c)]).join();
  return '${days[now.weekday - 1]}, ${dn(now.day)} ${months[now.month - 1]} ${dn(now.year)}';
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

const _desks = {
  '0x2e1733523b5704cf431378618cc5e74bb1248997': 'Desk MH-A',
  '0xf96c7f67f72301038ec538e422e0d52e7dd81ccf': 'Desk DL-B',
  '0x68f0ee5526e28e9072a9fa398d91a5a867001645': 'Desk ML-C',
};

String deskIdFor(String creator) {
  return _desks[creator.toLowerCase()] ?? 'Desk ${shortAddr(creator)}';
}

String journalistByline(ArkivEntity s) {
  final district = s.district.isNotEmpty ? s.district : (s.city.isNotEmpty ? s.city : 'India');
  return '${deskIdFor(s.creator)} · $district district · ${relativeTime(s.createdAtMs)}';
}

String standfirst(String body) {
  final para = articleBody(body).split(RegExp(r'\n\s*\n')).first.replaceAll('\n', ' ').trim();
  if (para.length <= 220) return para;
  return '${para.substring(0, 217).trim()}…';
}

String articleBody(String body) {
  var clean = body.trim();
  clean = clean.replaceFirst(RegExp(r'^SYNTHETIC[^\n]*\n+', caseSensitive: false), '');
  return clean;
}

/// Paragraphs after the standfirst, so the article does not repeat the dek.
String articleRest(String body) {
  final parts = articleBody(body).split(RegExp(r'\n\s*\n'));
  if (parts.length < 2) return '';
  return parts.skip(1).join('\n\n');
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
