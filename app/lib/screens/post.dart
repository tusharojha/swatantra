import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final title = TextEditingController();
  final body = TextEditingController();
  final city = TextEditingController();
  final mediaUrl = TextEditingController();
  String state = 'Maharashtra';
  String category = 'civic';
  String? status;
  CaptureChain? chain;
  Uint8List? preview;
  GeoStamp? stamp = stampDeclared('Pune');
  String declaredDistrict = 'Pune';
  final frames = <({Uint8List bytes, int timestampMs})>[];

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
  static const cats = ['civic', 'protest', 'environment', 'labour', 'conflict', 'other'];

  Future<void> _hashBytes(Uint8List bytes) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    frames.add((bytes: bytes, timestampMs: ts));
    final c = hashChain(
      List.of(frames),
      district: stamp?.district ?? '',
      geoCell: stamp?.geoCell ?? '',
    );
    setState(() {
      chain = c;
      preview = bytes;
      status =
          'Sampled ${c.frameCount} frame(s), last ts $ts. Chain root ${c.root}. Media stays off Arkiv.';
    });
  }

  Future<void> _pickGallery() async {
    final r = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
    if (r?.files.first.bytes != null) await _hashBytes(r!.files.first.bytes!);
  }

  Future<void> _camera() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await _hashBytes(bytes);
  }

  Future<void> _publish() async {
    if (WalletStore.address == null) {
      setState(() => status = 'Create and fund a burner in Me first.');
      return;
    }
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      setState(() => status = 'Title and body are required.');
      return;
    }
    setState(() => status = 'Writing Arkiv entities…');
    try {
      Map<String, dynamic> r;
      if (chain != null) {
        r = await Arkiv.callWrite('publishStoryWithCapture', {
          'title': title.text.trim(),
          'body': '${body.text.trim()}\n\nSYNTHETIC / DEMO COPY unless you wrote otherwise.',
          'city': city.text.trim().isEmpty ? 'Mumbai' : city.text.trim(),
          'state': state,
          'category': category,
          'mediaUrl': mediaUrl.text.trim(),
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
        setState(() => status = 'Published story ${r['storyKey']} with capture ${r['captureKey']}. Tx ${r['txHash']}');
        if (mounted && r['storyKey'] != null) context.go('/s/${r['storyKey']}');
      } else {
        r = await Arkiv.callWrite('createStory', {
          'title': title.text.trim(),
          'body': body.text.trim(),
          'city': city.text.trim().isEmpty ? 'Mumbai' : city.text.trim(),
          'state': state,
          'category': category,
          'mediaUrl': mediaUrl.text.trim(),
          if (stamp != null) 'district': stamp!.district,
          if (stamp != null) 'geoCell': stamp!.geoCell,
        });
        setState(() => status = 'Published ${r['entityKey']}');
        if (mounted) context.go('/s/${r['entityKey']}');
      }
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
          kicker: 'File a dispatch',
          title: 'Post a story',
          dek:
              'Writes a readonly story entity owned by your burner wallet. Optional in-app capture hashes each still (add several for a 1 fps chain) and stores only the chain root on Arkiv.',
        ),
        const SizedBox(height: 16),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Headline')),
        const SizedBox(height: 12),
        TextField(controller: body, maxLines: 8, decoration: const InputDecoration(labelText: 'Body')),
        const SizedBox(height: 12),
        TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: state,
          items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => state = v ?? state),
          decoration: const InputDecoration(labelText: 'State'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: category,
          items: cats.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => category = v ?? category),
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: mediaUrl,
          decoration: const InputDecoration(
            labelText: 'Public media URL (optional, stays off Arkiv)',
          ),
        ),
        const SizedBox(height: 16),
        const Hairline(),
        const SizedBox(height: 16),
        const Kicker('District stamp'),
        const SizedBox(height: 8),
        Text('Coarse location', style: Swa.playfair(size: 20)),
        const SizedBox(height: 8),
        Text(
          'GPS is reverse-looked-up to a district centroid and a 0.1° cell. Precise coordinates are never stored or hashed.',
          style: Swa.serif(size: 13, color: Swa.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () async {
              setState(() => status = 'Requesting coarse location…');
              try {
                if (arkivJsAvailable) {
                  final r = await arkivJs('geoStamp');
                  final d = '${r['district'] ?? ''}';
                  if (d.isEmpty) throw StateError('no fix');
                  setState(() {
                    stamp = GeoStamp(
                      district: d,
                      state: '${r['state'] ?? ''}',
                      geoCell: '${r['geo_cell'] ?? r['geoCell'] ?? ''}',
                      selfDeclared: r['selfDeclared'] == true,
                      source: '${r['source'] ?? 'gps-coarse'}',
                    );
                    if (frames.isNotEmpty) {
                      chain = hashChain(List.of(frames), district: stamp!.district, geoCell: stamp!.geoCell);
                    }
                    status = 'Stamped ${stamp!.district} · cell ${stamp!.geoCell}';
                  });
                } else {
                  setState(() {
                    stamp = stampDeclared(declaredDistrict);
                    status = 'APK: use the self-declared picker (no GPS plugin). ${stamp!.district}';
                  });
                }
              } catch (e) {
                setState(() {
                  stamp = stampDeclared(declaredDistrict);
                  status = 'GPS unavailable — self-declared ${stamp!.district}. $e';
                });
              }
            },
            icon: const Icon(Icons.my_location_outlined),
            label: const Text('Use GPS (coarse)'),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: declaredDistrict,
          items: indiaDistricts
              .map((d) => DropdownMenuItem(value: d.name, child: Text('${d.name}, ${d.state}')))
              .toList(),
          onChanged: (v) {
            declaredDistrict = v ?? declaredDistrict;
            stamp = stampDeclared(declaredDistrict);
            if (frames.isNotEmpty) {
              final c = hashChain(List.of(frames), district: stamp!.district, geoCell: stamp!.geoCell);
              setState(() {
                chain = c;
                status = 'Self-declared ${stamp!.district}. Chain re-bound to district+cell.';
              });
            } else {
              setState(() {});
            }
          },
          decoration: const InputDecoration(
            labelText: 'Self-declared district',
            helperText: 'Labelled self-declared — not a GPS fix',
          ),
        ),
        if (stamp != null) ...[
          const SizedBox(height: 8),
          Mono('${stamp!.district} · ${stamp!.geoCell} · ${stamp!.selfDeclared ? 'self-declared' : stamp!.source}', maxLines: 2),
        ],
        const SizedBox(height: 16),
        const Hairline(),
        const SizedBox(height: 16),
        const Kicker('In-app still'),
        const SizedBox(height: 8),
        Text('Camera / gallery', style: Swa.playfair(size: 20)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _camera, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
          OutlinedButton.icon(onPressed: _pickGallery, icon: const Icon(Icons.photo_outlined), label: const Text('Add still')),
          if (frames.isNotEmpty)
            OutlinedButton(
              onPressed: () => setState(() {
                frames.clear();
                chain = null;
                preview = null;
                status = 'Capture chain cleared.';
              }),
              child: const Text('Clear frames'),
            ),
        ]),
        if (preview != null) ...[
          const SizedBox(height: 12),
          Image.memory(preview!, height: 180, fit: BoxFit.cover),
        ],
        if (chain != null) ...[
          const SizedBox(height: 8),
          Mono('root ${chain!.root}', maxLines: 3),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _publish, child: const Text('PUBLISH TO ARKIV')),
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
        const SizedBox(height: 16),
        Text(
          'Use only synthetic people and events unless you are the journalist who captured the scene. Never put secrets or real ID data in the payload.',
          style: Swa.serif(size: 13, color: Swa.muted, height: 1.4),
        ),
      ],
    );
  }
}
