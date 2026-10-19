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
                ? 'No injected wallet. Create wallet works on this phone.'
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
            if (mounted) setState(() { busy = false; status = 'WalletConnect unavailable. Create wallet instead.'; });
          }
        }
        return;
      }
      if (mounted) setState(() { busy = false; status = msg; });
    }
  }

  Widget _bullet(IconData icon, String title, String dek) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Swa.wash,
              borderRadius: BorderRadius.circular(Swa.radiusSm),
              border: Border.all(color: Swa.line),
            ),
            child: Icon(icon, size: 18, color: Swa.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Swa.ui(size: 14, weight: FontWeight.w700, spacing: 0.1)),
                const SizedBox(height: 2),
                Text(dek, style: Swa.serif(size: 14, color: Swa.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Kicker('Correspondent'),
        const SizedBox(height: 8),
        Text('Start writing', style: Swa.playfair(size: 32, height: 1.1)),
        const SizedBox(height: 8),
        Text('A wallet on this device. Reading never needs one.', style: Swa.serif(size: 16, color: Swa.muted, height: 1.4)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: Swa.paper,
            borderRadius: BorderRadius.circular(Swa.radiusLg),
            border: Border.all(color: Swa.line),
            boxShadow: Swa.lift,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _bullet(SwaI.lock, 'Stays on this device', 'Never written to Arkiv.'),
              _bullet(SwaI.news, 'Browse without signing in', 'A key is only for posting and tips.'),
              _bullet(SwaI.journalist, 'Prove 18+ without a name', 'Anon Aadhaar stores a nullifier only.'),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: busy ? 'Working…' : 'Create wallet',
                child: FilledButton.icon(
                  key: const ValueKey('sign-in-create'),
                  onPressed: busy ? null : _create,
                  icon: const Icon(SwaI.wallet, size: 18),
                  label: Text(busy ? 'Working…' : 'Create wallet'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('sign-in-connect'),
                onPressed: busy ? null : _connect,
                icon: const Icon(SwaI.wallet, size: 18),
                label: const Text('Connect wallet'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('sign-in-import-toggle'),
                onPressed: busy ? null : () => setState(() => showImport = !showImport),
                icon: const Icon(SwaI.key, size: 18),
                label: Text(showImport ? 'Hide import' : 'Import key'),
              ),
              if (showImport) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: importCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Private key (0x…) — stays on this device',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('sign-in-import'),
                  onPressed: busy ? null : _import,
                  icon: const Icon(SwaI.key, size: 18),
                  label: const Text('Import on this device'),
                ),
              ],
            ],
          ),
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
            'Prove 18+ without putting a name on Arkiv.',
            style: Swa.serif(size: 16, color: Swa.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => context.go('/journalist'),
              icon: const Icon(SwaI.journalist, size: 18),
              label: const Text('Continue to Anon Aadhaar'),
            ),
          ),
        ],
      ],
    );
  }
}
