import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'data.dart';
import 'social.dart';
import 'theme.dart';
import 'upload_page.dart';

/// دايرة ستوري عليها إطار أزرق
class StoryBubble extends StatelessWidget {
  final String label;
  final String initial;
  final Color color;
  final VoidCallback onTap;
  const StoryBubble({
    super.key,
    required this.label,
    required this.initial,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFF5B82E), Color(0xFFE0457B), Color(0xFF8A3FD1)],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Container(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر إضافة ستوري (دايرة بإطار منقّط)
class AddBubble extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AddBubble({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.blue, width: 2),
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.blue, size: 30),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class StoriesPage extends StatefulWidget {
  final Profile profile;
  const StoriesPage({super.key, required this.profile});

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  late Future<List<StoryGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<StoryGroup>> _load() async => groupStories(await fetchActiveStories());

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  Future<void> _add() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UploadPage(profile: widget.profile, isStory: true),
      ),
    );
    if (ok == true && mounted) _refresh();
  }

  Future<void> _open(StoryGroup g) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StoryViewer(group: g, profile: widget.profile),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الستوري',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.icon(
                  style: compactFilled,
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('أضف ستوري'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'الستوري بتختفي بعد 24 ساعة.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<StoryGroup>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: FilledButton(
                        style: compactFilled,
                        onPressed: _refresh,
                        child: const Text('حاول تاني'),
                      ),
                    );
                  }
                  final groups = snap.data ?? const <StoryGroup>[];
                  if (groups.isEmpty) {
                    return const Center(
                      child: Text(
                        'مفيش ستوري دلوقتي. كن أول واحد!',
                        style: TextStyle(fontSize: 16, color: AppColors.muted),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final g = groups[i];
                        final last = g.items.last['created_at'] as String;
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            onTap: () => _open(g),
                            borderRadius: BorderRadius.circular(22),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.sky, width: 3),
                                      color: AppColors.yellow,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initialOf(g.name),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          g.userId == myId ? 'ستورياتك' : g.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${g.items.length} ستوري · ${timeAgo(last)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عارض الستوري بملء الشاشة: اضغط يمين للتالي ويسار للسابق
class StoryViewer extends StatefulWidget {
  final StoryGroup group;
  final Profile profile;
  const StoryViewer({super.key, required this.group, required this.profile});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  int _i = 0;
  bool _loading = true;
  String? _error;
  String? _imageUrl;
  VideoPlayerController? _c;
  Timer? _timer;
  double _progress = 0;
  bool _advancing = false;
  int _token = 0;

  List<Map<String, dynamic>> get _items => widget.group.items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(0));
  }

  @override
  void dispose() {
    _token++;
    _timer?.cancel();
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  Future<void> _load(int i) async {
    if (!mounted) return;
    final token = ++_token;
    _timer?.cancel();
    _timer = null;
    final old = _c;
    _c = null;
    old?.removeListener(_tick);
    _advancing = false;
    setState(() {
      _i = i;
      _loading = true;
      _error = null;
      _imageUrl = null;
      _progress = 0;
    });
    await old?.dispose();
    if (!mounted || token != _token) return;

    final path = _items[i]['path'] as String;
    try {
      final url = await signedUrl(path);
      if (!mounted || token != _token) return;
      if (isVideoPath(path)) {
        final c = VideoPlayerController.networkUrl(Uri.parse(url));
        await c.initialize();
        if (!mounted || token != _token) {
          await c.dispose();
          return;
        }
        c.addListener(_tick);
        await c.play();
        setState(() {
          _c = c;
          _loading = false;
        });
      } else {
        setState(() {
          _imageUrl = url;
          _loading = false;
        });
        _startImageTimer(token);
      }
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تشغيل الستوري';
      });
    }
  }

  void _startImageTimer(int token) {
    const total = 5000;
    var elapsed = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted || token != _token) {
        t.cancel();
        return;
      }
      elapsed += 50;
      setState(() => _progress = (elapsed / total).clamp(0.0, 1.0));
      if (elapsed >= total) {
        t.cancel();
        _next();
      }
    });
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    if (!v.isInitialized || v.duration.inMilliseconds <= 0) return;
    final p = v.position.inMilliseconds / v.duration.inMilliseconds;
    setState(() => _progress = p.clamp(0.0, 1.0));
    if (!_advancing && v.position >= v.duration - const Duration(milliseconds: 250)) {
      _advancing = true;
      _next();
    }
  }

  void _next() {
    if (_i + 1 < _items.length) {
      _load(_i + 1);
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    _load(_i > 0 ? _i - 1 : 0);
  }

  bool get _canDelete {
    final item = _items[_i];
    return widget.profile.isAdmin || item['user_id'] == myId;
  }

  Future<void> _edit() async {
    final item = _items[_i];
    final t = await showEditTextDialog(
      context,
      title: 'تعديل وصف الستوري',
      initial: (item['caption'] ?? '').toString(),
      maxLength: 200,
      allowEmpty: true,
    );
    if (t == null) return;
    try {
      await sb.from('stories').update({'caption': t}).eq('id', item['id'] as String);
      if (mounted) setState(() => item['caption'] = t);
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر التعديل');
    }
  }

  Future<void> _delete() async {
    final item = _items[_i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الستوري؟'),
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
      await removeFiles([item['path'] as String]);
      await sb.from('stories').delete().eq('id', item['id'] as String);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر الحذف');
    }
  }

  Widget _media() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 16)),
      );
    }
    final c = _c;
    if (c != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    }
    if (_imageUrl != null) {
      return Center(child: Image.network(_imageUrl!, fit: BoxFit.contain));
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_i];
    final caption = (item['caption'] ?? '').toString();
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (d.globalPosition.dx > width / 2) {
                _next();
              } else {
                _prev();
              }
            },
            child: _media(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      for (var j = 0; j < _items.length; j++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: j < _i ? 1 : (j == _i ? _progress : 0),
                                minHeight: 4,
                                backgroundColor: const Color(0x55FFFFFF),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.yellow,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initialOf(widget.group.name),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              timeAgo(item['created_at'] as String),
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canDelete)
                        IconButton(
                          tooltip: 'تعديل',
                          onPressed: _edit,
                          icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        ),
                      if (_canDelete)
                        IconButton(
                          tooltip: 'حذف',
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (caption.isNotEmpty)
            PositionedDirectional(
              start: 20,
              end: 20,
              bottom: 36,
              child: IgnorePointer(
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
