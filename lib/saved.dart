import 'package:flutter/material.dart';

import 'data.dart';
import 'social.dart';
import 'theme.dart';

/// زر الحفظ (علامة مرجعية) للمنشورات والفيديوهات
class SaveButton extends StatelessWidget {
  final String? postId;
  final String? videoId;
  final Color? color;
  final bool filledBg;
  const SaveButton({
    super.key,
    this.postId,
    this.videoId,
    this.color,
    this.filledBg = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'حفظ',
      onPressed: () => showSaveSheet(context, postId: postId, videoId: videoId),
      style: filledBg
          ? IconButton.styleFrom(
              backgroundColor: const Color(0x29FFFFFF),
              minimumSize: const Size(52, 52),
            )
          : null,
      icon: Icon(
        Icons.bookmark_border_rounded,
        color: color ?? AppColors.muted,
        size: filledBg ? 28 : 24,
      ),
    );
  }
}

Future<void> showSaveSheet(BuildContext context, {String? postId, String? videoId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SaveSheet(postId: postId, videoId: videoId),
  );
}

class _SaveSheet extends StatefulWidget {
  final String? postId;
  final String? videoId;
  const _SaveSheet({this.postId, this.videoId});

  @override
  State<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends State<_SaveSheet> {
  List<Map<String, dynamic>> _cols = [];
  final Set<String> _in = {};
  bool _loading = true;
  String? _error;

  String get _col => widget.postId != null ? 'post_id' : 'video_id';
  String get _target => (widget.postId ?? widget.videoId)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var cols = rowsOf(
        await sb.from('collections').select().eq('user_id', myId).order('created_at'),
      );
      if (cols.isEmpty) {
        final row = await sb
            .from('collections')
            .insert({'user_id': myId, 'name': 'المحفوظات'})
            .select()
            .single();
        cols = [Map<String, dynamic>.from(row)];
      }
      final saved = rowsOf(
        await sb
            .from('saved_items')
            .select('collection_id')
            .eq('user_id', myId)
            .eq(_col, _target),
      );
      if (!mounted) return;
      setState(() {
        _cols = cols;
        _in
          ..clear()
          ..addAll(saved.map((e) => e['collection_id'] as String));
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل القوائم. تأكد إنك شغّلت sections_saves.sql';
      });
    }
  }

  Future<void> _toggle(Map<String, dynamic> c) async {
    final id = c['id'] as String;
    try {
      if (_in.contains(id)) {
        await sb.from('saved_items').delete().eq('collection_id', id).eq(_col, _target);
        setState(() => _in.remove(id));
      } else {
        await sb.from('saved_items').insert({
          'collection_id': id,
          'user_id': myId,
          _col: _target,
        });
        setState(() => _in.add(id));
        if (mounted) showMsg(context, 'تم الحفظ في ${c['name']}');
      }
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر الحفظ');
    }
  }

  Future<void> _newList() async {
    final name = await showEditTextDialog(
      context,
      title: 'قائمة جديدة',
      initial: '',
      maxLength: 40,
    );
    if (name == null) return;
    try {
      final row = await sb
          .from('collections')
          .insert({'user_id': myId, 'name': name})
          .select()
          .single();
      await sb.from('saved_items').insert({
        'collection_id': row['id'],
        'user_id': myId,
        _col: _target,
      });
      await _load();
      if (mounted) showMsg(context, 'تم الحفظ في $name');
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر إنشاء القائمة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'احفظ في...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in _cols)
                      ListTile(
                        leading: Icon(
                          _in.contains(c['id']) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: AppColors.blue,
                        ),
                        title: Text((c['name'] ?? '').toString()),
                        trailing: _in.contains(c['id'])
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.blue)
                            : null,
                        onTap: () => _toggle(c),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.blue),
              title: const Text('قائمة جديدة'),
              onTap: _loading ? null : _newList,
            ),
          ],
        ),
      ),
    );
  }
}
