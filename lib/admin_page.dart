import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

class AdminPage extends StatelessWidget {
  final Profile profile;
  const AdminPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          title: const Text('إدارة العيلة'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الطلبات'),
              Tab(text: 'الأعضاء'),
              Tab(text: 'الدعوات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MembersList(profile: profile, pendingOnly: true),
            _MembersList(profile: profile, pendingOnly: false),
            const _InvitesTab(),
          ],
        ),
      ),
    );
  }
}

class _MembersList extends StatefulWidget {
  final Profile profile;
  final bool pendingOnly;
  const _MembersList({required this.profile, required this.pendingOnly});

  @override
  State<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<_MembersList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = rowsOf(
      await sb.from('profiles').select().order('created_at', ascending: false),
    );
    return rows.where((r) {
      if (r['id'] == widget.profile.id) return false;
      final pending = r['status'] == 'pending';
      return widget.pendingOnly ? pending : !pending;
    }).toList();
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await sb.from('profiles').update({'status': status}).eq('id', id);
      await _refresh();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر تنفيذ العملية');
    }
  }

  Future<void> _edit(Map<String, dynamic> r) async {
    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _EditMemberDialog(
        name: (r['display_name'] ?? '').toString(),
        role: (r['role'] ?? 'member').toString(),
        status: (r['status'] ?? 'approved').toString(),
      ),
    );
    if (res == null) return;
    try {
      await sb.from('profiles').update(res).eq('id', r['id'] as String);
      await _refresh();
      if (mounted) showMsg(context, 'تم حفظ التعديل');
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر حفظ التعديل');
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final id = r['id'] as String;
    final name = (r['display_name'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف $name؟'),
        content: const Text(
          'هيتحذف حسابه وكل اللي نشره (فيديوهات وستوري ومنشورات وتعليقات) نهائيًا ومش هينفع تسترجعه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: compactFilled,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // نحذف ملفاته من التخزين الأول
      final paths = <String>[];
      for (final t in ['videos', 'stories']) {
        final rows = rowsOf(await sb.from(t).select('path').eq('user_id', id));
        paths.addAll(rows.map((e) => e['path'] as String));
      }
      final posts = rowsOf(
        await sb.from('posts').select('image_path').eq('user_id', id),
      );
      for (final e in posts) {
        final ip = e['image_path'] as String?;
        if (ip != null && ip.isNotEmpty) paths.add(ip);
      }
      try {
        await removeFiles(paths);
      } catch (_) {}
      await sb.rpc('admin_delete_member', params: {'target': id});
      await _refresh();
      if (mounted) showMsg(context, 'تم حذف العضو');
    } catch (e) {
      if (mounted) showMsg(context, 'تعذّر الحذف. تأكد إنك شغّلت admin_members.sql');
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'مقبول';
      case 'blocked':
        return 'محظور';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return Center(
            child: Text(
              widget.pendingOnly ? 'مفيش طلبات جديدة' : 'مفيش أعضاء لسه',
              style: const TextStyle(fontSize: 16, color: AppColors.muted),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = rows[i];
              final id = r['id'] as String;
              final status = (r['status'] ?? 'pending').toString();
              final name = (r['display_name'] ?? '').toString();
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: categoryColor(categories[i % categories.length].key),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initialOf(name),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'بدون اسم' : name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${_statusLabel(status)}${r['role'] == 'admin' ? ' · مدير' : ''}',
                                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (status != 'approved')
                          Expanded(
                            child: FilledButton(
                              style: compactFilled,
                              onPressed: () => _setStatus(id, 'approved'),
                              child: const Text('قبول'),
                            ),
                          ),
                        if (status == 'pending') const SizedBox(width: 10),
                        if (status == 'pending')
                          Expanded(
                            child: OutlinedButton(
                              style: compactOutlined,
                              onPressed: () => _setStatus(id, 'rejected'),
                              child: const Text('رفض'),
                            ),
                          ),
                        if (status == 'approved')
                          Expanded(
                            child: OutlinedButton(
                              style: compactOutlined,
                              onPressed: () => _setStatus(id, 'blocked'),
                              child: const Text('حظر'),
                            ),
                          ),
                      ],
                    ),
                    if (!widget.pendingOnly) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: compactOutlined,
                              onPressed: () => _edit(r),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('تعديل'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: compactOutlined.copyWith(
                                foregroundColor: const WidgetStatePropertyAll(Color(0xFFB3261E)),
                              ),
                              onPressed: () => _delete(r),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('حذف'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _InvitesTab extends StatefulWidget {
  const _InvitesTab();

  @override
  State<_InvitesTab> createState() => _InvitesTabState();
}

class _InvitesTabState extends State<_InvitesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    return rowsOf(
      await sb.from('invite_codes').select().order('created_at', ascending: false),
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final code = await sb.rpc('create_invite_code');
      await Clipboard.setData(ClipboardData(text: code.toString()));
      if (mounted) showMsg(context, 'تم إنشاء الكود ${code.toString()} ونسخه');
      _reload();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر إنشاء الكود');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.vpn_key_rounded),
            label: const Text('إنشاء كود دعوة جديد'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'ابعت الكود لقريبك. لما يسجّل بيه بيتقبل تلقائيًا، والكود بيتستخدم مرة واحدة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Center(
                  child: Text('مفيش أكواد لسه', style: TextStyle(color: AppColors.muted)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final code = r['code'].toString();
                  final used = r['used_by'] != null;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: used ? const Color(0xFFE9EEF3) : AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            code,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: used ? AppColors.muted : AppColors.ink,
                              decoration: used ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        Text(
                          used ? 'مستخدم' : 'متاح',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        if (!used)
                          IconButton(
                            tooltip: 'نسخ',
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: code));
                              if (context.mounted) showMsg(context, 'تم نسخ الكود');
                            },
                            icon: const Icon(Icons.copy_rounded, size: 20),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


class _EditMemberDialog extends StatefulWidget {
  final String name;
  final String role;
  final String status;
  const _EditMemberDialog({required this.name, required this.role, required this.status});

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.name);
  late String _role = widget.role;
  late String _status = widget.status == 'blocked' ? 'blocked' : 'approved';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل العضو'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 8),
            const Text('الصلاحية'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('عضو'),
                  selected: _role == 'member',
                  onSelected: (_) => setState(() => _role = 'member'),
                ),
                ChoiceChip(
                  label: const Text('مدير'),
                  selected: _role == 'admin',
                  onSelected: (_) => setState(() => _role = 'admin'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('الحالة'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('مقبول'),
                  selected: _status == 'approved',
                  onSelected: (_) => setState(() => _status = 'approved'),
                ),
                ChoiceChip(
                  label: const Text('محظور'),
                  selected: _status == 'blocked',
                  onSelected: (_) => setState(() => _status = 'blocked'),
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
          onPressed: () {
            final n = _c.text.trim();
            if (n.isEmpty) return;
            Navigator.of(context).pop({
              'display_name': n,
              'role': _role,
              'status': _status,
            });
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
