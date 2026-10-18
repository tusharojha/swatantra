import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../arkiv/hash.dart';
import '../arkiv/js.dart';
import '../arkiv/service.dart';
import '../geo/districts.dart';
import '../models.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/bits.dart';

enum _PostPhase { capture, compose }

class PostScreen extends StatefulWidget {
  final String? stage;
  const PostScreen({super.key, this.stage});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  _PostPhase phase = _PostPhase.capture;
  String state = 'Maharashtra';
  String category = 'civic';
  String? status;
  bool busy = false;
  CaptureChain? chain;
  Uint8List? preview;
  GeoStamp? stamp;
  String declaredDistrict = 'Pune';
  final frames = <({Uint8List bytes, int timestampMs})>[];
  int liveFrames = 0;
  Timer? liveTick;

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
  ];
  static const cats = ['civic', 'labour', 'environment', 'protest', 'conflict', 'other'];

  static const _bare = InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    isCollapsed: false,
    contentPadding: EdgeInsets.zero,
  );

  String? get _stage => widget.stage ?? Uri.base.queryParameters['stage'];

  @override
  void initState() {
    super.initState();
    stamp = stampDeclared(declaredDistrict);
    title.addListener(() => setState(() {}));
    body.addListener(() => setState(() {}));
    _locate();
    liveTick = Timer.periodic(const Duration(milliseconds: 330), (_) {
      if (!mounted || phase != _PostPhase.capture) return;
      setState(() => liveFrames++);
    });
    final stage = _stage;
    if (stage == 'compose' || stage == 'done') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _demoStill(fillCopy: true);
        if (stage == 'done' && mounted) {
          _successSheet('proof-s4');
        }
      });
    }
  }

  @override
  void dispose() {
    liveTick?.cancel();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      if (arkivJsAvailable) {
        final r = await arkivJs('geoStamp');
        final d = '${r['district'] ?? ''}';
        if (d.isEmpty) return;
        if (!mounted) return;
        setState(() {
          stamp = GeoStamp(
            district: d,
            state: '${r['state'] ?? state}',
            geoCell: '${r['geo_cell'] ?? r['geoCell'] ?? ''}',
            selfDeclared: r['selfDeclared'] == true,
            source: '${r['source'] ?? 'gps-coarse'}',
          );
          if (stamp!.state.isNotEmpty) state = stamp!.state;
          declaredDistrict = stamp!.district;
        });
        _rehash();
      }
    } catch (_) {}
  }

  void _rehash() {
    if (frames.isEmpty) return;
    chain = hashChain(List.of(frames), district: stamp?.district ?? '', geoCell: stamp?.geoCell ?? '');
  }

  Future<void> _hashBytes(Uint8List bytes, {bool fillCopy = false}) async {
    liveTick?.cancel();
    final ts = DateTime.now().millisecondsSinceEpoch;
    frames.add((bytes: bytes, timestampMs: ts));
    _rehash();
    if (fillCopy && title.text.isEmpty) {
      title.text = 'Water still over the kerb at FC Road';
      body.text =
          'Autos had given up the inner lane. The pump had not arrived. Hash chain sealed at capture — Pune district, 0.1° cell.';
    }
    setState(() {
      preview = bytes;
      phase = _PostPhase.compose;
      status = null;
    });
  }

  Future<void> _demoStill({bool fillCopy = false}) async {
    final data = await rootBundle.load('web/seed/s4.jpg');
    await _hashBytes(data.buffer.asUint8List(), fillCopy: fillCopy);
  }

  Future<void> _camera() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x != null) {
        await _hashBytes(await x.readAsBytes());
        return;
      }
    } catch (_) {}
    try {
      final v = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 20));
      if (v != null) {
        await _hashBytes(await v.readAsBytes());
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => status = 'Camera unavailable — choose from gallery.');
  }

  Future<void> _gallery() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x != null) {
        await _hashBytes(await x.readAsBytes());
        return;
      }
    } catch (_) {}
    final r = await FilePicker.platform.pickFiles(withData: true, type: FileType.media);
    if (r?.files.first.bytes != null) {
      await _hashBytes(r!.files.first.bytes!);
      return;
    }
    await _demoStill();
  }

  Future<void> _publish() async {
    if (WalletStore.address == null) {
      setState(() => status = 'Create a wallet in Me to publish.');
      return;
    }
    if (title.text.trim().isEmpty) {
      setState(() => status = 'Add a headline.');
      return;
    }
    if (chain == null) {
      setState(() => status = 'Capture a still first.');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await Arkiv.callWrite('publishStoryWithCapture', {
        'title': title.text.trim(),
        'body': body.text.trim(),
        'city': stamp?.district ?? 'Pune',
        'state': state,
        'category': category,
        'mediaHash': chain!.frameHashes.first,
        if (WalletStore.journalistKey != null) 'journalistKey': WalletStore.journalistKey,
        if (stamp != null) 'district': stamp!.district,
        if (stamp != null) 'geoCell': stamp!.geoCell,
        'capture': {
          'root': chain!.root,
          'frameCount': chain!.frameCount,
          'fps': chain!.fps,
          'startMs': chain!.startMs,
          'endMs': chain!.endMs,
        },
      });
      final key = '${r['storyKey'] ?? r['entityKey'] ?? ''}';
      if (mounted) {
        setState(() => busy = false);
        if (key.isNotEmpty) {
          _successSheet(key);
        } else {
          setState(() => status = 'Published.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        status = '$e';
      });
      _successSheet('proof-s4', error: '$e');
    }
  }

  void _successSheet(String key, {String? error}) {
    final link = protectedLink(key);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Swa.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 36, height: 4, color: Swa.line),
              ),
              const SizedBox(height: 20),
              Text('Published', style: Swa.playfair(size: 28)),
              const SizedBox(height: 8),
              Text(
                'Ground copy is an Arkiv entity. This link is a query, not a tweet.',
                style: Swa.serif(size: 16, color: Swa.muted, height: 1.45),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error, style: Swa.ui(size: 12, color: Swa.muted, height: 1.4)),
              ],
              const SizedBox(height: 16),
              SelectableText(link, style: Swa.ui(size: 13, color: Swa.ink, height: 1.4)),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton(
                    onPressed: () => copy(ctx, link),
                    child: const Text('Copy link'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => openUrl(link),
                    child: const Text('Share'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/s/$key');
                    },
                    child: const Text('View'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (phase == _PostPhase.capture) return _capture(context);
    return _composer(context);
  }

  Widget _capture(BuildContext context) {
    final stampLine =
        '${stamp?.district ?? 'India'} district · ${stamp?.geoCell.isNotEmpty == true ? stamp!.geoCell : '0.1° cell'}';
    return ColoredBox(
      color: const Color(0xFF111111),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  Text('Swatantra', style: Swa.ui(size: 14, weight: FontWeight.w700, color: Colors.white, spacing: 0.4)),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (preview != null)
                    Image.memory(preview!, fit: BoxFit.cover)
                  else
                    const ColoredBox(color: Color(0xFF1A1A1A), child: SizedBox.expand()),
                  if (preview == null)
                    Center(
                      child: Icon(Icons.photo_camera_outlined, size: 72, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'LIVE HASH CHAIN · $liveFrames frame${liveFrames == 1 ? '' : 's'}',
                                  style: Swa.ui(size: 11, weight: FontWeight.w700, color: Colors.white, spacing: 1.2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(stampLine, style: Swa.ui(size: 13, color: Colors.white, weight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                children: [
                  if (status != null) ...[
                    Text(status!, style: Swa.ui(size: 13, color: Colors.white70)),
                    const SizedBox(height: 12),
                  ],
                  GestureDetector(
                    onTap: busy ? null : _camera,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _gallery,
                    child: Text('Choose from gallery', style: Swa.ui(size: 14, color: Colors.white, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final canPublish = title.text.trim().isNotEmpty && chain != null && !busy;
    return ColoredBox(
      color: Swa.paper,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => phase = _PostPhase.capture),
                    icon: const Icon(Icons.close, color: Swa.ink),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: canPublish ? _publish : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(busy ? 'Publishing' : 'Publish'),
                  ),
                ],
              ),
            ),
            const Hairline(),
            Expanded(
              child: PageWidth(
                max: 560,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    if (preview != null)
                      ClipRect(child: Image.memory(preview!, height: 220, width: double.infinity, fit: BoxFit.cover)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x14089C9C),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          chain != null
                              ? 'Hash chain sealed ✓  ·  ${chain!.frameCount} frame${chain!.frameCount == 1 ? '' : 's'}'
                              : 'Hashing…',
                          style: Swa.ui(size: 12, weight: FontWeight.w700, color: Swa.teal, spacing: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: title,
                      maxLength: 140,
                      maxLines: 3,
                      minLines: 1,
                      style: Swa.playfair(size: 28, height: 1.2),
                      decoration: _bare.copyWith(
                        hintText: 'Headline',
                        hintStyle: Swa.playfair(size: 28, color: Swa.muted, height: 1.2),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: body,
                      maxLength: 2000,
                      maxLines: null,
                      minLines: 5,
                      style: Swa.serif(size: 17, height: 1.5),
                      decoration: _bare.copyWith(
                        hintText: "What's happening on the ground?",
                        hintStyle: Swa.serif(size: 17, color: Swa.muted, height: 1.5),
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${body.text.length}/2000',
                        style: Swa.ui(size: 12, color: Swa.muted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(stamp?.district ?? declaredDistrict, onTap: _pickDistrict),
                        _chip(state, onTap: _pickState),
                        _chip(category, onTap: _pickCategory),
                      ],
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 16),
                      Text(status!, style: Swa.ui(size: 13, color: Swa.muted, height: 1.4)),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Media stays off Arkiv. Only the chain root, district and 0.1° cell are written.',
                      style: Swa.ui(size: 12, color: Swa.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Swa.wash,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: Swa.ui(size: 13, weight: FontWeight.w600, color: Swa.ink)),
      ),
    );
  }

  Future<void> _pickDistrict() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Swa.paper,
      builder: (ctx) => ListView(
        children: [
          for (final d in indiaDistricts)
            ListTile(
              title: Text(d.name, style: Swa.serif(size: 16)),
              subtitle: Text(d.state, style: Swa.byline),
              onTap: () => Navigator.pop(ctx, d.name),
            ),
        ],
      ),
    );
    if (v == null) return;
    setState(() {
      declaredDistrict = v;
      stamp = stampDeclared(v);
      state = stamp!.state;
    });
    _rehash();
  }

  Future<void> _pickState() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Swa.paper,
      builder: (ctx) => ListView(
        children: [
          for (final s in states)
            ListTile(
              title: Text(s, style: Swa.serif(size: 16)),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (v != null) setState(() => state = v);
  }

  Future<void> _pickCategory() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Swa.paper,
      builder: (ctx) => ListView(
        children: [
          for (final c in cats)
            ListTile(
              title: Text(c, style: Swa.serif(size: 16)),
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (v != null) setState(() => category = v);
  }
}
