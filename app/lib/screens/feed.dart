import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../config.dart';
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
  bool corroboratedOnly = false;
  String? state;
  String? category;
  final clusters = <String, Corroboration>{};

  static const states = [
    '',
    'Maharashtra',
    'Delhi',
    'Karnataka',
    'Himachal Pradesh',
    'Assam',
    'Telangana',
    'Uttar Pradesh',
    'Tamil Nadu',
  ];
  static const cats = ['', 'civic', 'labour', 'environment', 'protest', 'conflict', 'other'];

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
    final desktop = Swa.isDesktop(context);

    return PageWidth(
      max: Swa.maxWidth,
      child: RefreshIndicator(
        onRefresh: _load,
        color: Swa.ink,
        child: ListView(
          padding: Swa.pagePadding,
          children: [
            const Kicker("Today's paper"),
            const SizedBox(height: 6),
            Text('आज का अंक', style: Swa.serif(size: desktop ? 16 : 14, color: Swa.muted, height: 1.3)),
            if (desktop) ...[
              const SizedBox(height: 8),
              Text('On the ground', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Stories are Arkiv entities. Anyone can query them — no wallet needed to read.',
                style: Swa.serif(size: 16.5, color: Swa.muted, height: 1.5),
              ),
            ],
            if (Config.isLocal) ...[
              const SizedBox(height: 16),
              Text(
                'Local Arkiv node · chain 1337. Tiramisu stays the default.',
                style: Swa.demoLine,
              ),
            ],
            const SizedBox(height: 24),
            _FilterRow(
              states: states,
              cats: cats,
              state: state ?? '',
              category: category ?? '',
              corroboratedOnly: corroboratedOnly,
              onState: (v) {
                setState(() => state = v);
                _load();
              },
              onCat: (v) {
                setState(() => category = v);
                _load();
              },
              onCorr: (v) => setState(() => corroboratedOnly = v),
            ),
            const SizedBox(height: 24),
            if (error != null) ...[
              Text(error!, style: Swa.serif(size: 14, color: Swa.muted)),
              const SizedBox(height: 16),
            ],
            if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            if (!loading && items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No live stories. They may have expired, or the seed has not run yet.',
                  style: Swa.serif(size: 16, color: Swa.muted),
                ),
              ),
            if (!loading && lead != null && desktop)
              _DesktopFront(
                lead: lead,
                rest: rest,
                clusters: clusters,
              )
            else if (!loading && lead != null) ...[
              LeadStory(
                story: lead,
                cluster: clusters[lead.key],
                onTap: () => context.go('/s/${lead.key}'),
                photoFirst: true,
                imageHeight: 200,
                headlineSize: 28,
              ),
              if (rest.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Hairline()),
              for (var i = 0; i < rest.length; i++) ...[
                StoryRow(story: rest[i], cluster: clusters[rest[i].key], onTap: () => context.go('/s/${rest[i].key}')),
                if (i != rest.length - 1) const Hairline(),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> states;
  final List<String> cats;
  final String state;
  final String category;
  final bool corroboratedOnly;
  final ValueChanged<String> onState;
  final ValueChanged<String> onCat;
  final ValueChanged<bool> onCorr;
  const _FilterRow({
    required this.states,
    required this.cats,
    required this.state,
    required this.category,
    required this.corroboratedOnly,
    required this.onState,
    required this.onCat,
    required this.onCorr,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in states)
                _TextChip(
                  label: s.isEmpty ? 'All India' : s,
                  selected: state == s,
                  onTap: () => onState(s),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in cats)
                _TextChip(
                  label: c.isEmpty ? 'All desks' : c,
                  selected: category == c,
                  onTap: () => onCat(c),
                ),
              _TextChip(
                label: 'Corroborated',
                selected: corroboratedOnly,
                accent: true,
                onTap: () => onCorr(!corroboratedOnly),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;
  const _TextChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? (accent ? Swa.magenta : Swa.ink) : Swa.muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Center(
          child: Text(
            label,
            style: Swa.ui(
              size: 13,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
              spacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopFront extends StatelessWidget {
  final ArkivEntity lead;
  final List<ArkivEntity> rest;
  final Map<String, Corroboration> clusters;
  const _DesktopFront({required this.lead, required this.rest, required this.clusters});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: LeadStory(
            story: lead,
            cluster: clusters[lead.key],
            onTap: () => context.go('/s/${lead.key}'),
            imageHeight: 340,
            headlineSize: 40,
          ),
        ),
        const SizedBox(width: 32),
        Container(width: 1, color: Swa.line, height: 640),
        const SizedBox(width: 32),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              for (var i = 0; i < rest.length; i++) ...[
                StoryRow(
                  story: rest[i],
                  cluster: clusters[rest[i].key],
                  onTap: () => context.go('/s/${rest[i].key}'),
                  compact: true,
                ),
                if (i != rest.length - 1) const Hairline(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class LeadStory extends StatelessWidget {
  final ArkivEntity story;
  final Corroboration? cluster;
  final VoidCallback onTap;
  final double imageHeight;
  final double headlineSize;
  final bool photoFirst;
  const LeadStory({
    super.key,
    required this.story,
    required this.onTap,
    this.cluster,
    this.imageHeight = 220,
    this.headlineSize = 32,
    this.photoFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final photo = story.mediaUrl.isNotEmpty
        ? Padding(
            padding: EdgeInsets.only(top: photoFirst ? 10 : 16, bottom: photoFirst ? 12 : 0),
            child: StoryImage(story, height: imageHeight),
          )
        : const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(story.category.isEmpty ? 'story' : story.category),
          if (cluster != null) CorroborationStamp(cluster!),
          if (photoFirst) photo,
          const SizedBox(height: 12),
          Text(
            story.title.isEmpty ? 'Untitled story' : story.title,
            style: Swa.playfair(size: headlineSize, weight: FontWeight.w700, height: 1.12),
          ),
          const SizedBox(height: 12),
          Text(journalistByline(story), style: Swa.byline),
          if (!photoFirst) photo,
          const SizedBox(height: 16),
          Text(
            standfirst(story.body),
            style: Swa.serif(size: 17, height: 1.5),
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
  final bool compact;
  const StoryRow({
    super.key,
    required this.story,
    required this.onTap,
    this.cluster,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
                    style: Swa.playfair(size: compact ? 18 : 20, weight: FontWeight.w700, height: 1.22),
                  ),
                  const SizedBox(height: 8),
                  Text(journalistByline(story), style: Swa.byline),
                ],
              ),
            ),
            if (story.mediaUrl.isNotEmpty) ...[
              const SizedBox(width: 16),
              StoryImage(story, height: compact ? 72 : 88, width: compact ? 108 : 128),
            ],
          ],
        ),
      ),
    );
  }
}
