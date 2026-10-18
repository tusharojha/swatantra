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
  final amount = TextEditingController(text: '0.01');
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
        setState(() {
          story = e;
          capture = cap;
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
      setState(() => status = 'Proof edition — tips write to Arkiv once the seeder is funded.');
      return;
    }
    if (WalletStore.address == null) {
      setState(() => status = 'Create a burner wallet in Me first, then fund it on the Tiramisu faucet.');
      return;
    }
    setState(() => status = 'Sending testnet GLM…');
    try {
      final r = await Arkiv.callWrite('createTip', {
        'storyKey': widget.entityKey,
        'to': story!.creator,
        'amountEth': amount.text.trim(),
        'note': 'Swatantra testnet tip',
      });
      setState(() => status = 'Tipped. Transfer ${r['transferTx']} · tip entity ${r['entityKey']}');
      await _load();
    } catch (e) {
      setState(() => status = 'Tip failed: $e');
    }
  }

  Future<void> _extend() async {
    if (proof) {
      setState(() => status = 'Proof edition — Lifetime Extension runs against a live entity.');
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
    return ListView(
      padding: Swa.pagePadding,
      children: [
        TextButton(
          onPressed: () => context.go('/'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          child: Text('← FEED', style: Swa.kicker),
        ),
        const SizedBox(height: 12),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        if (error != null) TestModeBanner(error!),
        if (s != null) ...[
          if (proof) ...[
            TestModeBanner(ProofEdition.banner),
            const SizedBox(height: 12),
            Text('SYNTHETIC DEMO · LAYOUT ONLY · NOT ON-CHAIN', style: Swa.kicker),
            const SizedBox(height: 12),
          ],
          Kicker(s.category.isEmpty ? 'story' : s.category),
          const SizedBox(height: 8),
          Text(s.title, style: Swa.playfair(size: 34, weight: FontWeight.w700, height: 1.12)),
          const SizedBox(height: 12),
          Text(standfirst(s.body), style: Swa.serif(size: 18, height: 1.4, weight: FontWeight.w400)),
          const SizedBox(height: 8),
          Text(journalistByline(s), style: Swa.byline),
          const SizedBox(height: 16),
          if (s.mediaUrl.isNotEmpty) StoryImage(s, height: 200),
          const SizedBox(height: 16),
          Text(s.body, style: Swa.serif(size: 17, height: 1.6)),
          const SizedBox(height: 24),
          _VerifyBlock(story: s, capture: capture, proof: proof),
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Kicker('Support'),
          const SizedBox(height: 8),
          Text('Tip this desk', style: Swa.playfair(size: 22)),
          const SizedBox(height: 8),
          Text(
            'Native Tiramisu test token, then a readonly tip entity. Not real money. $tipTotal wei so far.',
            style: Swa.serif(size: 14, color: Swa.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount (GLM, testnet)')),
          const SizedBox(height: 12),
          FilledButton(onPressed: _tip, child: const Text('SEND TESTNET TIP')),
          const SizedBox(height: 24),
          const Hairline(),
          const SizedBox(height: 16),
          const Kicker('Lifetime'),
          const SizedBox(height: 8),
          Text('Keep this story alive', style: Swa.playfair(size: 22)),
          const SizedBox(height: 8),
          Text(
            'Stories expire after ~180 days. Extension sets a new 180-day life from now (it does not add). Anyone may extend because permissionlessExtension is on.',
            style: Swa.serif(size: 14, color: Swa.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _extend, child: const Text('EXTEND ON ARKIV')),
          if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
        ],
      ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Swa.paper,
        border: Border.all(color: Swa.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('Verification'),
          const SizedBox(height: 8),
          Text('Capture hash + Arkiv entity', style: Swa.playfair(size: 20)),
          const SizedBox(height: 12),
          Text('CAPTURE HASH', style: Swa.dateline.copyWith(color: Swa.muted)),
          const SizedBox(height: 4),
          Mono(hash, maxLines: 4),
          const SizedBox(height: 12),
          Text('ARKIV ENTITY', style: Swa.dateline.copyWith(color: Swa.muted)),
          const SizedBox(height: 4),
          Mono(story.key, maxLines: 3),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => openUrl(entityUrl),
                child: const Text('Open Arkiv entity'),
              ),
              TextButton(
                onPressed: () => copy(context, protectedLink(story.key)),
                child: const Text('Copy protected link'),
              ),
              TextButton(
                onPressed: () => openUrl(explorerAddr(story.creator)),
                child: const Text('Creator on explorer'),
              ),
              if (capture != null)
                TextButton(
                  onPressed: () => context.go('/verify?root=${capture!.attr('chain_root')}'),
                  child: const Text('Verify this capture'),
                ),
            ],
          ),
          if (capture != null) ...[
            const SizedBox(height: 8),
            Text(
              '${capture!.attr('frame_count')} frame(s) at ${capture!.attr('fps')} fps',
              style: Swa.serif(size: 13, color: Swa.muted),
            ),
          ],
        ],
      ),
    );
  }
}
