import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'data.dart';
import 'posts_page.dart';
import 'reels_page.dart';
import 'social.dart';
import 'theme.dart';

/// فتح صفحة شخص (أو صفحتي) على طريقة فيس بوك
void openUserPage(BuildContext context, String userId, String name) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => UserPage(userId: userId, name: name)),
  );
}

class UserPage extends StatefulWidget {
  final String userId;
  final String name;
  const UserPage({super.key, required this.userId, required this.name});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String _name = '';
  String _role = 'member';
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _videos = [];
  Map<String, Map<String, String>> _reactions = {};
  Map<String, int> _counts = {};
  bool _loading = true;
  String? _error;
  int _tab = 0; // 0 منشورات، 1 صور، 2 فيديوهات

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _load();
  }

  Future<void> _load() async {
    try {
      final prof = await sb
          .from('profiles')
          .select('display_name, role')
          .eq('id', widget.userId)
          .maybeSingle();
      final posts = rowsOf(
        await sb
            .from('posts')
            .select('*, profiles!posts_user_id_fkey(display_name)')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false),
      );
      final videos = rowsOf(
        await sb
            .from('videos')
            .select('*, profiles!videos_user_id_fkey(display_name)')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false),
      );
      final reactions = await fetchReactions();
      final counts = await fetchCommentCounts();
      if (!mounted) return;
      setState(() {
        if (prof != null) {
          _name = (prof['display_name'] ?? widget.name).toString();
          _role = (prof['role'] ?? 'member').toString();
        }
        _posts = posts;
        _videos = videos;
        _reactions = reactions;
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الصفحة';
      });
    }
  }

  /// كل صور المنشورات: كل عنصر مسار صورة
  List<String> get _photos => [
        for (final p in _posts) ...postImagePaths(p),
      ];

  Widget _header() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 110,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF1EA0F0), Color(0xFF0A4F8A)],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  top: 62,
                  child: Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initialOf(_name),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB7791F),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (_role == 'admin')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'مدير العيلة',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blue,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('${_posts.length}', 'منشور'),
              _stat('${_photos.length}', 'صورة'),
              _stat('${_videos.length}', 'فيديو'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _tabBtn(0, 'المنشورات', Icons.article_outlined),
              _tabBtn(1, 'الصور', Icons.photo_outlined),
              _tabBtn(2, 'الفيديوهات', Icons.play_circle_outline_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String n, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(n, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _tabBtn(int i, String label, IconData icon) {
    final on = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = i),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: on ? AppColors.blue : AppColors.line,
                width: on ? 3 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: on ? AppColors.blue : AppColors.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? AppColors.blue : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (_tab == 0) {
      if (_posts.isEmpty) return [_empty('لسه مفيش منشورات')];
      return [
        SliverList.builder(
          itemCount: _posts.length,
          itemBuilder: (context, i) {
            final p = _posts[i];
            final id = p['id'] as String;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PostCard(
                key: ValueKey('u-post-$id'),
                post: p,
                reactions: _reactions[id] ?? const <String, String>{},
                commentCount: _counts[id] ?? 0,
              ),
            );
          },
        ),
      ];
    }
    if (_tab == 1) {
      final photos = _photos;
      if (photos.isEmpty) return [_empty('لسه مفيش صور')];
      return [
        SliverPadding(
          padding: const EdgeInsets.only(top: 2),
          sliver: SliverGrid.builder(
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, i) => InkWell(
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => _PhotoViewer(paths: photos, start: i),
                ),
              ),
              child: _PhotoThumb(path: photos[i]),
            ),
          ),
        ),
      ];
    }
    if (_videos.isEmpty) return [_empty('لسه مفيش فيديوهات')];
    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 2),
        sliver: SliverGrid.builder(
          itemCount: _videos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, i) {
            final v = _videos[i];
            return InkWell(
              onTap: () {
                final me = currentProfile;
                if (me == null) return;
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ReelsPage(
                      profile: me,
                      userId: widget.userId,
                      startId: v['id'] as String,
                      title: _name,
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumb(path: v['path'] as String),
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 34),
                  ),
                  if ((v['caption'] ?? '').toString().isNotEmpty)
                    PositionedDirectional(
                      start: 6,
                      end: 6,
                      bottom: 6,
                      child: Text(
                        v['caption'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(_name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: compactFilled,
                        onPressed: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        child: const Text('حاول تاني'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _header()),
                      ..._content(),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }
}

/// صورة مصغّرة من التخزين الخاص
class _PhotoThumb extends StatefulWidget {
  final String path;
  const _PhotoThumb({required this.path});

  @override
  State<_PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<_PhotoThumb> {
  late final Future<String> _url = signedUrl(widget.path);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(color: const Color(0xFFE4E6EB));
        }
        return Image.network(
          snap.data!,
          fit: BoxFit.cover,
          cacheWidth: 360,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE4E6EB)),
        );
      },
    );
  }
}

/// عارض صور بملء الشاشة مع تمرير
class _PhotoViewer extends StatefulWidget {
  final List<String> paths;
  final int start;
  const _PhotoViewer({required this.paths, required this.start});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_i + 1}/${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => FutureBuilder<String>(
          future: signedUrl(widget.paths[i]),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            return InteractiveViewer(
              child: Center(child: Image.network(snap.data!, fit: BoxFit.contain)),
            );
          },
        ),
      ),
    );
  }
}

/// صورة مصغّرة من أول لقطة في الفيديو (بتتخزّن مؤقتًا)
class VideoThumb extends StatefulWidget {
  final String path;
  const VideoThumb({super.key, required this.path});

  static final Map<String, Uint8List> _cache = {};

  @override
  State<VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<VideoThumb> {
  late final Future<Uint8List?> _future = _load();

  Future<Uint8List?> _load() async {
    final cached = VideoThumb._cache[widget.path];
    if (cached != null) return cached;
    try {
      final url = await signedUrl(widget.path);
      final data = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 360,
        quality: 60,
        timeMs: 300,
      );
      if (data != null) VideoThumb._cache[widget.path] = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return Container(
            color: const Color(0xFF1F3347),
            alignment: Alignment.center,
            child: snap.connectionState == ConnectionState.done
                ? const Icon(Icons.movie_rounded, color: Colors.white38, size: 30)
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ),
          );
        }
        return Image.memory(data, fit: BoxFit.cover);
      },
    );
  }
}
