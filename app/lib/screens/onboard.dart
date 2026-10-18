import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';

/// Phone-first login: one-tap Create wallet, then Connect wallet
/// (injected MetaMask on desktop web, MetaMask deep link on phone).
/// WalletConnect / Reown needs a projectId; without it we fall back.
class OnboardPanel extends StatefulWidget {
  final VoidCallback? onReady;
  const OnboardPanel({super.key, this.onReady});

  @override
  State<OnboardPanel> createState() => _OnboardPanelState();
}

class _OnboardPanelState extends State<OnboardPanel> {
  String? status;
  bool busy = false;
  bool showImport = false;
  final importCtrl = TextEditingController();

  @override
  void dispose() {
    importCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await WalletStore.generate();
      widget.onReady?.call();
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Wallet on this device. Next: Anon Aadhaar.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { busy = false; status = '$e'; });
    }
  }

  Future<void> _import() async {
    final pk = importCtrl.text.trim();
    if (!pk.startsWith('0x') || pk.length < 66) {
      setState(() => status = 'Paste a 0x-prefixed private key. It stays on this device.');
      return;
    }
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await WalletStore.importKey(pk);
      importCtrl.clear();
      widget.onReady?.call();
      if (mounted) {
        setState(() {
          busy = false;
          showImport = false;
          status = 'Key imported. Next: Anon Aadhaar.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { busy = false; status = '$e'; });
    }
  }

  Future<void> _connect() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await WalletStore.connectInjected();
      widget.onReady?.call();
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Connected. Tiramisu chain added. Next: Anon Aadhaar.';
        });
      }
    } catch (e) {
      final msg = '$e';
      if (msg.contains('NO_INJECTED') || msg.contains('No injected')) {
        if (kIsWeb) {
          final dapp = Uri.base.hasAuthority
              ? 'https://metamask.app.link/dapp/${Uri.base.host}${Uri.base.path}'
              : Config.pagesBase;
          try {
            await openUrl(dapp);
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            busy = false;
            status = Config.walletConnectProjectId.isEmpty
                ? 'No injected wallet. Create wallet works on this phone. WalletConnect needs WALLETCONNECT_PROJECT_ID (Reown) — falling back to the in-app burner.'
                : 'No injected wallet. Trying WalletConnect…';
          });
        }
        if (Config.walletConnectProjectId.isNotEmpty) {
          try {
            await WalletStore.connectWalletConnect(Config.walletConnectProjectId);
            widget.onReady?.call();
            if (mounted) setState(() { busy = false; status = 'WalletConnect ready.'; });
            return;
          } catch (e2) {
            if (mounted) setState(() { busy = false; status = 'WalletConnect unavailable: $e2. Create wallet instead.'; });
          }
        }
        return;
      }
      if (mounted) setState(() { busy = false; status = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHead(
          kicker: 'Correspondent',
          title: 'Start writing',
          dek:
              'Reading needs no login. A wallet is only for posting, tipping, and registering a desk. The default is a one-tap burner saved on this device — never on Arkiv.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : _create,
          child: Text(busy ? 'Working…' : 'Create wallet'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy ? null : _connect,
          child: const Text('Connect wallet'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy ? null : () => setState(() => showImport = !showImport),
          child: Text(showImport ? 'Hide import' : 'Import key'),
        ),
        if (showImport) ...[
          const SizedBox(height: 8),
          TextField(
            controller: importCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Private key (0x…) — stays on this device',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : _import,
            child: const Text('Import on this device'),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          kIsWeb
              ? 'Desktop: Connect wallet uses an injected wallet (MetaMask) and adds Tiramisu (7738577). Phone: Create wallet, or Import key. WalletConnect is skipped unless WALLETCONNECT_PROJECT_ID is set at build time.'
              : 'On this phone, Create wallet is the fastest path. Import a key if you already have a funded burner.',
          style: Swa.ui(size: 13, color: Swa.muted, weight: FontWeight.w400, height: 1.45),
        ),
        if (status != null) ...[
          const SizedBox(height: 16),
          Text(status!, style: Swa.serif(size: 15, color: Swa.muted, height: 1.45)),
        ],
        if (WalletStore.address != null) ...[
          const SizedBox(height: 24),
          const Hairline(),
          const SizedBox(height: 24),
          const Kicker('Next'),
          const SizedBox(height: 8),
          Text('Anon Aadhaar', style: Swa.playfair(size: 22)),
          const SizedBox(height: 8),
          Text(
            'Prove 18+ / Indian resident without putting a name on Arkiv. Then you can file a dispatch.',
            style: Swa.serif(size: 16, color: Swa.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/journalist'),
            child: const Text('Continue to Anon Aadhaar'),
          ),
        ],
      ],
    );
  }
}
