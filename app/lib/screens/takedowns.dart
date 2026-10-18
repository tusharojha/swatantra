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
  final law = TextEditingController(text: 'IT Act s.79 (synthetic)');
  final notes = TextEditingController();
  final storyKey = TextEditingController();
  bool authorityNamed = false;
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
    storyKey.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final list = await Arkiv.ofType('takedown');
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          items = ProofEdition.takedowns;
          loading = false;
        });
      } else {
        setState(() {
          items = list;
          loading = false;
        });
      }
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
      setState(() => status = 'Need a funded burner in Me.');
      return;
    }
    try {
      final r = await Arkiv.callWrite('createTakedown', {
        'platform': platform,
        'dateMs': DateTime.now().millisecondsSinceEpoch,
        'lawCited': law.text.trim(),
        'authorityNamed': authorityNamed,
        if (storyKey.text.trim().isNotEmpty) 'storyKey': storyKey.text.trim(),
        'notes': notes.text.trim(),
      });
      setState(() => status = 'Logged ${r['entityKey']}');
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
        const SectionHead(
          kicker: 'The record',
          title: 'Takedown log',
          dek:
              'A public tracker of notices journalists record. Attributes: platform, notice_date_ms, law_cited, authority_named.',
        ),
        const SizedBox(height: 24),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (!loading && items.isEmpty)
          Text('No notices on Arkiv yet. File one with a funded burner.', style: Swa.serif(size: 15, color: Swa.muted)),
        for (var i = 0; i < items.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(items[i].attr('platform')),
                const SizedBox(height: 8),
                Text(items[i].attr('law_cited'), style: Swa.playfair(size: 18, height: 1.25)),
                const SizedBox(height: 8),
                Text(
                  items[i].attr('authority_named') == 'true' ? 'Authority named' : 'Authority unnamed',
                  style: Swa.byline,
                ),
                if ('${items[i].payload['notes'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${items[i].payload['notes']}', style: Swa.serif(size: 14, color: Swa.muted, height: 1.4)),
                ],
                Mono('by ${shortAddr(items[i].creator)}', maxLines: 1),
              ],
            ),
          ),
          if (i != items.length - 1) const Hairline(),
        ],
        const SizedBox(height: 24),
        const Hairline(),
        const SizedBox(height: 16),
        const Kicker('File a notice'),
        const SizedBox(height: 8),
        Text('Record a notice', style: Swa.playfair(size: 22)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: platform,
          items: const ['X', 'Instagram', 'YouTube', 'Facebook', 'WhatsApp', 'other']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => platform = v ?? platform),
          decoration: const InputDecoration(labelText: 'Platform'),
        ),
        const SizedBox(height: 12),
        TextField(controller: law, decoration: const InputDecoration(labelText: 'Law cited (synthetic OK)')),
        const SizedBox(height: 12),
        TextField(controller: storyKey, decoration: const InputDecoration(labelText: 'Related story entity key (optional)')),
        const SizedBox(height: 12),
        TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Authority named on the notice?', style: Swa.serif(size: 15)),
          value: authorityNamed,
          activeThumbColor: Swa.magenta,
          onChanged: (v) => setState(() => authorityNamed = v),
        ),
        FilledButton(onPressed: _submit, child: const Text('WRITE TAKEDOWN ENTITY')),
        if (status != null) ...[const SizedBox(height: 12), TestModeBanner(status!)],
      ],
    ),
    );
  }
}
