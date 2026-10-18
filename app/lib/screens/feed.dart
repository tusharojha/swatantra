import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../models.dart';
import '../proof_edition.dart';
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
  bool proof = false;
  bool corroboratedOnly = false;
  String? state;
  String? city;
  String? category;
  final clusters = <String, Corroboration>{};

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
      if (!mounted) return;
      if (list.isEmpty) {
        var edition = ProofEdition.stories;
        if (state != null && state!.isNotEmpty) {
          edition = edition.where((s) => s.state == state).toList();
        }
        if (category != null && category!.isNotEmpty) {
          edition = edition.where((s) => s.category == category).toList();
        }
        if (city != null && city!.isNotEmpty) {
          edition = edition.where((s) => s.city.toLowerCase() == city!.toLowerCase()).toList();
        }
        final map = <String, Corroboration>{};
        for (final s in edition) {
          final c = ProofEdition.corroborationFor(s);
          if (c != null && c.ok) map[s.key] = c;
        }
        setState(() {
          items = edition;
          clusters
            ..clear()
            ..addAll(map);
          proof = true;
          loading = false;
        });
      } else {
        final map = <String, Corroboration>{};
        for (final s in list) {
          final district = s.district.isNotEmpty ? s.district : s.city;
          final ts = s.captureTsMs == 0 ? s.createdAtMs : s.captureTsMs;
          final c = await Arkiv.corroborationFor(district: district, captureTsMs: ts, geoCell: s.geoCell);
          if (c != null && c.ok) map[s.key] = c;
        }
        setState(() {
          items = list;
          clusters
            ..clear()
            ..addAll(map);
          proof = false;
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final edition = ProofEdition.stories;
      final map = <String, Corroboration>{};
      for (final s in edition) {
        final c = ProofEdition.corroborationFor(s);
        if (c != null && c.ok) map[s.key] = c;
      }
      setState(() {
        error = '$e';
        items = edition;
        clusters
          ..clear()
          ..addAll(map);
        proof = true;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var shown = items;
    if (corroboratedOnly) {
      shown = items.where((s) => clusters[s.key]?.ok == true).toList();
    }
    final lead = shown.isEmpty ? null : shown.first;
    final rest = shown.length > 1 ? shown.sublist(1) : const <ArkivEntity>[];

    return RefreshIndicator(
      onRefresh: _load,
      color: Swa.ink,
      child: ListView(
        padding: Swa.pagePadding,
        children: [
          const Kicker("Today's paper"),
          const SizedBox(height: 4),
          Text('आज का अंक', style: Swa.serif(size: 14, color: Swa.muted, height: 1.3)),
          const SizedBox(height: 8),
          Text('On the ground', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Stories are Arkiv entities. Anyone can query them — no wallet needed to read.',
            style: Swa.serif(size: 15, color: Swa.muted, height: 1.45),
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
              FilterChip(
                label: Text('Corroborated', style: Swa.condensed(size: 12, color: corroboratedOnly ? Swa.magenta : Swa.ink)),
                selected: corroboratedOnly,
                selectedColor: Swa.paper,
                side: BorderSide(color: corroboratedOnly ? Swa.magenta : Swa.line),
                checkmarkColor: Swa.magenta,
                onSelected: (v) => setState(() => corroboratedOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: 'City filter (exact, e.g. Mumbai)',
              isDense: true,
            ),
            onSubmitted: (v) {
              city = v.trim();
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (proof) ...[
            if (error != null) ...[
              TestModeBanner('Could not query Arkiv: $error'),
              const SizedBox(height: 12),
            ],
            TestModeBanner(ProofEdition.banner),
            const SizedBox(height: 12),
            Text('SYNTHETIC DEMO · LAYOUT ONLY · NOT ON-CHAIN', style: Swa.kicker),
            const SizedBox(height: 12),
          ],
          if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (!loading && items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No live stories. They may have expired, or the seed has not run yet.',
                style: Swa.serif(size: 15, color: Swa.muted),
              ),
            ),
          if (lead != null)
            LeadStory(story: lead, cluster: clusters[lead.key], onTap: () => context.go('/s/${lead.key}')),
          if (rest.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Hairline()),
          for (var i = 0; i < rest.length; i++) ...[
            StoryRow(story: rest[i], cluster: clusters[rest[i].key], onTap: () => context.go('/s/${rest[i].key}')),
            if (i != rest.length - 1) const Hairline(),
          ],
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
          color: Swa.paper,
        ),
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: Swa.dateline),
          style: Swa.condensed(size: 13, color: Swa.ink, spacing: 0.4, weight: FontWeight.w500),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o.isEmpty ? 'All $label' : o)))
              .toList(),
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}

class LeadStory extends StatelessWidget {
  final ArkivEntity story;
  final Corroboration? cluster;
  final VoidCallback onTap;
  const LeadStory({super.key, required this.story, required this.onTap, this.cluster});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(story.category.isEmpty ? 'story' : story.category),
          if (cluster != null) CorroborationStamp(cluster!),
          const SizedBox(height: 8),
          Text(
            story.title.isEmpty ? 'Untitled story' : story.title,
            style: Swa.playfair(size: 32, weight: FontWeight.w700, height: 1.12),
          ),
          const SizedBox(height: 8),
          Text(journalistByline(story), style: Swa.byline),
          if (story.mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            StoryImage(story, height: 180),
          ],
          const SizedBox(height: 12),
          Text(
            standfirst(story.body),
            style: Swa.serif(size: 16, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class StoryRow extends StatelessWidget {
  final ArkivEntity story;
  final Corroboration? cluster;
  final VoidCallback onTap;
  const StoryRow({super.key, required this.story, required this.onTap, this.cluster});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(story.category.isEmpty ? 'story' : story.category),
                  if (cluster != null) CorroborationStamp(cluster!),
                  const SizedBox(height: 8),
                  Text(
                    story.title.isEmpty ? 'Untitled story' : story.title,
                    style: Swa.playfair(size: 18, weight: FontWeight.w700, height: 1.22),
                  ),
                  const SizedBox(height: 8),
                  Text(journalistByline(story), style: Swa.byline),
                ],
              ),
            ),
            if (story.mediaUrl.isNotEmpty) ...[
              const SizedBox(width: 12),
              StoryImage(story, height: 72, width: 96),
            ],
          ],
        ),
      ),
    );
  }
}
