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
          Text('Posts that disappeared, logged by the desk that filed them.', style: Swa.serif(size: 16, color: Swa.muted, height: 1.45)),
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
            _NoticeCard(items[i]),
            if (i != items.length - 1) const Hairline(),
          ],
          if (status != null) ...[const SizedBox(height: 16), ErrorNote(status!)],
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final ArkivEntity item;
  const _NoticeCard(this.item);

  int get _when {
    final notice = int.tryParse(item.attr('notice_date_ms', '0')) ?? 0;
    if (notice > 0) return notice;
    return item.createdAtMs;
  }

  @override
  Widget build(BuildContext context) {
    final platform = item.attr('platform');
    final law = _visibleCopy(item.attr('law_cited'));
    final notes = _visibleCopy('${item.payload['notes'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Swa.wash,
                  borderRadius: BorderRadius.circular(Swa.radiusSm),
                  border: Border.all(color: Swa.line),
                ),
                child: Icon(platformIcon(platform), size: 18, color: Swa.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(platform.isEmpty ? 'Platform' : platform, style: Swa.ui(size: 14, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(relativeTime(_when), style: Swa.byline),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x14DC2460),
                  borderRadius: BorderRadius.circular(Swa.radiusPill),
                  border: Border.all(color: const Color(0x33DC2460)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(SwaI.removed, size: 13, color: Swa.magenta),
                    const SizedBox(width: 6),
                    Text('Removed', style: Swa.ui(size: 12, weight: FontWeight.w700, color: Swa.magenta, spacing: 0.2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            notes.isEmpty ? 'Logged after the post disappeared from the platform.' : notes,
            style: Swa.playfair(size: 18, height: 1.28),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (law.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Swa.line),
                    borderRadius: BorderRadius.circular(Swa.radiusPill),
                  ),
                  child: Text(law, style: Swa.ui(size: 12, weight: FontWeight.w600, color: Swa.inkSoft)),
                ),
              if (item.attr('authority_named') == 'true')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Swa.wash,
                    borderRadius: BorderRadius.circular(Swa.radiusPill),
                  ),
                  child: Text('Authority named', style: Swa.ui(size: 12, weight: FontWeight.w600, color: Swa.muted)),
                ),
            ],
          ),
          if (item.key.startsWith('0x')) ...[
            const SizedBox(height: 12),
            OnArkivLink(url: explorerEntity(item.key)),
          ],
        ],
      ),
    );
  }
}
