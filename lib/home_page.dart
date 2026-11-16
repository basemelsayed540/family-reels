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
  final VoidCallback? onCompose;
  const HomePage({super.key, required this.profile, this.onCompose});

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
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                _composer(),
                const SizedBox(height: 8),
                _storiesRow(data.stories),
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      const SizedBox(height: 4),
                      _sections(data.videos),
                    ],
                  ),
                ),
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

  Widget _composer() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initialOf(widget.profile.name),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: widget.onCompose,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 40,
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'بتفكر في إيه يا ${widget.profile.name}؟',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'إضافة صور',
            onPressed: widget.onCompose,
            icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF2E9E5B), size: 28),
          ),
        ],
      ),
    );
  }

  Widget _storiesRow(List<StoryGroup> groups) {
    const gradients = <List<Color>>[
      [Color(0xFF1EA0F0), Color(0xFF0A4F8A)],
      [Color(0xFFF5B82E), Color(0xFFC05621)],
      [Color(0xFF3B9B6A), Color(0xFF1D5A3C)],
      [Color(0xFFE0457B), Color(0xFF8A3FD1)],
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      height: 170,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          InkWell(
            onTap: _addStory,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      color: AppColors.yellow,
                      alignment: Alignment.center,
                      child: Text(
                        initialOf(widget.profile.name),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB7791F),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(
                          top: -16,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'أنشئ قصة',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < groups.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: InkWell(
                onTap: () => _openStory(groups[i]),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradients[i % gradients.length],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.pink,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.blue, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initialOf(groups[i].name),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        groups[i].userId == myId ? 'أنت' : groups[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
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
