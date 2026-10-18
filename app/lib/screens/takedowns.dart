import 'package:flutter/material.dart';
import '../arkiv/js.dart';
import '../arkiv/service.dart';
import '../models.dart';
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

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final list = await Arkiv.ofType('takedown');
      if (mounted) setState(() { items = list; loading = false; });
    } catch (e) {
      if (mounted) setState(() { status = '$e'; loading = false; });
    }
  }

  Future<void> _submit() async {
    if (WalletStore.address == null) {
      setState(() => status = 'Need a funded burner in Me.');
      return;
    }
    try {
      final r = await arkivJs('createTakedown', {
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text('Takedown log', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'A public tracker of notices journalists record. Synthetic in the demo. Attributes: platform, notice_date_ms, law_cited, authority_named.',
          style: TextStyle(color: Swa.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        if (loading) const Center(child: CircularProgressIndicator()),
        ...items.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, children: [
                    AccentChip(t.attr('platform'), color: Swa.magenta),
                    AccentChip(t.attr('authority_named') == 'true' ? 'authority named' : 'authority unnamed'),
                  ]),
                  const SizedBox(height: 8),
                  Text(t.attr('law_cited')),
                  const SizedBox(height: 4),
                  Text('${t.payload['notes'] ?? ''}', style: const TextStyle(color: Swa.muted)),
                  Mono('by ${shortAddr(t.creator)}', maxLines: 1),
                ]),
              ),
            )),
        const SizedBox(height: 20),
        const Text('Record a notice', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
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
          title: const Text('Authority named on the notice?'),
          value: authorityNamed,
          onChanged: (v) => setState(() => authorityNamed = v),
        ),
        FilledButton(onPressed: _submit, child: const Text('Write takedown entity')),
        if (status != null) ...[const SizedBox(height: 12), TestModeBanner(status!)],
      ],
    );
  }
}
