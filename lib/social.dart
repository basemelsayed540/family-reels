import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'theme.dart';

/// بروفايل المستخدم الحالي (يتحدد عند فتح التطبيق)
Profile? currentProfile;

bool get iAmAdmin => currentProfile?.isAdmin ?? false;

// ---------------------------------------------------------------------------
// بيانات التفاعلات والتعليقات
// ---------------------------------------------------------------------------

/// خريطة: رقم المنشور/الفيديو -> (رقم المستخدم -> نوع التفاعل like|love)
Future<Map<String, Map<String, String>>> fetchReactions() async {
  final rows = rowsOf(await sb.from('reactions').select('user_id, post_id, video_id, kind'));
  final out = <String, Map<String, String>>{};
  for (final r in rows) {
    final target = (r['post_id'] ?? r['video_id']) as String;
    (out[target] ??= <String, String>{})[r['user_id'] as String] = r['kind'] as String;
  }
  return out;
}

/// خريطة: رقم المنشور/الفيديو -> عدد التعليقات
Future<Map<String, int>> fetchCommentCounts() async {
  final rows = rowsOf(await sb.from('comments').select('post_id, video_id'));
  final out = <String, int>{};
  for (final r in rows) {
    final target = (r['post_id'] ?? r['video_id']) as String;
    out[target] = (out[target] ?? 0) + 1;
  }
  return out;
}

Future<void> setReaction({
  required bool isPost,
  required String targetId,
  required String? current,
  required String kind,
}) async {
  final col = isPost ? 'post_id' : 'video_id';
  if (current == kind) {
    await sb.from('reactions').delete().eq(col, targetId).eq('user_id', myId);
  } else if (current != null) {
    await sb.from('reactions').update({'kind': kind}).eq(col, targetId).eq('user_id', myId);
  } else {
    await sb.from('reactions').insert({'user_id': myId, col: targetId, 'kind': kind});
  }
}

// ---------------------------------------------------------------------------
// عدّاد الإشعارات (بيتحدّث كل 25 ثانية والتطبيق مفتوح)
// ---------------------------------------------------------------------------

class NotifService {
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);
  static Timer? _timer;

  static void start() {
    stop();
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => refresh());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> refresh() async {
    try {
      final rows =
          await sb.from('notifications').select('id').eq('user_id', myId).eq('is_read', false);
      var n = (rows as List).length;
      if (iAmAdmin) {
        final pending = await sb.from('profiles').select('id').eq('status', 'pending');
        n += (pending as List).length;
      }
      unread.value = n;
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// شريط التفاعل: إعجاب / قلب / تعليقات
// ---------------------------------------------------------------------------

class ReactionBar extends StatefulWidget {
  final String targetId;
  final bool isPost;
  final Map<String, String> reactions;
  final int commentCount;
  final bool vertical;
  final bool dark;
  const ReactionBar({
    super.key,
    required this.targetId,
    required this.isPost,
    required this.reactions,
    required this.commentCount,
    this.vertical = false,
    this.dark = false,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  late Map<String, String> _r;
  late int _comments;

  @override
  void initState() {
    super.initState();
    _r = Map<String, String>.of(widget.reactions);
    _comments = widget.commentCount;
  }

  int _count(String kind) => _r.values.where((k) => k == kind).length;

  Future<void> _react(String kind) async {
    final before = Map<String, String>.of(_r);
    final current = _r[myId];
    setState(() {
      if (current == kind) {
        _r.remove(myId);
      } else {
        _r[myId] = kind;
      }
    });
    try {
      await setReaction(
        isPost: widget.isPost,
        targetId: widget.targetId,
        current: current,
        kind: kind,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _r = before);
      showMsg(context, 'تعذّر تنفيذ العملية');
    }
  }

  Future<void> _openComments() async {
    await showCommentsSheet(
      context,
      isPost: widget.isPost,
      targetId: widget.targetId,
      onCount: (n) {
        if (mounted) setState(() => _comments = n);
      },
    );
  }

  Widget _button({
    required IconData icon,
    required Color color,
    required int count,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    if (widget.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tooltip,
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x29FFFFFF),
              minimumSize: const Size(52, 52),
            ),
            icon: Icon(icon, color: color, size: 28),
          ),
          Text(
            count > 0 ? '$count' : ' ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = _r[myId];
    final idle = widget.dark ? Colors.white : AppColors.muted;
    final likeOn = widget.dark ? AppColors.darkAccent : AppColors.blue;
    final loveOn = widget.dark ? const Color(0xFFFF6B81) : const Color(0xFFE0405A);

    final likeBtn = _button(
      icon: mine == 'like' ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
      color: mine == 'like' ? likeOn : idle,
      count: _count('like'),
      tooltip: 'إعجاب',
      onTap: () => _react('like'),
    );
    final loveBtn = _button(
      icon: mine == 'love' ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: mine == 'love' ? loveOn : idle,
      count: _count('love'),
      tooltip: 'قلب',
      onTap: () => _react('love'),
    );
    final commentBtn = _button(
      icon: Icons.chat_bubble_outline_rounded,
      color: idle,
      count: _comments,
      tooltip: 'تعليقات',
      onTap: _openComments,
    );

    if (widget.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          likeBtn,
          const SizedBox(height: 8),
          loveBtn,
          const SizedBox(height: 8),
          commentBtn,
        ],
      );
    }
    return Row(
      children: [likeBtn, loveBtn, commentBtn],
    );
  }
}

// ---------------------------------------------------------------------------
// التعليقات
// ---------------------------------------------------------------------------

Future<void> showCommentsSheet(
  BuildContext context, {
  required bool isPost,
  required String targetId,
  required ValueChanged<int> onCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'التعليقات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: CommentsPanel(
                  isPost: isPost,
                  targetId: targetId,
                  onCount: onCount,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class CommentsPanel extends StatefulWidget {
  final bool isPost;
  final String targetId;
  final ValueChanged<int>? onCount;
  const CommentsPanel({
    super.key,
    required this.isPost,
    required this.targetId,
    this.onCount,
  });

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _sending = false;
  final _text = TextEditingController();

  String get _col => widget.isPost ? 'post_id' : 'video_id';

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
      final rows = rowsOf(
        await sb
            .from('comments')
            .select('id, user_id, body, created_at, profiles!comments_user_id_fkey(display_name)')
            .eq(_col, widget.targetId)
            .order('created_at', ascending: true),
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
      widget.onCount?.call(rows.length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    if (body.length > 500) {
      showMsg(context, 'التعليق طويل، أقصى حد 500 حرف');
      return;
    }
    setState(() => _sending = true);
    try {
      await sb.from('comments').insert({
        'user_id': myId,
        _col: widget.targetId,
        'body': body,
      });
      _text.clear();
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر إرسال التعليق');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await sb.from('comments').delete().eq('id', id);
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر الحذف');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'لسه مفيش تعليقات. كن أول واحد!',
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = _items[i];
                        final name = authorOf(c);
                        final mineOrAdmin = c['user_id'] == myId || iAmAdmin;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.yellow,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initialOf(name),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeAgo(c['created_at'] as String),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (c['body'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 15, height: 1.5),
                                    ),
                                    if (mineOrAdmin)
                                      Align(
                                        alignment: AlignmentDirectional.centerEnd,
                                        child: InkWell(
                                          onTap: () => _delete(c['id'] as String),
                                          child: const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              'حذف',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFB3261E),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'اكتب تعليق...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'إرسال',
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(50, 50),
                  ),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
