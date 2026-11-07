import 'package:flutter/material.dart';

import 'data.dart';
import 'posts_page.dart';
import 'reels_page.dart';
import 'social.dart';
import 'theme.dart';

/// صفحة المحفوظات: قوائم الحفظ الخاصة بالمستخدم
class SavedPage extends StatefulWidget {
  final Profile profile;
  const SavedPage({super.key, required this.profile});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<Map<String, dynamic>> _cols = [];
  Map<String, int> _counts = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cols = rowsOf(
        await sb.from('collections').select().eq('user_id', myId).order('created_at'),
      );
      final items = rowsOf(await sb.from('saved_items').select('collection_id').eq('user_id', myId));
      final counts = <String, int>{};
      for (final i in items) {
        final k = i['collection_id'] as String;
        counts[k] = (counts[k] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() {
        _cols = cols;
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل المحفوظات. تأكد إنك شغّلت sections_saves.sql';
      });
    }
  }

  Future<void> _create() async {
    final name = await showEditTextDialog(context, title: 'قائمة جديدة', initial: '', maxLength: 40);
    if (name == null) return;
    try {
      await sb.from('collections').insert({'user_id': myId, 'name': name});
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر إنشاء القائمة');
    }
  }

  Future<void> _rename(Map<String, dynamic> c) async {
    final name = await showEditTextDialog(
      context,
      title: 'تعديل اسم القائمة',
      initial: (c['name'] ?? '').toString(),
      maxLength: 40,
    );
    if (name == null) return;
    try {
      await sb.from('collections').update({'name': name}).eq('id', c['id'] as String);
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر التعديل');
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف قائمة ${c['name']}؟'),
        content: const Text('هتتحذف القائمة بس، والمنشورات والفيديوهات نفسها مش هتتأثر.'),
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
      await sb.from('collections').delete().eq('id', c['id'] as String);
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر الحذف');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('المحفوظات'),
        actions: [
          IconButton(
            tooltip: 'قائمة جديدة',
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _cols.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'لسه مفيش محفوظات. اضغط على علامة الحفظ في أي منشور أو فيديو.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _cols.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = _cols[i];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              leading: const Icon(Icons.bookmarks_rounded, color: AppColors.blue),
                              title: Text(
                                (c['name'] ?? '').toString(),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text('${_counts[c['id']] ?? 0} عنصر'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'rename') _rename(c);
                                  if (v == 'delete') _delete(c);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'rename', child: Text('تعديل الاسم')),
                                  PopupMenuItem(value: 'delete', child: Text('حذف القائمة')),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => CollectionPage(
                                      collection: c,
                                      profile: widget.profile,
                                    ),
                                  ),
                                );
                                if (mounted) _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// محتوى قائمة محفوظات واحدة
class CollectionPage extends StatefulWidget {
  final Map<String, dynamic> collection;
  final Profile profile;
  const CollectionPage({super.key, required this.collection, required this.profile});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  // كل عنصر: {'item': saved_items row, 'post': .. أو 'video': ..}
  List<Map<String, dynamic>> _entries = [];
  Map<String, Map<String, String>> _reactions = {};
  Map<String, int> _counts = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = rowsOf(
        await sb
            .from('saved_items')
            .select()
            .eq('collection_id', widget.collection['id'] as String)
            .order('created_at', ascending: false),
      );
      final postIds = [for (final i in items) if (i['post_id'] != null) i['post_id'] as String];
      final videoIds = [for (final i in items) if (i['video_id'] != null) i['video_id'] as String];
      final posts = <String, Map<String, dynamic>>{};
      final videos = <String, Map<String, dynamic>>{};
      if (postIds.isNotEmpty) {
        final rows = rowsOf(
          await sb
              .from('posts')
              .select('*, profiles!posts_user_id_fkey(display_name)')
              .inFilter('id', postIds),
        );
        for (final r in rows) {
          posts[r['id'] as String] = r;
        }
      }
      if (videoIds.isNotEmpty) {
        final rows = rowsOf(
          await sb
              .from('videos')
              .select('*, profiles!videos_user_id_fkey(display_name)')
              .inFilter('id', videoIds),
        );
        for (final r in rows) {
          videos[r['id'] as String] = r;
        }
      }
      final reactions = await fetchReactions();
      final counts = await fetchCommentCounts();
      final entries = <Map<String, dynamic>>[];
      for (final i in items) {
        final p = i['post_id'] != null ? posts[i['post_id']] : null;
        final v = i['video_id'] != null ? videos[i['video_id']] : null;
        if (p == null && v == null) continue;
        entries.add({'item': i, 'post': p, 'video': v});
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _reactions = reactions;
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل القائمة';
      });
    }
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    try {
      await sb.from('saved_items').delete().eq('id', item['id'] as String);
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر الإزالة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text((widget.collection['name'] ?? '').toString()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _entries.isEmpty
                  ? const Center(
                      child: Text('القائمة فاضية', style: TextStyle(color: AppColors.muted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _entries.length,
                        itemBuilder: (context, i) {
                          final e = _entries[i];
                          final item = e['item'] as Map<String, dynamic>;
                          final post = e['post'] as Map<String, dynamic>?;
                          final video = e['video'] as Map<String, dynamic>?;
                          if (post != null) {
                            final id = post['id'] as String;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PostCard(
                                  key: ValueKey('saved-post-$id'),
                                  post: post,
                                  reactions: _reactions[id] ?? const <String, String>{},
                                  commentCount: _counts[id] ?? 0,
                                ),
                                Container(
                                  color: Colors.white,
                                  alignment: AlignmentDirectional.centerEnd,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: TextButton.icon(
                                    onPressed: () => _remove(item),
                                    icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
                                    label: const Text('إزالة من القائمة'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            );
                          }
                          final v = video!;
                          final caption = (v['caption'] ?? '').toString();
                          return Container(
                            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.lightBlue,
                                child: Icon(Icons.play_arrow_rounded, color: AppColors.blue),
                              ),
                              title: Text(caption.isEmpty ? 'فيديو' : caption, maxLines: 2),
                              subtitle: Text('من ${authorOf(v)}'),
                              trailing: IconButton(
                                tooltip: 'إزالة',
                                onPressed: () => _remove(item),
                                icon: const Icon(Icons.bookmark_remove_outlined),
                              ),
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => ReelsPage(
                                    profile: widget.profile,
                                    videoId: v['id'] as String,
                                    title: 'فيديو محفوظ',
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
