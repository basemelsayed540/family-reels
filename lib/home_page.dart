import 'package:flutter/material.dart';

import 'config.dart';
import 'data.dart';
import 'notifications_page.dart';
import 'reels_page.dart';
import 'sections_ui.dart';
import 'social.dart';
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
  const HomePage({super.key, required this.profile});

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
    await refreshSections();
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

  Future<void> _addSection() async {
    if (await showSectionDialog(context)) _refresh();
  }

  Future<void> _manageSection(Category c) async {
    final mine = iAmAdmin || (c.createdBy != null && c.createdBy == myId);
    if (!mine) {
      showMsg(context, 'تعديل القسم للمدير أو لمن أنشأه');
      return;
    }
    if (await showSectionOptions(context, c)) _refresh();
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              children: [
                _header(data.pending),
                const SizedBox(height: 12),
                _storiesRow(data.stories),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'الأقسام',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('قسم جديد'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            initialOf(widget.profile.name),
            style: const TextStyle(
              fontSize: 16,
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
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const NotificationBell(),
      ],
    );
  }

  Widget _storiesRow(List<StoryGroup> groups) {
    return SizedBox(
      height: 90,
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

  Widget _sections(List<Map<String, dynamic>> videos) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [
        for (final c in categories)
          _SectionTile(
            category: c,
            count: videos.where((v) => v['category'] == c.key).length,
            onTap: () => _openCategory(c),
            onLongPress: () => _manageSection(c),
          ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  final Category category;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _SectionTile({
    required this.category,
    required this.count,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: categoryColor(category.key),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
