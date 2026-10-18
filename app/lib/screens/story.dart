import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../models.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Feed'),
        ),
        if (loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        if (error != null) TestModeBanner(error!),
        if (s != null) ...[
          Wrap(spacing: 8, runSpacing: 6, children: [
            AccentChip(s.category.isEmpty ? 'story' : s.category, color: Swa.magenta),
            if (s.city.isNotEmpty) AccentChip('${s.city}, ${s.state}'),
            if (s.hasCapture) const ProofBadge(),
            const AccentChip('Tiramisu testnet', color: Swa.saffron),
          ]),
          const SizedBox(height: 16),
          Text(s.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Published ${s.createdAtMs == 0 ? '—' : DateTime.fromMillisecondsSinceEpoch(s.createdAtMs).toUtc().toIso8601String()}  ·  '
            '\$creator ${shortAddr(s.creator)}',
            style: const TextStyle(color: Swa.muted),
          ),
          const SizedBox(height: 20),
          if (s.mediaUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                s.mediaUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 20),
          Text(s.body, style: const TextStyle(height: 1.55, fontSize: 17)),
          const SizedBox(height: 24),
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Protected link', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'This URL reads the entity straight from Arkiv. A platform takedown does not delete it.',
                style: TextStyle(color: Swa.muted, height: 1.4),
              ),
              const SizedBox(height: 8),
              Mono(protectedLink(s.key), maxLines: 4),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => copy(context, protectedLink(s.key)), child: const Text('Copy link')),
                OutlinedButton(
                  onPressed: () => openUrl(explorerAddr(s.creator)),
                  child: const Text('Creator on explorer'),
                ),
              ]),
              const SizedBox(height: 8),
              Mono('entity ${s.key}', maxLines: 3),
              Mono('creator ${s.creator} · owner ${s.owner}', maxLines: 3),
            ]),
          ),
          if (capture != null) ...[
            const SizedBox(height: 14),
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  ProofBadge(),
                  SizedBox(width: 8),
                  Text('In-app capture chain', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Root ${capture!.attr('chain_root')}  ·  ${capture!.attr('frame_count')} frame(s) at ${capture!.attr('fps')} fps',
                  style: const TextStyle(color: Swa.muted, height: 1.4),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => context.go('/verify?root=${capture!.attr('chain_root')}'),
                  child: const Text('Verify this capture'),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tips  ·  $tipTotal wei test GLM', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Native Tiramisu test token, then a readonly tip entity. Not real money.',
                style: TextStyle(color: Swa.muted),
              ),
              const SizedBox(height: 12),
              TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount (GLM, testnet)')),
              const SizedBox(height: 12),
              FilledButton(onPressed: _tip, child: const Text('Send testnet tip')),
            ]),
          ),
          const SizedBox(height: 14),
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lifetime Extension', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Stories expire after ~180 days. Extension sets a new 180-day life from now (it does not add). Anyone may extend because permissionlessExtension is on.',
                style: TextStyle(color: Swa.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _extend, child: const Text('Keep this story alive')),
            ]),
          ),
          if (status != null) ...[const SizedBox(height: 12), TestModeBanner(status!)],
        ],
      ],
    );
  }
}
