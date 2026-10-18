import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../config.dart';
import '../models.dart';
import '../screens/onboard.dart';
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
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    if (WalletStore.address != null) {
      try {
        balance = await WalletStore.balanceWei();
        mine = await Arkiv.feed(createdBy: WalletStore.address);
      } catch (e) {
        status = '$e';
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final addr = WalletStore.address;
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
        padding: Swa.pagePadding,
        children: [
          if (addr == null)
            OnboardPanel(onReady: () => _refresh())
          else ...[
            Text('Me', style: Swa.playfair(size: 28)),
            const SizedBox(height: 8),
            Text(
              'A key on this device, or an injected wallet. Never written to Arkiv.',
              style: Swa.serif(size: 16, color: Swa.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            Text(
              WalletStore.injected ? 'Connected wallet' : 'In-app wallet',
              style: Swa.kicker,
            ),
            const SizedBox(height: 8),
            Text(addr, style: Swa.playfair(size: 20, height: 1.3)),
            if (balance != null) ...[
              const SizedBox(height: 8),
              Text('$balance wei ${Config.nativeToken}', style: Swa.byline),
            ],
            if (WalletStore.aaGroth16 && WalletStore.aaNullifier != null) ...[
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(SwaI.journalist, size: 16, color: Swa.magenta),
                  SizedBox(width: 6),
                  Kicker('Proof verified ✓'),
                ],
              ),
              const SizedBox(height: 8),
              Mono(WalletStore.aaNullifier!, maxLines: 4),
            ] else if (WalletStore.aaNullifier != null) ...[
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(SwaI.hash, size: 16, color: Swa.magenta),
                  SizedBox(width: 6),
                  Kicker('Nullifier'),
                ],
              ),
              const SizedBox(height: 8),
              Mono(WalletStore.aaNullifier!, maxLines: 3),
            ],
            if (WalletStore.journalistKey != null) ...[
              const SizedBox(height: 8),
              Text('Journalist entity ${shortAddr(WalletStore.journalistKey!)}', style: Swa.byline),
            ],
            const SizedBox(height: 24),
            Wrap(children: [
              ActionPill(icon: SwaI.copy, label: 'Copy address', onTap: () => copy(context, addr)),
              ActionPill(icon: SwaI.faucet, label: 'Faucet', onTap: () => openUrl(Config.faucet)),
              ActionPill(
                icon: SwaI.rotate,
                label: 'Rotate',
                onTap: () async {
                  await WalletStore.generate();
                  setState(() => status = 'New burner on this device.');
                  await _refresh();
                },
              ),
              ActionPill(
                icon: SwaI.journalist,
                label: WalletStore.aaNullifier == null ? 'Anon Aadhaar' : 'Journalist',
                accent: true,
                onTap: () => context.go('/journalist'),
              ),
            ]),
            const SizedBox(height: 32),
            const Hairline(),
            const SizedBox(height: 24),
            const Kicker('By this desk'),
            const SizedBox(height: 8),
            Text('Stories I created', style: Swa.playfair(size: 24)),
            const SizedBox(height: 12),
            if (loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            if (!loading && mine.isEmpty)
              Text(
                'None yet. Publish from Post — writes go to Arkiv from this wallet.',
                style: Swa.serif(size: 16, color: Swa.muted, height: 1.5),
              ),
            for (var i = 0; i < mine.length; i++) ...[
              InkWell(
                onTap: () => context.go('/s/${mine[i].key}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mine[i].title, style: Swa.playfair(size: 20, height: 1.25)),
                      const SizedBox(height: 6),
                      Text(shortAddr(mine[i].key), style: Swa.byline),
                    ],
                  ),
                ),
              ),
              if (i != mine.length - 1) const Hairline(),
            ],
            if (status != null) ...[const SizedBox(height: 16), Text(status!, style: Swa.serif(size: 14, color: Swa.muted))],
          ],
        ],
      ),
    );
  }
}
