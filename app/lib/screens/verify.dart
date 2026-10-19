import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../arkiv/hash.dart';
import '../arkiv/service.dart';
import '../models.dart';
import '../proof_edition.dart';
import '../theme.dart';
import '../widgets/bits.dart';
import '../widgets/skeleton.dart';

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
  bool looking = false;
  bool? matched;
  final rootCtrl = TextEditingController();

  bool get _idle => computedRoot == null && match == null && !looking && matched == null;

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
      matched = null;
      status = 'Hashed as a 1-frame chain. A match needs the capture’s stored timestamp, district and cell.';
    });
  }

  Future<void> _pickWithStoredTs() async {
    final key = rootCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => status = 'Paste a chain root or capture key, then pick the file.');
      return;
    }
    setState(() {
      looking = true;
      status = 'Looking up Arkiv…';
    });
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
          matched = false;
          looking = false;
          status = 'No capture on Arkiv for that key.';
        });
        return;
      }
      setState(() => match = cap);
      final r = await FilePicker.platform.pickFiles(withData: true);
      if (r == null || r.files.first.bytes == null) {
        setState(() => looking = false);
        return;
      }
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
        matched = ok;
        looking = false;
        status = ok ? 'Match. Same root as the Arkiv capture.' : 'No match. Different bytes, time, district or cell.';
      });
    } catch (e) {
      setState(() {
        looking = false;
        status = sanitizeUi('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
        padding: Swa.pagePadding,
        children: [
          const Kicker('Integrity'),
          const SizedBox(height: 8),
          Text('Verify', style: Swa.playfair(size: 32)),
          const SizedBox(height: 8),
          Text(
            'A hash chain binds bytes, time and district. Matching the Arkiv root proves the still was not swapped.',
            style: Swa.serif(size: 16, color: Swa.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          if (_idle)
            EmptyState(
              icon: SwaI.hash,
              title: 'Recompute a capture',
              dek:
                  'Each frame is hashed with its timestamp, then bound to district and cell. The root lives on Arkiv; the file stays with you. A match means those bytes are the ones that were sealed.',
              action: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: rootCtrl,
                    style: Swa.ui(size: 15),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Swa.paper,
                      hintText: 'Capture key or chain root',
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _pickWithStoredTs,
                    icon: const Icon(SwaI.verify, size: 18),
                    label: const Text('Pick file and compare'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(SwaI.hash, size: 18),
                    label: const Text('Hash a file'),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: rootCtrl,
              style: Swa.ui(size: 15),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Swa.paper,
                hintText: 'Capture key or chain root',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              children: [
                ActionPill(icon: SwaI.verify, label: 'Pick file and compare', onTap: _pickWithStoredTs),
                ActionPill(icon: SwaI.hash, label: 'Hash a file', onTap: _pick),
              ],
            ),
          ],
          if (looking) ...[
            const SizedBox(height: 24),
            const Skeleton(height: 14, width: 180),
            const SizedBox(height: 12),
            const Skeleton(height: 48, radius: 12),
          ],
          if (matched != null) ...[
            const SizedBox(height: 24),
            matched == true
                ? const CaptureSeal()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Swa.line),
                      borderRadius: BorderRadius.circular(Swa.radiusPill),
                    ),
                    child: const Text(
                      'NO MATCH',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Swa.muted,
                      ),
                    ),
                  ),
          ],
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
                  const SizedBox(height: 8),
                  OnArkivLink(url: explorerEntity(match!.key)),
                ],
              ),
            ),
          ],
          if (status != null && !_idle) Text(sanitizeUi(status!), style: Swa.serif(size: 15, color: Swa.muted, height: 1.45)),
        ],
      ),
    );
  }
}
