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
      status = 'Hashed as a 1-frame chain at now=$ts. A match needs the capture’s stored timestamp, district and cell.';
    });
  }

  Future<void> _pickWithStoredTs() async {
    final key = rootCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => status = 'Paste a chain root or capture key, then pick the file.');
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
          status = 'No capture on Arkiv for that key. Seed stills use capture start_ms + district + geo_cell.';
        });
        return;
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
        status = ok ? 'Match. Same root as the Arkiv capture.' : 'No match. Different bytes, time, district or cell.';
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
          Text('Verify', style: Swa.playfair(size: 28)),
          const SizedBox(height: 8),
          Text(
            'Recompute the hash chain from a file. Media never sits on Arkiv.',
            style: Swa.serif(size: 16, color: Swa.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: rootCtrl,
            style: Swa.ui(size: 15),
            decoration: const InputDecoration(
              hintText: 'Capture key or chain root',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          const Hairline(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _pickWithStoredTs, child: const Text('Pick file and compare')),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _pick, child: const Text('Hash a file only')),
          ),
          if (computedRoot != null) ...[
            const SizedBox(height: 16),
            const Hairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Computed root', style: Swa.ui(size: 12, color: Swa.muted, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Mono(computedRoot!, maxLines: 4),
                ],
              ),
            ),
          ],
          if (match != null) ...[
            const Hairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Arkiv capture', style: Swa.ui(size: 12, color: Swa.muted, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Mono(match!.key, maxLines: 3),
                  const SizedBox(height: 8),
                  Text(
                    '${match!.attr('frame_count')} frames · ${match!.district} · ${match!.attr('city')}',
                    style: Swa.byline,
                  ),
                ],
              ),
            ),
          ],
          if (status != null) Text(status!, style: Swa.serif(size: 15, color: Swa.muted, height: 1.45)),
        ],
      ),
    );
  }
}
