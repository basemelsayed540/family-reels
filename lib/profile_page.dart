import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'admin_page.dart';
import 'config.dart';
import 'data.dart';
import 'theme.dart';
import 'saved_page.dart';
import 'update.dart';
import 'upload_page.dart';

class ProfilePage extends StatefulWidget {
  final Profile profile;
  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    }).catchError((_) {});
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color ?? AppColors.blue),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                initialOf(p.name),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            p.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(
            p.isAdmin ? 'الأدمن' : 'عضو',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          _tile(Icons.bookmarks_rounded, 'المحفوظات', () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => SavedPage(profile: p)),
            );
          }),
          const SizedBox(height: 10),
          _tile(Icons.video_call_rounded, 'ارفع فيديو (ريل)', () {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => UploadPage(profile: p, isStory: false),
              ),
            );
          }),
          const SizedBox(height: 10),
          if (p.isAdmin) ...[
            _tile(Icons.admin_panel_settings_rounded, 'طلبات الانضمام والأعضاء والدعوات', () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => AdminPage(profile: p)),
              );
            }),
            const SizedBox(height: 10),
          ],
          _tile(Icons.system_update_rounded, 'فحص التحديثات', () {
            checkForUpdate(context, manual: true);
          }),
          const SizedBox(height: 10),
          _tile(
            Icons.logout_rounded,
            'تسجيل خروج',
            () => sb.auth.signOut(),
            color: const Color(0xFFB3261E),
          ),
          const SizedBox(height: 20),
          Text(
            '${AppConfig.appName} · النسخة $_version',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
