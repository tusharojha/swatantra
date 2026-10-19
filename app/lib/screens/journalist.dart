import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/anon.dart';
import '../arkiv/js.dart';
import '../arkiv/service.dart';
import '../auth.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';

class JournalistScreen extends StatefulWidget {
  final String? preview;
  const JournalistScreen({super.key, this.preview});
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

  @override
  void initState() {
    super.initState();
    if (widget.preview == 'proving') {
      proving = true;
      status = 'Fetching proving artifacts, then prove and verify.';
    }
    if (widget.preview == 'verified') {
      nullifier = '0x06ffb52d39bcf94137fd80cd418163a22c52ec478b54e83c66fccb3ee9b7361f';
      groth16 = true;
      status = 'Proof verified. Nullifier only.';
    }
  }

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

  static const _field = InputDecoration(
    filled: true,
    fillColor: Swa.paper,
  );

  int get _step {
    if (nullifier != null) return 2;
    if (proving) return 1;
    return 0;
  }

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
  void dispose() {
    qr.dispose();
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageWidth(
      max: Swa.articleWidth,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 120),
        children: [
          TextButton.icon(
            onPressed: () => context.go('/me'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            icon: const Icon(SwaI.back, size: 16, color: Swa.magenta),
            label: Text('Me', style: Swa.kicker),
          ),
          const SizedBox(height: 16),
          const Kicker('The desk'),
          const SizedBox(height: 8),
          Text('Verified journalist', style: Swa.playfair(size: 32, height: 1.1)),
          const SizedBox(height: 8),
          Text(
            'Prove you are an Indian adult. We store a nullifier — never QR data, never a name.',
            style: Swa.serif(size: 16, color: Swa.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: name,
            style: Swa.playfair(size: 20, height: 1.2),
            decoration: _field.copyWith(labelText: 'Public byline'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: state,
            isExpanded: true,
            decoration: _field.copyWith(labelText: 'State (optional reveal)'),
            items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => state = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bio,
            maxLines: 2,
            style: Swa.serif(size: 16, height: 1.45),
            decoration: _field.copyWith(labelText: 'Bio'),
          ),
          const SizedBox(height: 20),
          _ProofCard(
            step: _step,
            proving: proving,
            verified: nullifier != null,
            groth16: groth16,
            status: status,
            qr: qr,
            onSaved: proving ? null : () => _verify(saved: true),
            onPasted: proving ? null : () => _verify(saved: false),
          ),
          if (nullifier != null) ...[
            const SizedBox(height: 20),
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
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('aa-register'),
            onPressed: proving ? null : _register,
            icon: const Icon(SwaI.sealed, size: 18),
            label: const Text('Create journalist entity'),
          ),
          if (status != null && nullifier == null && !proving) ...[
            const SizedBox(height: 16),
            Text(sanitizeUi(status!), style: Swa.serif(size: 15, color: Swa.muted, height: 1.45)),
          ],
          if (status != null && nullifier != null) ...[
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

class _ProofCard extends StatelessWidget {
  final int step;
  final bool proving;
  final bool verified;
  final bool groth16;
  final String? status;
  final TextEditingController qr;
  final VoidCallback? onSaved;
  final VoidCallback? onPasted;
  const _ProofCard({
    required this.step,
    required this.proving,
    required this.verified,
    required this.groth16,
    required this.qr,
    this.status,
    this.onSaved,
    this.onPasted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Swa.paper,
        borderRadius: BorderRadius.circular(Swa.radiusLg),
        border: Border.all(color: Swa.line),
        boxShadow: Swa.lift,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepRow(
            index: 1,
            icon: SwaI.qr,
            title: 'Scan QR',
            dek: 'Paste the mAadhaar QR, or use the identity saved on this device.',
            state: step > 0 ? _StepState.done : (step == 0 ? _StepState.active : _StepState.idle),
          ),
          const _StepRail(),
          _StepRow(
            index: 2,
            icon: SwaI.proof,
            title: 'Generate proof',
            dek: proving
                ? (status ?? 'Building the Groth16 proof…')
                : 'Zero-knowledge. Aadhaar details never leave this device.',
            state: proving ? _StepState.busy : (step > 1 ? _StepState.done : (step == 1 ? _StepState.active : _StepState.idle)),
          ),
          const _StepRail(),
          _StepRow(
            index: 3,
            icon: SwaI.journalist,
            title: 'Verified seal',
            dek: verified
                ? (groth16 ? 'Proof verified. Nullifier only.' : 'Nullifier stored on this device.')
                : 'A verified-journalist badge after the proof lands.',
            state: verified ? _StepState.done : _StepState.idle,
          ),
          if (!verified && !proving) ...[
            const SizedBox(height: 18),
            TextField(
              controller: qr,
              maxLines: 2,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Swa.paper,
                labelText: 'mAadhaar QR',
                hintText: 'Paste QR, or prove with the saved identity',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('aa-prove-saved'),
              onPressed: onSaved,
              icon: const Icon(SwaI.journalist, size: 18),
              label: const Text('Prove with saved identity'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('aa-prove-pasted'),
              onPressed: onPasted,
              icon: const Icon(SwaI.qr, size: 18),
              label: const Text('Prove pasted QR'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { idle, active, busy, done }

class _StepRow extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String dek;
  final _StepState state;
  const _StepRow({
    required this.index,
    required this.icon,
    required this.title,
    required this.dek,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final live = state == _StepState.active || state == _StepState.busy;
    final ring = done ? Swa.teal : (live ? Swa.magenta : Swa.line);
    final fill = done ? const Color(0x14089C9C) : (live ? const Color(0x14DC2460) : Swa.wash);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: ring),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: state == _StepState.busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Swa.magenta))
                : Icon(done ? SwaI.check : icon, size: 16, color: done ? Swa.teal : (live ? Swa.magenta : Swa.muted)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Swa.ui(size: 14, weight: FontWeight.w700, color: live || done ? Swa.ink : Swa.muted)),
              const SizedBox(height: 4),
              Text(dek, style: Swa.serif(size: 13.5, color: Swa.muted, height: 1.4)),
            ],
          ),
        ),
        Text('$index', style: Swa.ui(size: 12, color: Swa.muted, weight: FontWeight.w600)),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 17, top: 4, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 1, height: 14, child: ColoredBox(color: Swa.line)),
      ),
    );
  }
}
