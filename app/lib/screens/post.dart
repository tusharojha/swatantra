import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../arkiv/hash.dart';
import '../arkiv/js.dart';
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
  String? journalistKey;

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
    final c = hashChain([(bytes: bytes, timestampMs: ts)]);
    setState(() {
      chain = c;
      preview = bytes;
      status = 'Sampled 1 frame at capture time $ts. Chain root ${c.root}. Media stays off Arkiv.';
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
        r = await arkivJs('publishStoryWithCapture', {
          'title': title.text.trim(),
          'body': '${body.text.trim()}\n\nSYNTHETIC / DEMO COPY unless you wrote otherwise.',
          'city': city.text.trim().isEmpty ? 'Mumbai' : city.text.trim(),
          'state': state,
          'category': category,
          'mediaUrl': mediaUrl.text.trim(),
          'mediaHash': chain!.frameHashes.first,
          if (journalistKey != null) 'journalistKey': journalistKey,
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
        r = await arkivJs('createStory', {
          'title': title.text.trim(),
          'body': body.text.trim(),
          'city': city.text.trim().isEmpty ? 'Mumbai' : city.text.trim(),
          'state': state,
          'category': category,
          'mediaUrl': mediaUrl.text.trim(),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text('Post a story', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Writes a readonly story entity owned by your burner wallet. Optional in-app capture hashes frames and stores only the chain root on Arkiv.',
          style: TextStyle(color: Swa.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
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
        const Text('In-app camera / still', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _camera, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
          OutlinedButton.icon(onPressed: _pickGallery, icon: const Icon(Icons.photo_outlined), label: const Text('Gallery')),
        ]),
        if (preview != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(preview!, height: 180, fit: BoxFit.cover),
          ),
        ],
        if (chain != null) ...[
          const SizedBox(height: 8),
          Mono('root ${chain!.root}', maxLines: 3),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _publish, child: const Text('Publish to Arkiv')),
        if (status != null) ...[const SizedBox(height: 16), TestModeBanner(status!)],
        const SizedBox(height: 16),
        const Text(
          'Use only synthetic people and events unless you are the journalist who captured the scene. Never put secrets or real ID data in the payload.',
          style: TextStyle(color: Swa.muted, height: 1.4),
        ),
      ],
    );
  }
}
