import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'config.dart';
import 'data.dart';
import 'social.dart';
import 'theme.dart';

class ReelsPage extends StatefulWidget {
  final Profile profile;
  final String? category;
  final String? title;
  final String? videoId;
  const ReelsPage({
    super.key,
    required this.profile,
    this.category,
    this.title,
    this.videoId,
  });

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  List<Map<String, dynamic>> _videos = [];
  Map<String, Map<String, String>> _reactions = {};
  Map<String, int> _counts = {};
  bool _loading = true;
  String? _error;
  int _index = 0;
  final PageController _pc = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var videos = await fetchVideos(category: widget.category);
      if (widget.videoId != null) {
        videos = videos.where((v) => v['id'] == widget.videoId).toList();
      }
      final reactions = await fetchReactions();
      final counts = await fetchCommentCounts();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _reactions = reactions;
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الفيديوهات\n$e';
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> video) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفيديو؟'),
        content: const Text('الفيديو هيتحذف نهائيًا من التطبيق.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: compactFilled,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await removeFiles([video['path'] as String]);
      await sb.from('videos').delete().eq('id', video['id'] as String);
      if (!mounted) return;
      setState(() {
        _videos.removeWhere((v) => v['id'] == video['id']);
        if (_index >= _videos.length) _index = _videos.isEmpty ? 0 : _videos.length - 1;
      });
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر الحذف');
    }
  }

  Future<void> _edit(Map<String, dynamic> video) async {
    final r = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _EditReelDialog(
        caption: (video['caption'] ?? '').toString(),
        category: (video['category'] ?? 'family').toString(),
      ),
    );
    if (r == null) return;
    try {
      await sb.from('videos').update({
        'caption': r['caption'],
        'category': r['category'],
      }).eq('id', video['id'] as String);
      if (!mounted) return;
      setState(() {
        video['caption'] = r['caption'];
        video['category'] = r['category'];
      });
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر التعديل');
    }
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: compactFilled,
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
                child: const Text('حاول تاني'),
              ),
            ],
          ),
        ),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            widget.videoId != null
                ? 'الفيديو ده اتحذف أو مش متاح.'
                : 'لسه مفيش فيديوهات. ارفع أول فيديو من تبويب حسابي.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          ),
        ),
      );
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pc,
      itemCount: _videos.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) {
        final video = _videos[i];
        final id = video['id'] as String;
        return ReelItem(
          key: ValueKey(id),
          video: video,
          active: i == _index,
          reactions: _reactions[id] ?? const <String, String>{},
          commentCount: _counts[id] ?? 0,
          onDelete: canManage(video) ? () => _delete(video) : null,
          onEdit: canManage(video) ? () => _edit(video) : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _body()),
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    if (widget.title != null) const BackButton(color: Colors.white),
                    Text(
                      widget.title ?? 'ريلز',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
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
}

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool active;
  final Map<String, String> reactions;
  final int commentCount;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const ReelItem({
    super.key,
    required this.video,
    required this.active,
    required this.reactions,
    required this.commentCount,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _c;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _start();
    } else if (!widget.active && old.active) {
      _stop();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_c != null || _loading) return;
    _loading = true;
    _error = null;
    try {
      final url = await signedUrl(widget.video['path'] as String);
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted || !widget.active) {
        await c.dispose();
        _loading = false;
        return;
      }
      await c.setLooping(true);
      await c.play();
      setState(() {
        _c = c;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تشغيل الفيديو\n$e';
      });
    }
  }

  void _stop() {
    final c = _c;
    _c = null;
    _loading = false;
    c?.dispose();
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final name = authorOf(widget.video);
    final caption = (widget.video['caption'] ?? '').toString();
    final id = widget.video['id'] as String;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF1F3347)),
        if (c != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),
          )
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (c != null)
          Center(
            child: IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (context, v, _) => AnimatedOpacity(
                  opacity: v.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xE61EA0F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 46, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        PositionedDirectional(
          start: 20,
          end: 92,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.pink,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initialOf(name),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                ),
              ],
              if (c != null) ...[
                const SizedBox(height: 12),
                VideoProgressIndicator(
                  c,
                  allowScrubbing: false,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.darkAccent,
                    bufferedColor: Color(0x40FFFFFF),
                    backgroundColor: Color(0x40FFFFFF),
                  ),
                ),
              ],
            ],
          ),
        ),
        PositionedDirectional(
          end: 14,
          bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReactionBar(
                key: ValueKey('video-$id'),
                targetId: id,
                isPost: false,
                reactions: widget.reactions,
                commentCount: widget.commentCount,
                vertical: true,
                dark: true,
              ),
              if (widget.onEdit != null) ...[
                const SizedBox(height: 4),
                IconButton(
                  tooltip: 'تعديل الفيديو',
                  onPressed: widget.onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x29FFFFFF),
                    minimumSize: const Size(52, 52),
                  ),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 26),
                ),
              ],
              if (widget.onDelete != null) ...[
                const SizedBox(height: 4),
                IconButton(
                  tooltip: 'حذف الفيديو',
                  onPressed: widget.onDelete,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x29FFFFFF),
                    minimumSize: const Size(52, 52),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


class _EditReelDialog extends StatefulWidget {
  final String caption;
  final String category;
  const _EditReelDialog({required this.caption, required this.category});

  @override
  State<_EditReelDialog> createState() => _EditReelDialogState();
}

class _EditReelDialogState extends State<_EditReelDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.caption);
  late String _cat = widget.category;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الفيديو'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              minLines: 1,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(hintText: 'وصف الفيديو'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    label: Text(c.title),
                    selected: _cat == c.key,
                    onSelected: (_) => setState(() => _cat = c.key),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: compactFilled,
          onPressed: () => Navigator.of(context).pop({
            'caption': _c.text.trim(),
            'category': _cat,
          }),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
