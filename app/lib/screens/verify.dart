import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../arkiv/hash.dart';
import '../arkiv/service.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/bits.dart';

class VerifyScreen extends StatefulWidget {
  final String? root;
  const VerifyScreen({super.key, this.root});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  String? status;
  String? computedRoot;
  ArkivEntity? match;
  final rootCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.root != null) rootCtrl.text = widget.root!;
  }

  @override
  void dispose() {
    rootCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;
    final bytes = r.files.first.bytes!;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final chain = hashChain([(bytes: bytes, timestampMs: ts)]);
    setState(() {
      computedRoot = chain.root;
      status =
          'Hashed ${bytes.length} bytes as a 1-frame chain using now=$ts. For a match, the original timestamp must be the one stored on the capture entity.';
    });
  }

  Future<void> _pickWithStoredTs() async {
    final key = rootCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => status = 'Paste a chain root or capture entity key first, or pick a file to compute a new root.');
      return;
    }
    setState(() => status = 'Looking up Arkiv…');
    try {
      ArkivEntity? cap;
      if (key.startsWith('0x') && key.length == 66) {
        cap = await Arkiv.entity(key);
        cap ??= (await Arkiv.ofType('capture', eq: {'chain_root': key})).firstOrNull;
      }
      cap ??= (await Arkiv.ofType('capture', eq: {'chain_root': key})).firstOrNull;
      if (cap == null) {
        setState(() {
          match = null;
          status = 'No capture entity with that key or chain_root.';
        });
        return;
      }
      setState(() => match = cap);
      final r = await FilePicker.platform.pickFiles(withData: true);
      if (r == null || r.files.first.bytes == null) return;
      final bytes = r.files.first.bytes!;
      final ts = int.tryParse(cap.attr('start_ms', '0')) ?? 0;
      final chain = hashChain([(bytes: bytes, timestampMs: ts)]);
      final expected = cap.attr('chain_root');
      final ok = chain.root.toLowerCase() == expected.toLowerCase();
      setState(() {
        computedRoot = chain.root;
        status = ok
            ? 'MATCH. Recomputed root equals the Arkiv capture entity. Media was not stored on Arkiv — only this hash chain.'
            : 'NO MATCH. Recomputed ${chain.root} vs Arkiv $expected. Different bytes or a different timestamp.';
      });
    } catch (e) {
      setState(() => status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text('Verify a capture', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Recompute the SHA-256 chain from a media file and compare it to a capture entity on Arkiv. Video/photos stay off Arkiv because of size and cost (128 KiB payload cap).',
          style: TextStyle(color: Swa.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        const TestModeBanner(
          'h_i = sha256(h_{i-1} || sha256(frame_i) || uint64be(timestamp_ms)), h_0 = 32 zero bytes. Seed stills use the capture start_ms as the timestamp.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: rootCtrl,
          decoration: const InputDecoration(
            labelText: 'Capture entity key or chain_root (0x…)',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _pickWithStoredTs, child: const Text('Pick file and compare to Arkiv')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _pick, child: const Text('Hash a file only (uses current time)')),
        if (computedRoot != null) ...[
          const SizedBox(height: 16),
          SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Computed root', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Mono(computedRoot!, maxLines: 4),
          ])),
        ],
        if (match != null) ...[
          const SizedBox(height: 12),
          SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Arkiv capture entity', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Mono(match!.key, maxLines: 3),
            Text('frames ${match!.attr('frame_count')} · fps ${match!.attr('fps')} · city ${match!.attr('city')}'),
            Text('\$creator ${match!.creator}', style: const TextStyle(color: Swa.muted, fontSize: 12)),
          ])),
        ],
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
      ],
    );
  }
}
