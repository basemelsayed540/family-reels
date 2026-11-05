import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'data.dart';
import 'notifications_page.dart';
import 'social.dart';
import 'theme.dart';

/// صورة من التخزين الخاص (رابط موقّع) مع عرض بملء الشاشة عند الضغط
class SignedImage extends StatefulWidget {
  final String path;
  const SignedImage({super.key, required this.path});

  @override
  State<SignedImage> createState() => _SignedImageState();
}

class _SignedImageState extends State<SignedImage> {
  late Future<String> _url = signedUrl(widget.path);

  @override
  void didUpdateWidget(covariant SignedImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = signedUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox(
            height: 80,
            child: Center(child: Text('تعذّر تحميل الصورة')),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final url = snap.data!;
        return GestureDetector(
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                body: Center(
                  child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 80,
                child: Center(child: Text('تعذّر تحميل الصورة')),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// بطاقة منشور واحد
class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Map<String, String> reactions;
  final int commentCount;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const PostCard({
    super.key,
    required this.post,
    required this.reactions,
    required this.commentCount,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name = authorOf(post);
    final body = (post['body'] ?? '').toString();
    final imagePath = post['image_path'] as String?;
    final id = post['id'] as String;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initialOf(name),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      timeAgo(post['created_at'] as String),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (onDelete != null || onEdit != null)
                PopupMenuButton<String>(
                  tooltip: 'خيارات',
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    if (onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(fontSize: 16, height: 1.6)),
          ],
          if (imagePath != null && imagePath.isNotEmpty) ...[
            const SizedBox(height: 10),
            SignedImage(path: imagePath),
          ],
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFE3EAF1)),
          ReactionBar(
            key: ValueKey('post-$id'),
            targetId: id,
            isPost: true,
            reactions: reactions,
            commentCount: commentCount,
          ),
        ],
      ),
    );
  }
}

class PostsPage extends StatefulWidget {
  final Profile profile;
  const PostsPage({super.key, required this.profile});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  List<Map<String, dynamic>> _posts = [];
  Map<String, Map<String, String>> _reactions = {};
  Map<String, int> _counts = {};
  bool _loading = true;
  String? _error;
  bool _posting = false;
  File? _image;
  final _picker = ImagePicker();
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final posts = rowsOf(
        await sb
            .from('posts')
            .select('*, profiles!posts_user_id_fkey(display_name)')
            .order('created_at', ascending: false),
      );
      final reactions = await fetchReactions();
      final counts = await fetchCommentCounts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _reactions = reactions;
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل المنشورات\n$e';
      });
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final x = await _picker.pickImage(source: src, maxWidth: 1800, imageQuality: 85);
      if (x != null && mounted) setState(() => _image = File(x.path));
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر اختيار الصورة');
    }
  }

  void _chooseImage() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('من المعرض'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('من الكاميرا'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publish() async {
    final body = _text.text.trim();
    if ((body.isEmpty && _image == null) || _posting) return;
    if (body.length > 1000) {
      showMsg(context, 'المنشور طويل، أقصى حد 1000 حرف');
      return;
    }
    setState(() => _posting = true);
    try {
      String? imagePath;
      final img = _image;
      if (img != null) {
        imagePath = 'posts/${myId}_${DateTime.now().millisecondsSinceEpoch}.${extOf(img.path)}';
        await uploadFile(imagePath, img);
      }
      await sb.from('posts').insert({
        'user_id': myId,
        'body': body,
        if (imagePath != null) 'image_path': imagePath,
      });
      _text.clear();
      _image = null;
      FocusManager.instance.primaryFocus?.unfocus();
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, 'تعذّر نشر المنشور');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> post) async {
    final hasImage = (post['image_path'] ?? '').toString().isNotEmpty;
    final t = await showEditTextDialog(
      context,
      title: 'تعديل المنشور',
      initial: (post['body'] ?? '').toString(),
      allowEmpty: hasImage,
    );
    if (t == null) return;
    try {
      await sb.from('posts').update({'body': t}).eq('id', post['id'] as String);
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر التعديل');
    }
  }

  Future<void> _delete(Map<String, dynamic> post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنشور؟'),
        content: const Text('هيتحذف المنشور مع تعليقاته.'),
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
      final img = post['image_path'] as String?;
      await sb.from('posts').delete().eq('id', post['id'] as String);
      if (img != null && img.isNotEmpty) {
        try {
          await removeFiles([img]);
        } catch (_) {}
      }
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر الحذف');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'المنشورات',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                const NotificationBell(),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _text,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'اكتب حاجة للعيلة...',
                      fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_image != null) ...[
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _image!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          child: IconButton(
                            onPressed: () => setState(() => _image = null),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: compactOutlined,
                        onPressed: _posting ? null : _chooseImage,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('صورة'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: compactFilled,
                        onPressed: _posting ? null : _publish,
                        icon: _posting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: const Text('انشر'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
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
              )
            else if (_posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'لسه مفيش منشورات. اكتب أول منشور!',
                    style: TextStyle(color: AppColors.muted, fontSize: 16),
                  ),
                ),
              )
            else
              for (final p in _posts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: PostCard(
                    key: ValueKey(p['id']),
                    post: p,
                    reactions: _reactions[p['id'] as String] ?? const <String, String>{},
                    commentCount: _counts[p['id'] as String] ?? 0,
                    onDelete: canManage(p) ? () => _delete(p) : null,
                    onEdit: canManage(p) ? () => _edit(p) : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// صفحة منشور واحد (تُفتح من الإشعارات)
class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Map<String, dynamic>? _post;
  Map<String, String> _reactions = {};
  int _count = 0;
  bool _loading = true;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await sb
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(display_name)')
          .eq('id', widget.postId)
          .maybeSingle();
      final reactions = await fetchReactions();
      final counts = await fetchCommentCounts();
      if (!mounted) return;
      setState(() {
        _post = row;
        _missing = row == null;
        _reactions = reactions[widget.postId] ?? <String, String>{};
        _count = counts[widget.postId] ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _missing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.bg, title: const Text('المنشور')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _missing || _post == null
              ? const Center(child: Text('المنشور ده اتحذف أو مش متاح'))
              : Column(
                  children: [
                    Flexible(
                      flex: 2,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: PostCard(
                          post: _post!,
                          reactions: _reactions,
                          commentCount: _count,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: CommentsPanel(isPost: true, targetId: widget.postId),
                    ),
                  ],
                ),
    );
  }
}
