import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../arkiv/hash.dart';
import '../arkiv/service.dart';
import '../models.dart';
import '../proof_edition.dart';
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
      cap ??= ProofEdition.captureByRoot(key);
      if (cap == null && ProofEdition.isProof(key)) cap = ProofEdition.entity(key);
      if (cap == null) {
        setState(() {
          match = null;
          status =
              'No capture entity with that key or chain_root on Arkiv (and no synthetic-demo match). Seed stills use capture start_ms.';
        });
        return;
      }
      if (ProofEdition.isProof(cap.key)) {
        setState(() => status = ProofEdition.banner);
      }
      setState(() => match = cap);
      final r = await FilePicker.platform.pickFiles(withData: true);
      if (r == null || r.files.first.bytes == null) return;
      final bytes = r.files.first.bytes!;
      final ts = int.tryParse(cap.attr('start_ms', '0')) ?? 0;
      final chain = hashChain(
        [(bytes: bytes, timestampMs: ts)],
        district: cap.district,
        geoCell: cap.geoCell,
      );
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
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
      padding: Swa.pagePadding,
      children: [
        const SectionHead(
          kicker: 'Newsroom',
          title: 'Verify a capture',
          dek:
              'Recompute the SHA-256 chain from a media file and compare it to a capture entity on Arkiv. Video/photos stay off Arkiv because of size and cost (128 KiB payload cap).',
        ),
        const SizedBox(height: 16),
        Text(
          'h_i = sha256(h_{i-1} || sha256(frame_i) || uint64be(timestamp_ms) || place); place = sha256(district || 0x00 || geo_cell). Precise GPS is never hashed.',
          style: Swa.serif(size: 15, color: Swa.muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: rootCtrl,
          decoration: const InputDecoration(
            labelText: 'Capture entity key or chain_root (0x…)',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _pickWithStoredTs, child: const Text('PICK FILE AND COMPARE')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _pick, child: const Text('Hash a file only (uses current time)')),
        if (computedRoot != null) ...[
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Kicker('Computed root'),
          const SizedBox(height: 8),
          Mono(computedRoot!, maxLines: 4),
        ],
        if (match != null) ...[
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Kicker('Arkiv capture entity'),
          const SizedBox(height: 8),
          Mono(match!.key, maxLines: 3),
          const SizedBox(height: 8),
          Text(
            'frames ${match!.attr('frame_count')} · fps ${match!.attr('fps')} · city ${match!.attr('city')}',
            style: Swa.serif(size: 14, color: Swa.muted),
          ),
          Text('\$creator ${match!.creator}', style: Swa.byline),
        ],
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
      ],
    ),
    );
  }
}
