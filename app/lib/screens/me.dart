import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../config.dart';
import '../models.dart';
import '../screens/onboard.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';
import '../widgets/skeleton.dart';

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
        status = sanitizeUi('$e');
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
            const Kicker('Correspondent'),
            const SizedBox(height: 8),
            Text('Me', style: Swa.playfair(size: 32)),
            const SizedBox(height: 8),
            Text(
              'A key on this device, or an injected wallet. Never written to Arkiv.',
              style: Swa.serif(size: 16, color: Swa.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Swa.wash,
                borderRadius: BorderRadius.circular(Swa.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    WalletStore.injected ? 'Connected wallet' : 'In-app wallet',
                    style: Swa.kicker,
                  ),
                  const SizedBox(height: 10),
                  Text(addr, style: Swa.playfair(size: 20, height: 1.3)),
                  if (balance != null) ...[
                    const SizedBox(height: 8),
                    Text('${formatGlm(balance!)} on Arkiv Tiramisu', style: Swa.byline),
                  ],
                  if (WalletStore.aaGroth16 && WalletStore.aaNullifier != null) ...[
                    const SizedBox(height: 16),
                    const VerifiedJournalistBadge(),
                    const SizedBox(height: 10),
                    Text('NULLIFIER', style: Swa.dateline.copyWith(color: Swa.muted)),
                    const SizedBox(height: 4),
                    Mono(WalletStore.aaNullifier!, maxLines: 4),
                  ] else if (WalletStore.aaNullifier != null) ...[
                    const SizedBox(height: 16),
                    const VerifiedJournalistBadge(),
                    const SizedBox(height: 10),
                    Text('NULLIFIER', style: Swa.dateline.copyWith(color: Swa.muted)),
                    const SizedBox(height: 4),
                    Mono(WalletStore.aaNullifier!, maxLines: 3),
                  ],
                  if (WalletStore.journalistKey != null) ...[
                    const SizedBox(height: 8),
                    Text('Journalist entity ${shortAddr(WalletStore.journalistKey!)}', style: Swa.byline),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(children: [
              ActionPill(icon: SwaI.copy, label: 'Copy address', onTap: () => copy(context, addr)),
              ActionPill(icon: SwaI.faucet, label: 'Get GLM', onTap: () => openUrl(Config.faucet)),
              ActionPill(
                icon: SwaI.rotate,
                label: 'Rotate',
                onTap: () async {
                  await WalletStore.generate();
                  setState(() => status = 'New wallet on this device.');
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
            if (loading) const FeedSkeleton(),
            if (!loading && mine.isEmpty)
              const EmptyState(
                title: 'None yet',
                dek: 'Publish from Post — writes go to Arkiv from this wallet.',
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
            if (status != null) ...[const SizedBox(height: 16), Text(sanitizeUi(status!), style: Swa.serif(size: 14, color: Swa.muted))],
          ],
        ],
      ),
    );
  }
}
