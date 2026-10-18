import 'package:flutter/material.dart';
import '../arkiv/anon.dart';
import '../arkiv/js.dart';
import '../arkiv/service.dart';
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
  final name = TextEditingController(text: 'Synthetic reporter');
  final bio = TextEditingController(text: 'Fictional byline for the Swatantra demo.');
  String? state;
  String? status;
  String? nullifier;
  String? entityKey;

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
    setState(() => status = 'TEST MODE verifier…');
    try {
      if (arkivJsAvailable) {
        final r = await arkivJs('verifyJournalist', {
          'qrData': bundled ? '' : qr.text,
          if (state != null) 'state': state,
        });
        setState(() {
          nullifier = r['nullifier'] as String?;
          status =
              'Anon Aadhaar TEST MODE. Claims: Indian resident, 18+. Nullifier ${r['nullifier']}. No Aadhaar data is stored.';
        });
        return;
      }
      final nid = testNullifier(bundled ? '' : qr.text);
      setState(() {
        nullifier = nid;
        status =
            'Anon Aadhaar TEST MODE (Dart). Claims: Indian resident, 18+. Nullifier $nid. No Aadhaar data is stored.';
      });
    } catch (e) {
      setState(() => status = '$e');
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
    return ListView(
      padding: Swa.pagePadding,
      children: [
        const SectionHead(
          kicker: 'The desk',
          title: 'Verified journalist',
        ),
        const SizedBox(height: 12),
        const TestModeBanner(
          'Anon Aadhaar TEST MODE (Ethereum Foundation PSE). We do not run the full Groth16 prover in Flutter. A minimal verifier derives a SHA-256 nullifier from test QR data. Nothing from Aadhaar — not even a hash of a real ID — is written to Arkiv. Use official test QR data, never a real card.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Public byline (synthetic)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bio,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Bio (synthetic)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: state,
          decoration: const InputDecoration(labelText: 'State (optional reveal)'),
          items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => state = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: qr,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Anon Aadhaar TEST QR (numeric) — optional',
            hintText: 'Paste test QR, or use the bundled test identity',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => _verify(bundled: true),
          child: const Text('Use bundled test identity'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => _verify(bundled: false), child: const Text('Verify pasted TEST QR')),
        const SizedBox(height: 8),
        FilledButton(onPressed: _register, child: const Text('CREATE JOURNALIST ENTITY')),
        if (nullifier != null) ...[
          const SizedBox(height: 16),
          const Hairline(),
          const SizedBox(height: 16),
          const Kicker('Nullifier'),
          const SizedBox(height: 8),
          Text('Pseudonymous id', style: Swa.playfair(size: 20)),
          const SizedBox(height: 8),
          Mono(nullifier!, maxLines: 3),
        ],
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
        const SizedBox(height: 24),
        Text(
          'On Arkiv we store only: type=journalist, nid=nullifier, optional state, test_mode=true, and a synthetic display name in the payload. \$creator is the burner wallet.',
          style: Swa.serif(size: 13, color: Swa.muted, height: 1.45),
        ),
      ],
    );
  }
}
