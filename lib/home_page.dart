import 'package:flutter/material.dart';

import 'admin_page.dart';
import 'config.dart';
import 'data.dart';
import 'reels_page.dart';
import 'stories_page.dart';
import 'theme.dart';
import 'upload_page.dart';

class _HomeData {
  final List<StoryGroup> stories;
  final List<Map<String, dynamic>> videos;
  final int pending;
  final List<String> errors;
  const _HomeData(this.stories, this.videos, this.pending, this.errors);
}

class HomePage extends StatefulWidget {
  final Profile profile;
  final VoidCallback onOpenReels;
  const HomePage({super.key, required this.profile, required this.onOpenReels});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final errors = <String>[];
    var stories = <StoryGroup>[];
    var videos = <Map<String, dynamic>>[];
    var pending = 0;
    try {
      stories = groupStories(await fetchActiveStories());
    } catch (e) {
      errors.add('الستوري: $e');
    }
    try {
      videos = await fetchVideos();
    } catch (e) {
      errors.add('الفيديوهات: $e');
    }
    if (widget.profile.isAdmin) {
      try {
        final rows = await sb.from('profiles').select('id').eq('status', 'pending');
        pending = (rows as List).length;
      } catch (e) {
        errors.add('الطلبات: $e');
      }
    }
    return _HomeData(stories, videos, pending, errors);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  Future<void> _openStory(StoryGroup g) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StoryViewer(group: g, profile: widget.profile),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _addStory() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UploadPage(profile: widget.profile, isStory: true),
      ),
    );
    if (ok == true && mounted) _refresh();
  }

  Future<void> _openAdmin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AdminPage(profile: widget.profile)),
    );
    if (mounted) _refresh();
  }

  void _openCategory(Category c) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReelsPage(profile: widget.profile, category: c.key, title: c.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذّر تحميل الصفحة', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: compactFilled,
                      onPressed: _refresh,
                      child: const Text('حاول تاني'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _header(data.pending),
                const SizedBox(height: 20),
                _storiesRow(data.stories),
                const SizedBox(height: 20),
                _banner(data.videos),
                const SizedBox(height: 22),
                const Text('الأقسام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _sections(data.videos),
                if (data.errors.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(
                      'تنبيه تقني (ابعته للمطوّر):\n${data.errors.join('\n')}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A1F1F)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(int pending) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            initialOf(widget.profile.name),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.blue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلًا يا ${widget.profile.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const Text(
                AppConfig.appName,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (widget.profile.isAdmin)
          IconButton(
            tooltip: 'طلبات الانضمام',
            onPressed: _openAdmin,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: Badge(
              label: Text('$pending'),
              isLabelVisible: pending > 0,
              child: const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
            ),
          ),
      ],
    );
  }

  Widget _storiesRow(List<StoryGroup> groups) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          AddBubble(label: 'ستوريك', onTap: _addStory),
          for (final g in groups)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14),
              child: StoryBubble(
                label: g.userId == myId ? 'أنت' : g.name,
                initial: initialOf(g.name),
                color: categoryColor(categories[g.name.length % categories.length].key),
                onTap: () => _openStory(g),
              ),
            ),
        ],
      ),
    );
  }

  Widget _banner(List<Map<String, dynamic>> videos) {
    final has = videos.isNotEmpty;
    final latest = has ? videos.first : null;
    final title = has ? 'فيديو جديد من ${authorOf(latest!)}' : 'لسه مفيش فيديوهات';
    final sub = has
        ? ((latest!['caption'] ?? '').toString().isEmpty
            ? categoryTitle((latest['category'] ?? 'family').toString())
            : (latest['caption'] as String))
        : (widget.profile.isAdmin
            ? 'ارفع أول فيديو من تبويب حسابي'
            : 'أول ما ينزل فيديو هيظهر هنا');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (has)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'جديد',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFE3F2FC)),
                ),
              ],
            ),
          ),
          if (has) ...[
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.blue,
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: widget.onOpenReels,
              child: const Text('شاهد الآن'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sections(List<Map<String, dynamic>> videos) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        for (final c in categories)
          _SectionTile(
            category: c,
            count: videos.where((v) => v['category'] == c.key).length,
            onTap: () => _openCategory(c),
          ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  final Category category;
  final int count;
  final VoidCallback onTap;
  const _SectionTile({
    required this.category,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: categoryColor(category.key),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(
                  categoryIcon(category.key),
                  color: categoryIconColor(category.key),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$count فيديو',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF3C4654)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
