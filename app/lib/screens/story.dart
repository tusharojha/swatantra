import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../config.dart';
import '../models.dart';
import '../proof_edition.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';

class StoryScreen extends StatefulWidget {
  final String entityKey;
  const StoryScreen({super.key, required this.entityKey});
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  ArkivEntity? story;
  ArkivEntity? capture;
  String tipTotal = '0';
  String? error;
  bool loading = true;
  bool proof = false;
  Corroboration? cluster;
  final amount = TextEditingController(text: '0.01');
  String tipPreset = '0.01';
  bool customTip = false;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (ProofEdition.isProof(widget.entityKey)) {
      final e = ProofEdition.entity(widget.entityKey);
      setState(() {
        story = e;
        capture = e == null ? null : ProofEdition.captureFor(e.key);
        cluster = e == null ? null : ProofEdition.corroborationFor(e);
        proof = true;
        loading = false;
        if (e == null) error = 'No proof-edition story for this key.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final e = await Arkiv.entity(widget.entityKey);
      ArkivEntity? cap;
      if (e != null && e.captureKey.isNotEmpty) {
        cap = await Arkiv.entity(e.captureKey);
      }
      var total = BigInt.zero;
      final tips = await Arkiv.ofType('tip', eq: {'story_key': widget.entityKey});
      for (final t in tips) {
        total += BigInt.tryParse(t.attr('amount_wei', '0')) ?? BigInt.zero;
      }
      if (mounted) {
        Corroboration? c;
        if (e != null) {
          final district = e.district.isNotEmpty ? e.district : (cap?.district ?? e.city);
          final ts = cap?.captureTsMs ?? e.captureTsMs;
          c = await Arkiv.corroborationFor(district: district, captureTsMs: ts, geoCell: cap?.geoCell ?? e.geoCell);
          if (c != null && c.ok && WalletStore.address != null) {
            try {
              await Arkiv.callWrite('createCorroboration', {
                'district': c.district,
                'geoCell': c.geoCell,
                'windowStartMs': c.windowStart,
                'windowEndMs': c.windowEnd,
                'witnessCount': c.count,
                'storyKey': e.key,
              });
            } catch (_) {}
          }
        }
        setState(() {
          story = e;
          capture = cap;
          cluster = c != null && c.ok ? c : null;
          tipTotal = total.toString();
          loading = false;
          if (e == null) error = 'No live entity for this key. It may have expired.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> _tip() async {
    if (proof) {
      setState(() => status = 'Open a live story to send GLM on Arkiv Tiramisu.');
      return;
    }
    if (WalletStore.address == null) {
      setState(() => status = 'Create a wallet in Me first, then fund it on the Arkiv Tiramisu faucet.');
      return;
    }
    setState(() => status = 'Sending GLM on Arkiv Tiramisu…');
    try {
      final r = await Arkiv.callWrite('createTip', {
        'storyKey': widget.entityKey,
        'to': story!.creator,
        'amountEth': amount.text.trim(),
        'note': 'Swatantra tip',
      });
      setState(() => status = 'Tipped. Transfer ${r['transferTx']} · tip entity ${r['entityKey']}');
      await _load();
    } catch (e) {
      setState(() => status = 'Tip failed: $e');
    }
  }

  Future<void> _extend() async {
    if (proof) {
      setState(() => status = 'Lifetime Extension runs against a live Arkiv Tiramisu entity.');
      return;
    }
    setState(() => status = 'Lifetime Extension…');
    try {
      final r = await Arkiv.callWrite('extendStory', {'entityKey': widget.entityKey});
      setState(() => status = 'Extended. New expiry block ${r['expiresAt']}. Tx ${r['txHash']}');
    } catch (e) {
      setState(() => status = 'Extension failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = story;
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
      padding: Swa.pagePadding,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          icon: const Icon(SwaI.back, size: 16, color: Swa.magenta),
          label: Text('Feed', style: Swa.kicker),
        ),
        const SizedBox(height: 16),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        if (error != null) TestModeBanner(error!),
        if (s != null) ...[
          Kicker(s.category.isEmpty ? 'story' : s.category),
          if (cluster != null) CorroborationStamp(cluster!),
          const SizedBox(height: 12),
          Text(s.title, style: Swa.playfair(size: 34, weight: FontWeight.w700, height: 1.12)),
          const SizedBox(height: 16),
          Text(standfirst(s.body), style: Swa.serif(size: 18, height: 1.45, weight: FontWeight.w400)),
          const SizedBox(height: 12),
          BylineRow(s),
          const SizedBox(height: 24),
          if (s.mediaUrl.isNotEmpty) StoryImage(s, height: 280),
          const SizedBox(height: 24),
          Text(articleRest(s.body), style: Swa.serif(size: 17, height: 1.5)),
          const SizedBox(height: 24),
          _VerifyBlock(story: s, capture: capture, proof: proof),
          if (cluster != null && cluster!.ok) ...[
            const SizedBox(height: 16),
            _WitnessList(cluster: cluster!, proof: proof),
          ],
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          Wrap(
            children: [
              ActionPill(
                icon: SwaI.tip,
                label: 'GLM 0.01',
                selected: !customTip && tipPreset == '0.01',
                onTap: () {
                  setState(() {
                    customTip = false;
                    tipPreset = '0.01';
                    amount.text = '0.01';
                  });
                  _tip();
                },
              ),
              ActionPill(
                icon: SwaI.tip,
                label: 'GLM 0.05',
                selected: !customTip && tipPreset == '0.05',
                onTap: () {
                  setState(() {
                    customTip = false;
                    tipPreset = '0.05';
                    amount.text = '0.05';
                  });
                  _tip();
                },
              ),
              ActionPill(
                icon: SwaI.tip,
                label: 'Custom',
                selected: customTip,
                onTap: () => setState(() => customTip = true),
              ),
              ActionPill(icon: SwaI.extend, label: 'Keep alive', onTap: _extend),
            ],
          ),
          if (customTip) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    decoration: const InputDecoration(
                      hintText: 'GLM',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                ActionPill(icon: SwaI.tip, label: 'Send', accent: true, onTap: _tip),
              ],
            ),
          ],
          if (tipTotal != '0')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$tipTotal wei tipped · GLM on Arkiv Tiramisu', style: Swa.byline),
            ),
          if (status != null) ...[const SizedBox(height: 12), TestModeBanner(status!)],
        ],
      ],
    ),
    );
  }
}

class _VerifyBlock extends StatelessWidget {
  final ArkivEntity story;
  final ArkivEntity? capture;
  final bool proof;
  const _VerifyBlock({required this.story, required this.capture, required this.proof});

  @override
  Widget build(BuildContext context) {
    final hash = capture?.attr('chain_root').isNotEmpty == true
        ? capture!.attr('chain_root')
        : (story.captureRoot.isNotEmpty ? story.captureRoot : '—');
    final entityUrl = proof ? Config.explorer : explorerEntity(story.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(SwaI.hash, size: 16, color: Swa.magenta),
            const SizedBox(width: 6),
            Text('CAPTURE HASH', style: Swa.dateline.copyWith(color: Swa.muted)),
          ],
        ),
        const SizedBox(height: 4),
        Mono(hash, maxLines: 3),
        const SizedBox(height: 12),
        Wrap(
          children: [
            if (capture != null)
              ActionPill(
                icon: SwaI.verify,
                label: 'Verify',
                onTap: () => context.go('/verify?root=${capture!.attr('chain_root')}'),
              ),
            ActionPill(
              icon: SwaI.copy,
              label: 'Copy link',
              onTap: () => copy(context, protectedLink(story.key)),
            ),
            ActionPill(
              icon: SwaI.open,
              label: 'Entity',
              onTap: () => openUrl(entityUrl),
            ),
            ActionPill(
              icon: SwaI.me,
              label: 'Creator',
              onTap: () => openUrl(explorerAddr(story.creator)),
            ),
          ],
        ),
        if (capture != null)
          Text(
            '${capture!.attr('frame_count')} frame(s) · ${capture!.district}',
            style: Swa.byline,
          ),
      ],
    );
  }
}

class _WitnessList extends StatelessWidget {
  final Corroboration cluster;
  final bool proof;
  const _WitnessList({required this.cluster, required this.proof});

  @override
  Widget build(BuildContext context) {
    final witnesses = [...cluster.witnesses]..sort((a, b) => a.captureTs.compareTo(b.captureTs));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Hairline(),
        const SizedBox(height: 16),
        const Kicker('Witnesses'),
        const SizedBox(height: 8),
        Text('${cluster.district} district', style: Swa.playfair(size: 22)),
        const SizedBox(height: 8),
        Text(
          'Independent captures in the same district ±30 minutes. Identity is a nullifier or \$creator, never a name. Precise GPS is never stored.',
          style: Swa.serif(size: 14, color: Swa.muted, height: 1.45),
        ),
        const SizedBox(height: 12),
        _DistrictCell(district: cluster.district, geoCell: cluster.geoCell, n: cluster.count),
        const SizedBox(height: 12),
        for (var i = 0; i < witnesses.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(witnesses[i].anonId, style: Swa.playfair(size: 16, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  '${relativeTime(witnesses[i].captureTs)} · root ${shortAddr(witnesses[i].chainRoot)}',
                  style: Swa.byline,
                ),
                TextButton(
                  onPressed: proof
                      ? null
                      : () => openUrl(explorerEntity(witnesses[i].entityKey)),
                  child: const Text('Open capture entity'),
                ),
              ],
            ),
          ),
          if (i != witnesses.length - 1) const Hairline(),
        ],
      ],
    );
  }
}

/// Coarse 0.1° cell as a labelled mini-map — never a pin.
class _DistrictCell extends StatelessWidget {
  final String district;
  final String geoCell;
  final int n;
  const _DistrictCell({required this.district, required this.geoCell, required this.n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Swa.line)),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Column(
              children: List.generate(3, (r) {
                return Expanded(
                  child: Row(
                    children: List.generate(3, (c) {
                      final centre = r == 1 && c == 1;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          color: centre ? Swa.magenta : Swa.wash,
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(district.toUpperCase(), style: Swa.kicker),
                const SizedBox(height: 6),
                Text('0.1° cell ${geoCell.isEmpty ? '—' : geoCell}', style: Swa.playfair(size: 18, height: 1.2)),
                const SizedBox(height: 6),
                Text('$n independent desks · ±30 min window', style: Swa.serif(size: 13, color: Swa.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
