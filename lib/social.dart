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

/// خريطة: رقم المنشور/الفيديو -> (رقم المستخدم -> نوع التفاعل)
/// الأنواع: like | love | haha | wow | sad | angry
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
// أنواع الريأكشنز: إعجاب / حب / ضحك / دهشة / حزن / غضب
// ---------------------------------------------------------------------------

class ReactionType {
  final String kind;
  final String emoji;
  final String label;
  final Color color;
  final Color darkColor;
  const ReactionType(
    this.kind,
    this.emoji,
    this.label,
    this.color,
    this.darkColor,
  );
}

const List<ReactionType> reactionTypes = [
  ReactionType('like', '👍', 'إعجاب', AppColors.blue, AppColors.darkAccent),
  ReactionType('love', '❤️', 'حب', Color(0xFFE0405A), Color(0xFFFF6B81)),
  ReactionType('haha', '😂', 'ضحك', Color(0xFFD99400), Color(0xFFFFC94A)),
  ReactionType('wow', '😮', 'دهشة', Color(0xFFE57300), Color(0xFFFFB05A)),
  ReactionType('sad', '😢', 'حزن', Color(0xFF4A7BB7), Color(0xFF8FB8E8)),
  ReactionType('angry', '😡', 'غضب', Color(0xFFD64525), Color(0xFFFF7A5C)),
];

ReactionType reactionTypeOf(String kind) {
  for (final r in reactionTypes) {
    if (r.kind == kind) return r;
  }
  return reactionTypes.first;
}

String? reactionEmojiOf(String kind) {
  for (final r in reactionTypes) {
    if (r.kind == kind) return r.emoji;
  }
  return null;
}

bool isReactionKind(String kind) => reactionEmojiOf(kind) != null;

// ---------------------------------------------------------------------------
// شريط التفاعل: زر إعجاب/ريأكشن + تعليقات
// ضغطة عادية = إعجاب، وضغطة مطوّلة = شريط الريأكشنز الستة.
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

class _ReactionBarState extends State<ReactionBar>
    with SingleTickerProviderStateMixin {
  late Map<String, String> _r;
  late int _comments;

  final GlobalKey _reactionKey = GlobalKey();
  OverlayEntry? _pickerEntry;
  late final AnimationController _pickerCtrl;
  late final Animation<double> _pickerFade;
  late final Animation<double> _pickerScale;
  bool _closingPicker = false;

  static const double _pickerHeight = 56;

  @override
  void initState() {
    super.initState();
    _r = Map<String, String>.of(widget.reactions);
    _comments = widget.commentCount;
    _pickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _pickerFade = CurvedAnimation(
      parent: _pickerCtrl,
      curve: Curves.easeOut,
    );
    _pickerScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _pickerCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant ReactionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameReactions(widget.reactions, oldWidget.reactions)) {
      _r = Map<String, String>.of(widget.reactions);
    }
    if (widget.commentCount != oldWidget.commentCount) {
      _comments = widget.commentCount;
    }
  }

  static bool _sameReactions(
    Map<String, String> a,
    Map<String, String> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    final entry = _pickerEntry;
    _pickerEntry = null;
    try {
      entry?.remove();
    } catch (_) {}
    _pickerCtrl.dispose();
    super.dispose();
  }

  int get _total => _r.length;

  List<ReactionType> _topReactions() {
    if (_r.isEmpty) return <ReactionType>[];
    final counts = <String, int>{};
    for (final k in _r.values) {
      if (isReactionKind(k)) counts[k] = (counts[k] ?? 0) + 1;
    }
    final order = <String, int>{
      for (var i = 0; i < reactionTypes.length; i++) reactionTypes[i].kind: i,
    };
    final list = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return (order[a.key] ?? 99).compareTo(order[b.key] ?? 99);
      });
    return [for (final e in list.take(3)) reactionTypeOf(e.key)];
  }

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

  void _showPicker() {
    if (_pickerEntry != null || _closingPicker) return;
    final box = _reactionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final topLeft = box.localToGlobal(Offset.zero);
    final barWidth = (screen.width - 24).clamp(0.0, 280.0).toDouble();
    const barHeight = _pickerHeight;

    var left = topLeft.dx + box.size.width / 2 - barWidth / 2;
    final maxLeft = screen.width - barWidth - 12;
    if (left < 12) left = 12;
    if (left > maxLeft) left = maxLeft;

    var top = topLeft.dy - barHeight - 8;
    final minTop = mq.padding.top + 8;
    if (top < minTop) {
      top = topLeft.dy + box.size.height + 8;
    }
    final maxTop = screen.height - mq.padding.bottom - barHeight - 8;
    if (top > maxTop) top = maxTop;
    if (top < minTop) top = minTop;

    _pickerEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _closePicker(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: barWidth,
            height: barHeight,
            child: FadeTransition(
              opacity: _pickerFade,
              child: ScaleTransition(
                scale: _pickerScale,
                child: _pickerBar(barWidth),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_pickerEntry!);
    _pickerCtrl.forward(from: 0);
  }

  Future<void> _closePicker({String? select}) async {
    final entry = _pickerEntry;
    if (entry == null || _closingPicker) return;
    _closingPicker = true;
    if (select != null) _react(select);
    try {
      await _pickerCtrl.reverse();
    } catch (_) {}
    if (identical(_pickerEntry, entry)) {
      _pickerEntry = null;
      try {
        entry.remove();
      } catch (_) {}
    }
    _closingPicker = false;
  }

  Widget _pickerBar(double width) {
    final mine = _r[myId];
    final itemWidth = (width - 16) / reactionTypes.length;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: widget.dark ? const Color(0xE61A2838) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: widget.dark ? const Color(0x33FFFFFF) : AppColors.line,
            width: 0.7,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.dark ? 0.38 : 0.16),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final rt in reactionTypes)
              SizedBox(
                width: itemWidth,
                height: 44,
                child: Tooltip(
                  message: rt.label,
                  child: InkResponse(
                    onTap: () => _closePicker(select: rt.kind),
                    radius: 24,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: mine == rt.kind
                            ? rt.color.withOpacity(widget.dark ? 0.30 : 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        rt.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reactionButton(
    ReactionType? mineType,
    Color color,
    List<ReactionType> top3,
  ) {
    final child = widget.vertical
        ? _verticalReaction(mineType, color, top3)
        : _horizontalReaction(mineType, color, top3);
    return Semantics(
      button: true,
      label: mineType == null ? 'إعجاب' : 'تفاعلك: ${mineType.label}',
      hint: 'اضغط للإعجاب، واضغط مطوّلًا لاختيار تفاعل',
      child: InkWell(
        key: _reactionKey,
        onTap: () => _react('like'),
        onLongPress: _showPicker,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }

  Widget _horizontalReaction(
    ReactionType? mineType,
    Color color,
    List<ReactionType> top3,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mineType == null)
            Icon(Icons.thumb_up_outlined, color: color, size: 24)
          else
            Text(mineType.emoji, style: const TextStyle(fontSize: 22)),
          if (_total > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$_total',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
          if (top3.isNotEmpty) ...[
            const SizedBox(width: 6),
            for (final rt in top3)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 1.5),
                child: Text(
                  rt.emoji,
                  style: const TextStyle(fontSize: 12, height: 1.1),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _verticalReaction(
    ReactionType? mineType,
    Color color,
    List<ReactionType> top3,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0x29FFFFFF),
            shape: BoxShape.circle,
            border: mineType == null
                ? null
                : Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: mineType == null
              ? Icon(Icons.thumb_up_outlined, color: color, size: 28)
              : Text(mineType.emoji, style: const TextStyle(fontSize: 27)),
        ),
        const SizedBox(height: 2),
        Text(
          _total > 0 ? '$_total' : ' ',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (top3.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final rt in top3)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 1),
                    child: Text(
                      rt.emoji,
                      style: const TextStyle(fontSize: 11, height: 1.1),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
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

  Widget _commentButton(Color idle) {
    if (widget.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'تعليقات',
            onPressed: _openComments,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x29FFFFFF),
              minimumSize: const Size(52, 52),
            ),
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              color: idle,
              size: 28,
            ),
          ),
          Text(
            _comments > 0 ? '$_comments' : ' ',
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
      message: 'تعليقات',
      child: InkWell(
        onTap: _openComments,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: idle,
                size: 24,
              ),
              if (_comments > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$_comments',
                  style: TextStyle(
                    color: idle,
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
    final mineType = mine == null ? null : reactionTypeOf(mine);
    final idle = widget.dark ? Colors.white : AppColors.muted;
    final activeColor = mineType == null
        ? idle
        : (widget.dark ? mineType.darkColor : mineType.color);
    final top3 = _topReactions();

    final reactionBtn = _reactionButton(mineType, activeColor, top3);
    final commentBtn = _commentButton(idle);

    if (widget.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          reactionBtn,
          const SizedBox(height: 8),
          commentBtn,
        ],
      );
    }
    return Row(children: [reactionBtn, commentBtn]);
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

  Future<void> _edit(Map<String, dynamic> c) async {
    final t = await showEditTextDialog(
      context,
      title: 'تعديل التعليق',
      initial: (c['body'] ?? '').toString(),
      maxLength: 500,
    );
    if (t == null) return;
    try {
      await sb.from('comments').update({'body': t}).eq('id', c['id'] as String);
      await _load();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر التعديل');
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
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => _edit(c),
                                              child: const Padding(
                                                padding: EdgeInsets.fromLTRB(8, 6, 8, 2),
                                                child: Text(
                                                  'تعديل',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.blue,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _delete(c['id'] as String),
                                              child: const Padding(
                                                padding: EdgeInsets.fromLTRB(8, 6, 8, 2),
                                                child: Text(
                                                  'حذف',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFFB3261E),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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

// ---------------------------------------------------------------------------
// صلاحيات التعديل والحذف: صاحب المحتوى أو الأدمن
// ---------------------------------------------------------------------------

bool canManage(Map<String, dynamic> row) => iAmAdmin || row['user_id'] == myId;

/// نافذة تعديل نص. ترجّع النص الجديد، أو null لو اتلغت العملية.
Future<String?> showEditTextDialog(
  BuildContext context, {
  required String title,
  required String initial,
  int maxLength = 1000,
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _EditTextDialog(
      title: title,
      initial: initial,
      maxLength: maxLength,
      allowEmpty: allowEmpty,
    ),
  );
}

class _EditTextDialog extends StatefulWidget {
  final String title;
  final String initial;
  final int maxLength;
  final bool allowEmpty;
  const _EditTextDialog({
    required this.title,
    required this.initial,
    required this.maxLength,
    required this.allowEmpty,
  });

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        maxLength: widget.maxLength,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: compactFilled,
          onPressed: () {
            final t = _c.text.trim();
            if (t.isEmpty && !widget.allowEmpty) return;
            Navigator.of(context).pop(t);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
