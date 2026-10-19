import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/anon.dart';
import '../arkiv/js.dart';
import '../arkiv/service.dart';
import '../auth.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';
import '../widgets/skeleton.dart';

class JournalistScreen extends StatefulWidget {
  const JournalistScreen({super.key});
  @override
  State<JournalistScreen> createState() => _JournalistScreenState();
}

class _JournalistScreenState extends State<JournalistScreen> {
  final qr = TextEditingController();
  final name = TextEditingController(text: 'Desk');
  final bio = TextEditingController(text: 'Anon byline. District-bound captures.');
  String? state;
  String? status;
  String? nullifier;
  String? entityKey;
  String? proofHash;
  bool groth16 = false;
  bool ageAbove18 = true;
  bool stateRevealed = false;
  bool proving = false;

  static const states = [
    'Maharashtra',
    'Delhi',
    'Tamil Nadu',
    'Assam',
    'Jharkhand',
    'Manipur',
    'Telangana',
    'West Bengal',
    'Meghalaya',
    'Karnataka',
    'Kerala',
    'Gujarat',
  ];

  Future<void> _verify({bool saved = false}) async {
    setState(() {
      proving = true;
      status = arkivJsAvailable
          ? 'Fetching proving artifacts, then prove and verify. First run downloads the circuit keys.'
          : 'On this phone we store a SHA-256 nullifier. Open the web app for a full Groth16 proof.';
    });
    try {
      if (arkivJsAvailable) {
        final r = await arkivJs('verifyJournalist', {
          'qrData': saved ? '' : qr.text,
          if (state != null) 'state': state,
        });
        final nid = r['nullifier'] as String?;
        final isG16 = r['groth16'] == true && r['ok'] != false;
        if (nid != null && nid.isNotEmpty) {
          await WalletStore.saveAnonProof(nullifier: nid, groth16: isG16);
        }
        if (!mounted) return;
        setState(() {
          nullifier = nid;
          groth16 = isG16;
          ageAbove18 = r['ageAbove18'] != false && r['ageOver18'] != false;
          stateRevealed = r['stateRevealed'] == true;
          proofHash = r['proofHash'] as String?;
          status = isG16
              ? sanitizeUi(r['note'] as String? ?? 'Proof verified. Nullifier only.')
              : sanitizeUi('Nullifier derived. ${r['note'] ?? ''}');
          proving = false;
        });
        return;
      }
      final nid = testNullifier(saved ? '' : qr.text);
      await WalletStore.saveAnonProof(nullifier: nid, groth16: false);
      if (!mounted) return;
      setState(() {
        nullifier = nid;
        groth16 = false;
        status = 'Nullifier stored on this device. Open the web app to generate a full Groth16 proof.';
        proving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        status = sanitizeUi('$e');
        proving = false;
      });
    }
  }

  Future<void> _register() async {
    if (!await ensureSignedIn(context, action: 'register this desk')) return;
    if (!mounted) return;
    if (nullifier == null) {
      await _verify(saved: qr.text.isEmpty);
    }
    if (nullifier == null) return;
    setState(() => status = 'Writing journalist entity…');
    try {
      final r = await Arkiv.callWrite('createJournalist', {
        'nullifier': nullifier,
        if (state != null) 'state': state,
        'displayName': name.text.trim(),
        'bio': bio.text.trim(),
        'groth16': groth16,
        'ageAbove18': ageAbove18,
        'stateRevealed': stateRevealed,
        if (proofHash != null) 'proofHash': proofHash,
      });
      final key = '${r['entityKey'] ?? (r['entity'] is Map ? (r['entity'] as Map)['key'] : '')}';
      if (key.startsWith('0x')) await WalletStore.saveJournalist(key);
      setState(() {
        entityKey = key;
        status = r['already'] == true
            ? 'This nullifier already has a journalist entity. One person = one identity.'
            : 'Registered. Entity ${shortAddr(entityKey ?? '')}.';
      });
    } catch (e) {
      setState(() => status = sanitizeUi('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
        padding: Swa.pagePadding,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/me'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            icon: const Icon(SwaI.back, size: 16, color: Swa.magenta),
            label: Text('Me', style: Swa.kicker),
          ),
          const SizedBox(height: 16),
          const SectionHead(
            kicker: 'The desk',
            title: 'Verified journalist',
            dek:
                'Prove you are an Indian adult with Anon Aadhaar. We store only the nullifier — never QR data, never a name.',
          ),
          const SizedBox(height: 16),
          Text(
            'Zero-knowledge proof. Your Aadhaar details never leave this device.',
            style: Swa.serif(size: 15, color: Swa.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          if (proving) ...[
            const Skeleton(height: 12, width: 160),
            const SizedBox(height: 12),
            const Skeleton(height: 48, radius: 12),
            const SizedBox(height: 20),
          ],
          if (nullifier != null) ...[
            const VerifiedJournalistBadge(),
            const SizedBox(height: 12),
            Text(groth16 ? 'Proof verified' : 'Nullifier stored', style: Swa.playfair(size: 22)),
            const SizedBox(height: 8),
            Text('NULLIFIER', style: Swa.dateline.copyWith(color: Swa.muted)),
            const SizedBox(height: 4),
            Mono(nullifier!, maxLines: 4),
            if (proofHash != null) ...[
              const SizedBox(height: 8),
              Text('PROOF HASH', style: Swa.dateline.copyWith(color: Swa.muted)),
              const SizedBox(height: 4),
              Mono(proofHash!, maxLines: 3),
            ],
            const SizedBox(height: 16),
            const Hairline(),
            const SizedBox(height: 16),
          ],
          Wrap(
            children: [
              ActionPill(
                key: const ValueKey('aa-prove-saved'),
                icon: SwaI.journalist,
                label: proving ? 'Proving…' : 'Prove with saved identity',
                accent: true,
                onTap: proving ? null : () => _verify(saved: true),
              ),
              ActionPill(
                key: const ValueKey('aa-prove-pasted'),
                icon: SwaI.hash,
                label: 'Prove pasted QR',
                onTap: proving ? null : () => _verify(saved: false),
              ),
              ActionPill(
                key: const ValueKey('aa-register'),
                icon: SwaI.sealed,
                label: 'Create journalist entity',
                onTap: proving ? null : _register,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            style: Swa.playfair(size: 24, height: 1.2),
            decoration: const InputDecoration(
              hintText: 'Public byline',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          TextField(
            controller: bio,
            maxLines: 3,
            style: Swa.serif(size: 16, height: 1.45),
            decoration: const InputDecoration(
              hintText: 'Bio',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: state,
            decoration: const InputDecoration(
              hintText: 'State (optional reveal)',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => state = v),
          ),
          TextField(
            controller: qr,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Paste the QR from mAadhaar, or prove with the saved identity on this device',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 16),
            Text(sanitizeUi(status!), style: Swa.serif(size: 15, color: Swa.muted, height: 1.45)),
          ],
          const SizedBox(height: 24),
          Text(
            'On Arkiv Tiramisu: type=journalist, nid=nullifier, groth16, age_over_18, state_revealed, optional state, proof_hash. No QR, no Aadhaar fields. \$creator is the wallet. nid uniqueness: one person = one journalist.',
            style: Swa.serif(size: 13, color: Swa.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
