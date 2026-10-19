import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../arkiv/service.dart';
import '../config.dart';
import '../theme.dart';
import '../wallet.dart';
import 'bits.dart';

Future<T?> showAppSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => sheet,
  );
}

class SheetScaffold extends StatelessWidget {
  final String kicker;
  final String title;
  final String? dek;
  final Widget child;
  const SheetScaffold({
    super.key,
    required this.kicker,
    required this.title,
    required this.child,
    this.dek,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Swa.paper,
            elevation: 0,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Swa.radiusLg)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Swa.line,
                        borderRadius: BorderRadius.circular(Swa.radiusPill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Kicker(kicker),
                  const SizedBox(height: 8),
                  Text(title, style: Swa.playfair(size: 26, height: 1.15)),
                  if (dek != null) ...[
                    const SizedBox(height: 8),
                    Text(dek!, style: Swa.serif(size: 15, color: Swa.muted, height: 1.45)),
                  ],
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Signal-style sheet: only when a gated write needs a wallet.
class SignInSheet extends StatefulWidget {
  final String action;
  const SignInSheet({super.key, required this.action});

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  bool busy = false;
  bool showImport = false;
  String? status;
  final importCtrl = TextEditingController();

  @override
  void dispose() {
    importCtrl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (!mounted) return;
    Navigator.of(context).pop(WalletStore.address != null);
  }

  Future<void> _create() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await WalletStore.generate();
      await _done();
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
      await _done();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          status = kIsWeb
              ? 'No injected wallet on this phone. Create a wallet — it stays on this device.'
              : 'Create a wallet on this phone. It stays on this device.';
        });
      }
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
      await _done();
    } catch (e) {
      if (mounted) setState(() { busy = false; status = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      kicker: 'Sign in',
      title: 'Needed to ${widget.action}',
      dek: 'Reading never needs a wallet. A key on this device is only for posting, tipping, or registering a desk — never written to Arkiv.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            children: [
              ActionPill(
                key: const ValueKey('sign-in-create'),
                icon: SwaI.wallet,
                label: busy ? 'Working…' : 'Create wallet',
                accent: true,
                onTap: busy ? null : _create,
              ),
              ActionPill(
                key: const ValueKey('sign-in-connect'),
                icon: SwaI.wallet,
                label: 'Connect wallet',
                onTap: busy ? null : _connect,
              ),
              ActionPill(
                key: const ValueKey('sign-in-import-toggle'),
                icon: SwaI.key,
                label: showImport ? 'Hide import' : 'Import key',
                selected: showImport,
                onTap: busy ? null : () => setState(() => showImport = !showImport),
              ),
            ],
          ),
          if (showImport) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('sign-in-import-key'),
              controller: importCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Private key (0x…) — stays on this device'),
            ),
            const SizedBox(height: 12),
            ActionPill(
              key: const ValueKey('sign-in-import'),
              icon: SwaI.key,
              label: 'Import on this device',
              accent: true,
              onTap: busy ? null : _import,
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(status!, style: Swa.serif(size: 14, color: Swa.muted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class TipResult {
  final bool ok;
  final String? transferTx;
  final String? entityKey;
  final String? error;
  const TipResult({required this.ok, this.transferTx, this.entityKey, this.error});
}

class TipSheet extends StatefulWidget {
  final String storyKey;
  final String to;
  final Future<Map<String, dynamic>> Function(String amountEth) send;
  const TipSheet({super.key, required this.storyKey, required this.to, required this.send});

  @override
  State<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<TipSheet> {
  String preset = '0.001';
  bool custom = false;
  bool sending = false;
  String? status;
  String? tx;
  String? entity;
  String? error;
  bool insufficient = false;
  final amount = TextEditingController(text: '0.001');

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final v = amount.text.trim();
    if (v.isEmpty) return;
    setState(() {
      sending = true;
      status = 'Sending GLM on Arkiv Tiramisu…';
      error = null;
      insufficient = false;
    });
    try {
      final r = await widget.send(v);
      if (!mounted) return;
      setState(() {
        sending = false;
        tx = '${r['transferTx'] ?? ''}';
        entity = '${r['entityKey'] ?? ''}';
        status = 'Tip recorded.';
      });
    } catch (e) {
      final msg = '$e';
      if (!mounted) return;
      setState(() {
        sending = false;
        error = msg;
        insufficient = msg.toLowerCase().contains('insufficient') || msg.toLowerCase().contains('funds');
        status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      kicker: 'Tip',
      title: tx != null ? 'Tip sent' : 'Support this desk',
      dek: tx != null
          ? 'GLM moved on Arkiv Tiramisu. The tip entity is public.'
          : 'Preset amounts, or type your own. Confirms before sending.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tx == null) ...[
            Wrap(
              children: [
                for (final v in const ['0.001', '0.01', '0.05'])
                  ActionPill(
                    key: ValueKey('tip-$v'),
                    icon: SwaI.tip,
                    label: 'GLM $v',
                    selected: !custom && preset == v,
                    onTap: sending
                        ? null
                        : () => setState(() {
                              custom = false;
                              preset = v;
                              amount.text = v;
                            }),
                  ),
                ActionPill(
                  key: const ValueKey('tip-custom'),
                  icon: SwaI.tip,
                  label: 'Custom',
                  selected: custom,
                  onTap: sending ? null : () => setState(() => custom = true),
                ),
              ],
            ),
            if (custom) ...[
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('tip-custom-amount'),
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'GLM amount'),
              ),
            ],
            const SizedBox(height: 16),
            ActionPill(
              key: const ValueKey('tip-confirm'),
              icon: SwaI.tip,
              label: sending ? 'Sending…' : 'Confirm tip',
              accent: true,
              onTap: sending ? null : _send,
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(status!, style: Swa.serif(size: 15, height: 1.4)),
          ],
          if (tx != null && tx!.startsWith('0x')) ...[
            const SizedBox(height: 8),
            Mono(tx!, maxLines: 3),
            const SizedBox(height: 8),
            Wrap(
              children: [
                ActionPill(
                  key: const ValueKey('tip-explorer'),
                  icon: SwaI.open,
                  label: 'On Arkiv',
                  onTap: () => openUrl(explorerTx(tx!)),
                ),
                if (entity != null && entity!.startsWith('0x'))
                  ActionPill(
                    icon: SwaI.open,
                    label: 'Tip entity',
                    onTap: () => openUrl(explorerEntity(entity!)),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionPill(
                key: const ValueKey('tip-done'),
                icon: SwaI.sealed,
                label: 'Done',
                accent: true,
                onTap: () => Navigator.of(context).pop(TipResult(ok: true, transferTx: tx, entityKey: entity)),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(sanitizeUi(error!), style: Swa.serif(size: 14, color: Swa.muted, height: 1.4)),
            if (insufficient)
              ActionPill(
                key: const ValueKey('tip-faucet'),
                icon: SwaI.faucet,
                label: 'Get GLM',
                onTap: () => openUrl(Config.faucet),
              ),
          ],
        ],
      ),
    );
  }
}

class ReportSheet extends StatefulWidget {
  final String? storyKey;
  const ReportSheet({super.key, this.storyKey});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  String platform = 'X';
  bool sending = false;
  String? status;
  String? entity;
  final notes = TextEditingController();
  final law = TextEditingController(text: 'IT Act s.79');

  @override
  void dispose() {
    notes.dispose();
    law.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      sending = true;
      status = 'Logging notice…';
    });
    try {
      final r = await Arkiv.callWrite('createTakedown', {
        'platform': platform,
        'dateMs': DateTime.now().millisecondsSinceEpoch,
        'lawCited': law.text.trim(),
        'authorityNamed': false,
        'notes': notes.text.trim(),
        if (widget.storyKey != null) 'storyKey': widget.storyKey,
      });
      if (!mounted) return;
      setState(() {
        sending = false;
        entity = '${r['entityKey'] ?? ''}';
        status = 'Notice logged.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        sending = false;
        status = sanitizeUi('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      kicker: 'Report',
      title: entity != null ? 'Notice logged' : 'Log a takedown',
      dek: 'A public row, not a legal filing. Signed in so the desk is \$creator.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entity == null) ...[
            Wrap(
              children: [
                for (final p in const ['X', 'Instagram', 'YouTube', 'Facebook', 'WhatsApp', 'other'])
                  ActionPill(
                    icon: SwaI.report,
                    label: p,
                    selected: platform == p,
                    onTap: sending ? null : () => setState(() => platform = p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: law,
              decoration: const InputDecoration(hintText: 'Law cited'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('report-notes'),
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What disappeared?'),
            ),
            const SizedBox(height: 16),
            ActionPill(
              key: const ValueKey('report-submit'),
              icon: SwaI.report,
              label: sending ? 'Logging…' : 'Log notice',
              accent: true,
              onTap: sending ? null : _submit,
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(status!, style: Swa.serif(size: 15, height: 1.4)),
          ],
          if (entity != null && entity!.startsWith('0x'))
            ActionPill(
              icon: SwaI.open,
              label: 'On Arkiv',
              onTap: () => openUrl(explorerEntity(entity!)),
            ),
        ],
      ),
    );
  }
}
