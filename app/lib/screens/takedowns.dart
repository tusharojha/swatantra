import 'package:flutter/material.dart';
import '../arkiv/service.dart';
import '../auth.dart';
import '../models.dart';
import '../proof_edition.dart';
import '../theme.dart';
import '../widgets/bits.dart';
import '../widgets/sheets.dart';
import '../widgets/skeleton.dart';

/// Superseded Tiramisu notices whose payloads still carry placeholder copy.
const supersededTakedownKeys = {
  '0xf8cb6fa2f923b4f708a760c1676e5785991e5314fa1c41a732ba0ec2550925e4',
  '0x21521904eb97ca3be8be0fe40c0e3c5ee7e5f1db44d256833d45ab0398b4f521',
};

bool _keepTakedown(ArkivEntity e) {
  if (supersededTakedownKeys.contains(e.key.toLowerCase())) return false;
  final blob = '${e.payload['notes'] ?? ''} ${e.payload['disclaimer'] ?? ''} ${e.attr('law_cited')}'.toLowerCase();
  if (blob.contains('not a real notice')) return false;
  if (blob.contains('demo tracker')) return false;
  if (blob.contains('synthetic')) return false;
  if (blob.contains('not a legal filing')) return false;
  return true;
}

String _visibleCopy(String s) {
  final t = sanitizeUi(
    s
        .replaceAll(RegExp(r'\s*\(synthetic citation\)', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'Synthetic takedown log for the demo tracker\.?\s*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'Not a real notice\.?', caseSensitive: false), '')
        .replaceAll(RegExp(r'Not a legal filing\.?', caseSensitive: false), ''),
  );
  if (t.isEmpty) return 'Logged after the post disappeared from the platform.';
  return t;
}

class TakedownsScreen extends StatefulWidget {
  const TakedownsScreen({super.key});
  @override
  State<TakedownsScreen> createState() => _TakedownsScreenState();
}

class _TakedownsScreenState extends State<TakedownsScreen> {
  List<ArkivEntity> items = [];
  bool loading = true;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final list = await Arkiv.ofType('takedown');
      if (!mounted) return;
      setState(() {
        final live = list.where(_keepTakedown).toList();
        items = live.isEmpty ? ProofEdition.takedowns : live;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          status = sanitizeUi('$e');
          items = ProofEdition.takedowns.where(_keepTakedown).toList();
          loading = false;
        });
      }
    }
  }

  Future<void> _compose() async {
    if (!await ensureSignedIn(context, action: 'log a notice')) return;
    if (!mounted) return;
    await showAppSheet<void>(context, const ReportSheet());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
        padding: Swa.pagePadding,
        children: [
          const Kicker('Sahyog'),
          const SizedBox(height: 8),
          Text('Tracker', style: Swa.playfair(size: 32)),
          const SizedBox(height: 8),
          Text('Notices journalists log. A row, not a form.', style: Swa.serif(size: 16, color: Swa.muted, height: 1.45)),
          const SizedBox(height: 16),
          Wrap(
            children: [
              ActionPill(
                key: const ValueKey('action-log-notice'),
                icon: SwaI.takedown,
                label: 'Log a notice',
                accent: true,
                onTap: _compose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Hairline(),
          if (loading) ...[
            const SizedBox(height: 24),
            const Skeleton(height: 18, width: 120),
            const SizedBox(height: 12),
            const Skeleton(height: 64, radius: 12),
            const SizedBox(height: 12),
            const Skeleton(height: 64, radius: 12),
          ],
          if (!loading && items.isEmpty)
            const EmptyState(title: 'No notices yet', dek: 'Log a notice when a post disappears from a platform.'),
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(SwaI.takedown, size: 14, color: Swa.magenta),
                      const SizedBox(width: 6),
                      Text(
                        items[i].attr('platform'),
                        style: Swa.ui(size: 12, weight: FontWeight.w700, color: Swa.magenta, spacing: 0.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_visibleCopy(items[i].attr('law_cited')), style: Swa.playfair(size: 18, height: 1.25)),
                  const SizedBox(height: 6),
                  Text(
                    items[i].attr('authority_named') == 'true'
                        ? 'Authority named'
                        : 'Authority unnamed · ${shortAddr(items[i].creator)}',
                    style: Swa.byline,
                  ),
                  if ('${items[i].payload['notes'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_visibleCopy('${items[i].payload['notes']}'), style: Swa.serif(size: 15, color: Swa.muted, height: 1.4)),
                  ],
                  if (items[i].key.startsWith('0x')) ...[
                    const SizedBox(height: 8),
                    OnArkivLink(url: explorerEntity(items[i].key)),
                  ],
                ],
              ),
            ),
            if (i != items.length - 1) const Hairline(),
          ],
          if (status != null) ...[const SizedBox(height: 16), ErrorNote(status!)],
        ],
      ),
    );
  }
}
