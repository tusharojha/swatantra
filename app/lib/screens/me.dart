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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text('Wallet', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'A burner key is generated in this app and stored in local storage. It is never written to Arkiv, never committed, never phoned home.',
          style: TextStyle(color: Swa.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AccentChip('Tiramisu testnet · GLM', color: Swa.saffron),
            const SizedBox(height: 12),
            Text(addr == null ? 'No wallet yet' : addr, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (balance != null) Text('$balance wei GLM', style: const TextStyle(color: Swa.muted)),
            if (WalletStore.journalistKey != null) ...[
              const SizedBox(height: 8),
              Text('Journalist entity ${shortAddr(WalletStore.journalistKey!)}',
                  style: const TextStyle(color: Swa.muted, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: _gen, child: Text(addr == null ? 'Create burner' : 'Rotate burner')),
              if (addr != null)
                OutlinedButton(onPressed: () => copy(context, addr), child: const Text('Copy address')),
              OutlinedButton(onPressed: () => openUrl(Config.faucet), child: const Text('Open faucet')),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go('/journalist'),
          child: const Text('Journalist onboarding (Anon Aadhaar test mode)'),
        ),
        const SizedBox(height: 20),
        const Text('Stories I created', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (mine.isEmpty) const Text('None yet.', style: TextStyle(color: Swa.muted)),
        ...mine.map((s) => ListTile(
              title: Text(s.title),
              subtitle: Text(shortAddr(s.key)),
              onTap: () => context.go('/s/${s.key}'),
            )),
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
      ],
    );
  }
}
