import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

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
    barrierDismissible: false,
    builder: (ctx) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  double _progress = 0;
  String? _error;
  String? _status;

  Future<Directory> _downloadDir() async {
    try {
      final d = await getExternalStorageDirectory();
      if (d != null) return d;
    } catch (_) {}
    return getTemporaryDirectory();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
      _status = 'جاري التحميل...';
    });
    final client = http.Client();
    try {
      final dir = await _downloadDir();
      final file = File('${dir.path}/lammatna-update.apk');
      if (await file.exists()) {
        await file.delete();
      }

      final req = http.Request('GET', Uri.parse(widget.info.url));
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _progress = got / total);
        }
      }
      await sink.flush();
      await sink.close();

      if (got < 1024 * 1024) {
        throw Exception('الملف المحمّل غير مكتمل');
      }

      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = 'جاري فتح شاشة التثبيت...';
      });

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'اضغط "تحديث" في شاشة التثبيت، وبعدها افتح التطبيق.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
          _error = 'تعذّر التحديث. لو ظهرت رسالة عن "مصادر غير معروفة" '
              'اسمح للتطبيق بالتثبيت من الإعدادات ثم جرّب تاني.\n$e';
        });
      }
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('تحديث جديد متاح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نسخة ${widget.info.name} جاهزة. هتتحمّل جوه التطبيق وتتثبّت فوق النسخة الحالية، '
              'وكل بياناتك هتفضل زي ما هي.',
            ),
            if (_busy || _status != null) ...[
              const SizedBox(height: 16),
              if (_busy) LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _busy && _progress > 0 && _progress < 1
                        ? '$_status ${(_progress * 100).round()}%'
                        : _status!,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB3261E)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            style: compactFilled,
            onPressed: _busy ? null : _run,
            child: Text(_error != null ? 'حاول تاني' : 'حدّث الآن'),
          ),
        ],
      ),
    );
  }
}
