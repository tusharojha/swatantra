import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});
  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  String? balance;
  String? status;
  List<ArkivEntity> mine = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (WalletStore.address != null) {
      try {
        balance = await WalletStore.balanceWei();
        mine = await Arkiv.feed(createdBy: WalletStore.address);
      } catch (e) {
        status = '$e';
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _gen() async {
    try {
      await WalletStore.generate();
      setState(() => status =
          'Burner created. Fund it at ${Config.faucet} (10 test GLM). The key never leaves this device.');
      await _refresh();
    } catch (e) {
      setState(() => status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final addr = WalletStore.address;
    return ListView(
      padding: Swa.pagePadding,
      children: [
        const SectionHead(
          kicker: 'Correspondent',
          title: 'Wallet',
          dek:
              'A burner key is generated in this app and stored in local storage. It is never written to Arkiv, never committed, never phoned home.',
        ),
        const SizedBox(height: 16),
        const Kicker('Tiramisu testnet · GLM'),
        const SizedBox(height: 8),
        Text(
          addr == null ? 'No wallet yet' : addr,
          style: Swa.playfair(size: 18, height: 1.3),
        ),
        if (balance != null) ...[
          const SizedBox(height: 8),
          Text('$balance wei GLM', style: Swa.byline),
        ],
        if (WalletStore.aaGroth16 && WalletStore.aaNullifier != null) ...[
          const SizedBox(height: 16),
          const Kicker('Proof verified ✓ (TEST MODE)'),
          const SizedBox(height: 8),
          Text('Proof verified ✓ (TEST MODE)', style: Swa.playfair(size: 20)),
          const SizedBox(height: 8),
          Text('NULLIFIER', style: Swa.dateline.copyWith(color: Swa.muted)),
          const SizedBox(height: 4),
          Mono(WalletStore.aaNullifier!, maxLines: 4),
        ] else if (WalletStore.aaNullifier != null) ...[
          const SizedBox(height: 16),
          const Kicker('Nullifier (stub)'),
          const SizedBox(height: 8),
          Mono(WalletStore.aaNullifier!, maxLines: 3),
        ],
        if (WalletStore.journalistKey != null) ...[
          const SizedBox(height: 8),
          Text('Journalist entity ${shortAddr(WalletStore.journalistKey!)}', style: Swa.byline),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: _gen, child: Text(addr == null ? 'CREATE BURNER' : 'ROTATE BURNER')),
          if (addr != null)
            OutlinedButton(onPressed: () => copy(context, addr), child: const Text('Copy address')),
          OutlinedButton(onPressed: () => openUrl(Config.faucet), child: const Text('Open faucet')),
        ]),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go('/journalist'),
          child: const Text('Journalist onboarding (Anon Aadhaar test mode)'),
        ),
        const SizedBox(height: 24),
        const Hairline(),
        const SizedBox(height: 16),
        const Kicker('By this desk'),
        const SizedBox(height: 8),
        Text('Stories I created', style: Swa.playfair(size: 22)),
        const SizedBox(height: 8),
        if (mine.isEmpty) Text('None yet.', style: Swa.serif(size: 15, color: Swa.muted)),
        for (var i = 0; i < mine.length; i++) ...[
          InkWell(
            onTap: () => context.go('/s/${mine[i].key}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mine[i].title, style: Swa.playfair(size: 18, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(shortAddr(mine[i].key), style: Swa.byline),
                ],
              ),
            ),
          ),
          if (i != mine.length - 1) const Hairline(),
        ],
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
      ],
    );
  }
}
