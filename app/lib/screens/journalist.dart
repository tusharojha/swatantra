import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/anon.dart';
import '../arkiv/js.dart';
import '../arkiv/service.dart';
import '../screens/onboard.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';

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

  Future<void> _verify({bool bundled = false}) async {
    setState(() {
      proving = true;
      status = arkivJsAvailable
          ? 'Groth16: fetching proving artifacts then prove()+verify(). First run downloads ~612 MiB.'
          : 'APK: SHA-256 nullifier (Groth16 runs in the web build).';
    });
    try {
      if (arkivJsAvailable) {
        final r = await arkivJs('verifyJournalist', {
          'qrData': bundled ? '' : qr.text,
          if (state != null) 'state': state,
        });
        final nid = r['nullifier'] as String?;
        final isG16 = r['groth16'] == true && r['ok'] != false;
        await WalletStore.saveAnonProof(nullifier: nid ?? '', groth16: isG16);
        if (!mounted) return;
        setState(() {
          nullifier = nid;
          groth16 = isG16;
          ageAbove18 = r['ageAbove18'] != false && r['ageOver18'] != false;
          stateRevealed = r['stateRevealed'] == true;
          proofHash = r['proofHash'] as String?;
          status = isG16
              ? (r['note'] as String? ?? 'Proof verified ✓')
              : 'SHA-256 nullifier (not Groth16). ${r['note'] ?? ''}';
          proving = false;
        });
        return;
      }
      final nid = testNullifier(bundled ? '' : qr.text);
      await WalletStore.saveAnonProof(nullifier: nid, groth16: false);
      if (!mounted) return;
      setState(() {
        nullifier = nid;
        groth16 = false;
        status =
            'SHA-256 nullifier on APK. Open the web app to generate a full Groth16 proof. Nullifier $nid';
        proving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        status = '$e';
        proving = false;
      });
    }
  }

  Future<void> _register() async {
    if (WalletStore.address == null) {
      setState(() => status = 'Generate a burner wallet in Me and fund it first.');
      return;
    }
    if (nullifier == null) {
      await _verify(bundled: qr.text.isEmpty);
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
            ? 'This nullifier already has a journalist entity. One person = one identity. ${r['entity']}'
            : 'Registered. Entity $entityKey  tx ${r['txHash']}';
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
        if (WalletStore.address == null) ...[
          const OnboardPanel(),
          const SizedBox(height: 32),
        ],
        Text(
          'Zero-knowledge proof. Your Aadhaar details never leave this device.',
          style: Swa.demoLine,
        ),
        const SizedBox(height: 16),
        if (groth16 && nullifier != null) ...[
          const Row(
            children: [
              Icon(SwaI.journalist, size: 16, color: Swa.magenta),
              SizedBox(width: 6),
              Kicker('Proof verified ✓'),
            ],
          ),
          const SizedBox(height: 8),
          Text('Proof verified ✓', style: Swa.playfair(size: 22)),
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
            hintText: 'Paste TEST QR, or use the bundled identity',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: proving ? null : () => _verify(bundled: true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: Text(proving ? 'Proving…' : 'Prove bundled test identity'),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: proving ? null : () => _verify(bundled: false),
            child: const Text('Prove pasted TEST QR'),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: proving ? null : _register, child: const Text('Create journalist entity')),
        ),
        if (!groth16 && nullifier != null) ...[
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Kicker('Nullifier'),
          const SizedBox(height: 8),
          Mono(nullifier!, maxLines: 3),
        ],
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
        const SizedBox(height: 24),
        Text(
          'On Arkiv: type=journalist, nid=nullifier, groth16, age_over_18, state_revealed, optional state, proof_hash, test_mode=true. No QR, no Aadhaar fields. \$creator is the burner wallet. nid uniqueness: one person = one journalist.',
          style: Swa.serif(size: 13, color: Swa.muted, height: 1.45),
        ),
      ],
    ),
    );
  }
}
