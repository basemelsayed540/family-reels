import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

SupabaseClient get sb => Supabase.instance.client;

String get myId => sb.auth.currentUser?.id ?? '';

String contentTypeFor(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case 'mkv':
      return 'video/x-matroska';
    case '3gp':
      return 'video/3gpp';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return 'application/octet-stream';
  }
}

bool isVideoPath(String path) => contentTypeFor(path).startsWith('video/');

String extOf(String path) {
  final i = path.lastIndexOf('.');
  if (i < 0 || i == path.length - 1) return 'bin';
  return path.substring(i + 1).toLowerCase();
}

String initialOf(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return '؟';
  return String.fromCharCode(n.runes.first);
}

Future<Map<String, dynamic>?> fetchMyProfile() async {
  final row = await sb.from('profiles').select().eq('id', myId).maybeSingle();
  return row;
}

Future<List<Map<String, dynamic>>> fetchVideos({String? category}) async {
  var q = sb.from('videos').select('*, profiles(display_name)');
  if (category != null) {
    q = q.eq('category', category);
  }
  final rows = await q.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
}

Future<List<Map<String, dynamic>>> fetchActiveStories() async {
  final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
  final rows = await sb
      .from('stories')
      .select('*, profiles(display_name)')
      .gt('created_at', cutoff.toIso8601String())
      .order('created_at', ascending: true);
  return List<Map<String, dynamic>>.from(rows);
}

/// ستوري مجمّعة حسب صاحبها (ستوريّاتي أولًا)
class StoryGroup {
  final String userId;
  final String name;
  final List<Map<String, dynamic>> items;
  StoryGroup(this.userId, this.name, this.items);
}

List<StoryGroup> groupStories(List<Map<String, dynamic>> rows) {
  final map = <String, StoryGroup>{};
  for (final r in rows) {
    final uid = r['user_id'] as String;
    final name = ((r['profiles'] as Map?)?['display_name'] as String?) ?? '';
    map.putIfAbsent(uid, () => StoryGroup(uid, name, [])).items.add(r);
  }
  final list = map.values.toList();
  list.sort((a, b) {
    if (a.userId == myId) return -1;
    if (b.userId == myId) return 1;
    final la = DateTime.parse(a.items.last['created_at'] as String);
    final lb = DateTime.parse(b.items.last['created_at'] as String);
    return lb.compareTo(la);
  });
  return list;
}

Future<String> signedUrl(String path) {
  return sb.storage.from(AppConfig.bucket).createSignedUrl(path, 3600);
}

Future<void> uploadFile(String storagePath, File file) async {
  await sb.storage.from(AppConfig.bucket).upload(
        storagePath,
        file,
        fileOptions: FileOptions(
          contentType: contentTypeFor(file.path),
          upsert: false,
        ),
      );
}

Future<void> removeFiles(List<String> paths) async {
  if (paths.isEmpty) return;
  await sb.storage.from(AppConfig.bucket).remove(paths);
}

/// حذف الستوري المنتهية (أقدم من 24 ساعة). الأدمن يحذف الكل، والعضو يحذف ستورياته.
Future<void> cleanupExpiredStories() async {
  try {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    final rows = await sb
        .from('stories')
        .select('id, path')
        .lt('created_at', cutoff.toIso8601String());
    final list = List<Map<String, dynamic>>.from(rows);
    if (list.isEmpty) return;
    await removeFiles(list.map((e) => e['path'] as String).toList());
    await sb
        .from('stories')
        .delete()
        .inFilter('id', list.map((e) => e['id']).toList());
  } catch (_) {
    // تنظيف صامت، لا يؤثر على التطبيق
  }
}

class Profile {
  final String id;
  final String name;
  final String role;
  final String status;
  const Profile({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
  });

  bool get isAdmin => role == 'admin' && status == 'approved';

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        name: (m['display_name'] ?? '').toString(),
        role: (m['role'] ?? 'member').toString(),
        status: (m['status'] ?? 'pending').toString(),
      );
}

List<Map<String, dynamic>> rowsOf(dynamic rows) =>
    List<Map<String, dynamic>>.from(rows as List);

String authorOf(Map<String, dynamic> row) {
  final p = row['profiles'];
  if (p is Map) return (p['display_name'] ?? '').toString();
  return '';
}

String timeAgo(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) return 'من ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'من ${d.inHours} ساعة';
  return 'من ${d.inDays} يوم';
}
