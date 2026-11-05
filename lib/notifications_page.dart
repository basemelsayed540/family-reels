import 'package:flutter/material.dart';

import 'admin_page.dart';
import 'data.dart';
import 'posts_page.dart';
import 'reels_page.dart';
import 'social.dart';
import 'theme.dart';

/// زر الجرس مع عدّاد الإشعارات غير المقروءة
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotifService.unread,
      builder: (context, count, _) {
        return IconButton(
          tooltip: 'الإشعارات',
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
            NotifService.refresh();
          },
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            child: const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
          ),
        );
      },
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  int _pending = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = rowsOf(
        await sb
            .from('notifications')
            .select('*, profiles!notifications_actor_id_fkey(display_name)')
            .eq('user_id', myId)
            .order('created_at', ascending: false)
            .limit(100),
      );
      var pending = 0;
      if (iAmAdmin) {
        final p = await sb.from('profiles').select('id').eq('status', 'pending');
        pending = (p as List).length;
      }
      if (!mounted) return;
      setState(() {
        _items = rows;
        _pending = pending;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذّر تحميل الإشعارات\n$e';
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await sb
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', myId)
          .eq('is_read', false);
      await _load();
      NotifService.refresh();
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر التنفيذ');
    }
  }

  String _targetLabel(Map<String, dynamic> n) =>
      n['post_id'] != null ? 'منشورك' : 'الفيديو بتاعك';

  String _text(Map<String, dynamic> n) {
    final who = authorOf(n);
    final preview = (n['preview'] ?? '').toString();
    switch (n['type']) {
      case 'comment':
        return '$who علّق على ${_targetLabel(n)}: "$preview"';
      case 'reply':
        return '$who علّق كمان على ${n['post_id'] != null ? 'منشور' : 'فيديو'} علّقت عليه: "$preview"';
      case 'like':
        return '$who أعجبه ${_targetLabel(n)}';
      case 'love':
        return '$who حبّ ${_targetLabel(n)}';
      default:
        return who;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'like':
        return Icons.thumb_up_rounded;
      case 'love':
        return Icons.favorite_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'like':
        return AppColors.blue;
      case 'love':
        return const Color(0xFFE0405A);
      default:
        return const Color(0xFF2F855A);
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final id = n['id'] as String;
    if (n['is_read'] == false) {
      try {
        await sb.from('notifications').update({'is_read': true}).eq('id', id);
      } catch (_) {}
    }
    if (!mounted) return;
    final profile = currentProfile;
    if (n['post_id'] != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(postId: n['post_id'] as String),
        ),
      );
    } else if (n['video_id'] != null && profile != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ReelsPage(
            profile: profile,
            videoId: n['video_id'] as String,
            title: 'الفيديو',
          ),
        ),
      );
    }
    if (mounted) {
      await _load();
      NotifService.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => n['is_read'] == false);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('الإشعارات'),
        actions: [
          if (hasUnread)
            TextButton(onPressed: _markAllRead, child: const Text('تعليم الكل كمقروء')),
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (iAmAdmin && _pending > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                final p = currentProfile;
                                if (p == null) return;
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(builder: (_) => AdminPage(profile: p)),
                                );
                                if (mounted) _load();
                                NotifService.refresh();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_add_alt_1_rounded),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$_pending طلب انضمام جديد في انتظار موافقتك',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_left_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(
                            child: Text(
                              'مفيش إشعارات لسه',
                              style: TextStyle(color: AppColors.muted, fontSize: 16),
                            ),
                          ),
                        ),
                      for (final n in _items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: n['is_read'] == false ? AppColors.lightBlue : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _open(n),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _icon(n['type'].toString()),
                                        color: _color(n['type'].toString()),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _text(n),
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.5,
                                              fontWeight: n['is_read'] == false
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeAgo(n['created_at'] as String),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
}
