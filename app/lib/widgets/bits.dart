import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../theme.dart';

class AccentChip extends StatelessWidget {
  final String label;
  final Color color;
  const AccentChip(this.label, {super.key, this.color = Swa.teal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }
}

class ProofBadge extends StatelessWidget {
  const ProofBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return const AccentChip('Capture proof', color: Swa.teal);
  }
}

class TestModeBanner extends StatelessWidget {
  final String text;
  const TestModeBanner(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14F47C20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Swa.saffron.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: const TextStyle(color: Swa.ink, height: 1.4)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Swa.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Swa.line),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: body);
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
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Swa.muted),
    );
  }
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
String protectedLink(String key) => '${Config.pagesBase}/s/$key';
