import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../arkiv/service.dart';
import '../config.dart';
import '../models.dart';
import '../proof_edition.dart';
import '../theme.dart';
import '../widgets/bits.dart';
import '../widgets/sheets.dart';
import '../widgets/skeleton.dart';

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
      ).timeout(const Duration(seconds: 8), onTimeout: () => const <ArkivEntity>[]);
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

  Future<void> _openFilters() async {
    await showAppSheet<void>(
      context,
      FiltersSheet(
        states: states,
        cats: cats,
        state: state ?? '',
        category: category ?? '',
        corroboratedOnly: corroboratedOnly,
        onApply: (s, c, corr) {
          setState(() {
            state = s;
            category = c;
            corroboratedOnly = corr;
          });
          _load();
        },
      ),
    );
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
            _FilterBar(
              state: state ?? '',
              category: category ?? '',
              corroboratedOnly: corroboratedOnly,
              onAllIndia: () {
                setState(() => state = '');
                _load();
              },
              onCorr: () => setState(() => corroboratedOnly = !corroboratedOnly),
              onClearCat: () {
                setState(() => category = '');
                _load();
              },
              onFilters: _openFilters,
            ),
            if (Config.isLocal) ...[
              const SizedBox(height: 12),
              Text(
                'Local Arkiv node · chain 1337. Arkiv Tiramisu stays the default.',
                style: Swa.demoLine,
              ),
            ],
            const SizedBox(height: 20),
            if (error != null) ErrorNote(sanitizeUi(error!)),
            if (loading) const FeedSkeleton(),
            if (!loading && items.isEmpty)
              const EmptyState(
                icon: SwaI.news,
                title: 'No live stories',
                dek: 'They may have expired, or the seed has not run yet. Pull to refresh.',
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
              if (rest.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Hairline()),
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

class _FilterBar extends StatelessWidget {
  final String state;
  final String category;
  final bool corroboratedOnly;
  final VoidCallback onAllIndia;
  final VoidCallback onCorr;
  final VoidCallback onClearCat;
  final VoidCallback onFilters;
  const _FilterBar({
    required this.state,
    required this.category,
    required this.corroboratedOnly,
    required this.onAllIndia,
    required this.onCorr,
    required this.onClearCat,
    required this.onFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionPill(
                  icon: SwaI.place,
                  label: 'All India',
                  selected: state.isEmpty,
                  onTap: onAllIndia,
                ),
                if (state.isNotEmpty)
                  ActionPill(
                    icon: SwaI.place,
                    label: state,
                    selected: true,
                    onTap: onFilters,
                  ),
                if (category.isNotEmpty)
                  ActionPill(
                    icon: SwaI.feed,
                    label: category,
                    selected: true,
                    onTap: onClearCat,
                  ),
                ActionPill(
                  icon: SwaI.corroborated,
                  label: 'Corroborated',
                  selected: corroboratedOnly,
                  accent: corroboratedOnly,
                  onTap: onCorr,
                ),
              ],
            ),
          ),
        ),
        ActionPill(
          icon: SwaI.filter,
          label: 'Filters',
          onTap: onFilters,
        ),
      ],
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
            padding: EdgeInsets.only(top: photoFirst ? 4 : 16, bottom: photoFirst ? 14 : 0),
            child: StoryImage(story, height: imageHeight),
          )
        : const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoFirst) photo,
          Kicker(story.category.isEmpty ? 'story' : story.category),
          const SizedBox(height: 10),
          Text(
            story.title.isEmpty ? 'Untitled story' : story.title,
            style: Swa.playfair(size: headlineSize, weight: FontWeight.w700, height: 1.12),
          ),
          const SizedBox(height: 10),
          BylineRow(story),
          if (cluster != null && cluster!.ok) CorroborationStamp(cluster!),
          if (!photoFirst) photo,
          const SizedBox(height: 14),
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
                  const SizedBox(height: 8),
                  Text(
                    story.title.isEmpty ? 'Untitled story' : story.title,
                    style: Swa.playfair(size: compact ? 18 : 20, weight: FontWeight.w700, height: 1.22),
                  ),
                  const SizedBox(height: 8),
                  BylineRow(story),
                  if (cluster != null && cluster!.ok) CorroborationStamp(cluster!),
                ],
              ),
            ),
            if (story.mediaUrl.isNotEmpty) ...[
              const SizedBox(width: 16),
              StoryImage(story, height: compact ? 72 : 92, width: compact ? 108 : 132),
            ],
          ],
        ),
      ),
    );
  }
}
