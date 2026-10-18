import 'package:flutter/material.dart';
import '../arkiv/service.dart';
import '../models.dart';
import '../proof_edition.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';

class TakedownsScreen extends StatefulWidget {
  const TakedownsScreen({super.key});
  @override
  State<TakedownsScreen> createState() => _TakedownsScreenState();
}

class _TakedownsScreenState extends State<TakedownsScreen> {
  List<ArkivEntity> items = [];
  bool loading = true;
  String platform = 'X';
  final law = TextEditingController(text: 'IT Act s.79');
  final notes = TextEditingController();
  bool composing = false;
  String? status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    law.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final list = await Arkiv.ofType('takedown');
      if (!mounted) return;
      setState(() {
        items = list.isEmpty ? ProofEdition.takedowns : list;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          status = '$e';
          items = ProofEdition.takedowns;
          loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (WalletStore.address == null) {
      setState(() => status = 'Need a wallet in Me.');
      return;
    }
    try {
      final r = await Arkiv.callWrite('createTakedown', {
        'platform': platform,
        'dateMs': DateTime.now().millisecondsSinceEpoch,
        'lawCited': law.text.trim(),
        'authorityNamed': false,
        'notes': notes.text.trim(),
      });
      setState(() {
        status = 'Logged ${r['entityKey']}';
        composing = false;
      });
      await _load();
    } catch (e) {
      setState(() => status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
        padding: Swa.pagePadding,
        children: [
          Text('Tracker', style: Swa.playfair(size: 28)),
          const SizedBox(height: 8),
          Text('Notices journalists log. A row, not a form.', style: Swa.serif(size: 16, color: Swa.muted, height: 1.45)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => composing = !composing),
              child: Text(composing ? 'Cancel' : 'Log a notice'),
            ),
          ),
          if (composing) ...[
            Wrap(
              spacing: 16,
              children: [
                for (final p in const ['X', 'Instagram', 'YouTube', 'Facebook', 'WhatsApp', 'other'])
                  InkWell(
                    onTap: () => setState(() => platform = p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        p,
                        style: Swa.ui(
                          size: 13,
                          weight: FontWeight.w600,
                          color: platform == p ? Swa.magenta : Swa.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            TextField(
              controller: law,
              decoration: const InputDecoration(
                hintText: 'Law cited',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What disappeared?',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Text('Log'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Hairline(),
          if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (!loading && items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('No notices yet.', style: Swa.serif(size: 16, color: Swa.muted)),
            ),
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].attr('platform'), style: Swa.ui(size: 12, weight: FontWeight.w700, color: Swa.magenta, spacing: 0.8)),
                        const SizedBox(height: 6),
                        Text(items[i].attr('law_cited'), style: Swa.playfair(size: 18, height: 1.25)),
                        const SizedBox(height: 6),
                        Text(
                          items[i].attr('authority_named') == 'true' ? 'Authority named' : 'Authority unnamed · ${shortAddr(items[i].creator)}',
                          style: Swa.byline,
                        ),
                        if ('${items[i].payload['notes'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('${items[i].payload['notes']}', style: Swa.serif(size: 15, color: Swa.muted, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1) const Hairline(),
          ],
          if (status != null) ...[const SizedBox(height: 16), Text(status!, style: Swa.serif(size: 14, color: Swa.muted))],
        ],
      ),
    );
  }
}
