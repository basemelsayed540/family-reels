import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'theme.dart';

class UpdateInfo {
  final int build;
  final String name;
  final String url;
  const UpdateInfo(this.build, this.name, this.url);
}

/// يرجّع بيانات النسخة الجديدة لو فيه نسخة أحدث من المثبّتة، وإلا null.
Future<UpdateInfo?> fetchUpdate() async {
  try {
    final res = await http
        .get(Uri.parse(AppConfig.versionUrl))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final m = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final remote = (m['build'] as num).toInt();
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;
    if (remote <= current) return null;
    return UpdateInfo(
      remote,
      (m['name'] ?? '').toString(),
      (m['apk_url'] ?? AppConfig.apkUrl).toString(),
    );
  } catch (_) {
    return null;
  }
}

Future<void> checkForUpdate(BuildContext context, {bool manual = false}) async {
  final info = await fetchUpdate();
  if (!context.mounted) return;
  if (info == null) {
    if (manual) showMsg(context, 'أنت على آخر نسخة');
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تحديث جديد متاح'),
      content: Text(
        'نسخة ${info.name} جاهزة. هتتحمّل وتتثبّت فوق النسخة الحالية، وكل بياناتك هتفضل زي ما هي.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('لاحقًا'),
        ),
        FilledButton(
          style: compactFilled,
          onPressed: () {
            launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
            Navigator.of(ctx).pop();
          },
          child: const Text('حدّث الآن'),
        ),
      ],
    ),
  );
}
