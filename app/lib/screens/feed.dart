import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/bits.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<ArkivEntity> items = [];
  String? error;
  bool loading = true;
  String? state;
  String? city;
  String? category;

  static const states = [
    '',
    'Maharashtra',
    'Delhi',
    'Tamil Nadu',
    'Assam',
    'Jharkhand',
    'Manipur',
    'Telangana',
    'West Bengal',
    'Meghalaya',
  ];
  static const cats = ['', 'civic', 'protest', 'environment', 'labour', 'conflict', 'other'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await Arkiv.feed(
        state: state?.isEmpty == true ? null : state,
        city: city?.isEmpty == true ? null : city,
        category: category?.isEmpty == true ? null : category,
      );
      if (mounted) {
        setState(() {
          items = list;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text('On the ground', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'Stories are Arkiv entities. Anyone can query them — no wallet needed to read.',
            style: TextStyle(color: Swa.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _drop('State', state ?? '', states, (v) {
                setState(() => state = v);
                _load();
              }),
              _drop('Category', category ?? '', cats, (v) {
                setState(() => category = v);
                _load();
              }),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: 'City filter (exact, e.g. Mumbai)',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            onSubmitted: (v) {
              city = v.trim();
              _load();
            },
          ),
          const SizedBox(height: 20),
          if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (error != null) TestModeBanner('Could not query Arkiv: $error'),
          if (!loading && items.isEmpty && error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('No live stories. They may have expired, or the seed has not run yet.',
                  style: TextStyle(color: Swa.muted)),
            ),
          ...items.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SoftCard(
                  onTap: () => context.go('/s/${s.key}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        AccentChip(s.category.isEmpty ? 'story' : s.category, color: Swa.magenta),
                        if (s.city.isNotEmpty) AccentChip('${s.city}, ${s.state}'),
                        if (s.hasCapture) const ProofBadge(),
                      ]),
                      if (s.mediaUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            s.mediaUrl,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(s.title.isEmpty ? 'Untitled story' : s.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        s.body.replaceAll('\n', ' '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Swa.muted, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Creator ${shortAddr(s.creator)}  ·  published ${s.createdAtMs == 0 ? '—' : DateTime.fromMillisecondsSinceEpoch(s.createdAtMs).toUtc().toIso8601String()}',
                        style: const TextStyle(fontSize: 12, color: Swa.muted),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _drop(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Swa.line),
          borderRadius: BorderRadius.circular(12),
          color: Swa.card,
        ),
        child: DropdownButton<String>(
          value: value,
          hint: Text(label),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? 'All $label' : o)))
              .toList(),
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}
