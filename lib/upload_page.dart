import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

/// رفع ريل (للأدمن) أو ستوري (لأي عضو مقبول)
class UploadPage extends StatefulWidget {
  final Profile profile;
  final bool isStory;
  const UploadPage({super.key, required this.profile, required this.isStory});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();
  File? _file;
  int _size = 0;
  String _category = categories.first.key;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<XFile?> Function() picker) async {
    try {
      final x = await picker();
      if (x == null) return;
      final f = File(x.path);
      final size = await f.length();
      if (!mounted) return;
      setState(() {
        _file = f;
        _size = size;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر فتح الملف');
    }
  }

  Future<void> _upload() async {
    final f = _file;
    if (f == null) return;
    if (_size > AppConfig.maxUploadBytes) {
      setState(() => _error = 'الملف أكبر من 50 ميجا. اختار ملف أصغر أو قصّر الفيديو.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? uploaded;
    try {
      final folder = widget.isStory ? 'stories' : 'videos';
      final path = '$folder/${myId}_${DateTime.now().millisecondsSinceEpoch}.${extOf(f.path)}';
      await uploadFile(path, f);
      uploaded = path;
      await sb.from(widget.isStory ? 'stories' : 'videos').insert({
        'user_id': myId,
        'path': path,
        'caption': _caption.text.trim(),
        if (!widget.isStory) 'category': _category,
      });
      if (!mounted) return;
      showMsg(context, widget.isStory ? 'تم نشر الستوري' : 'تم رفع الفيديو');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (uploaded != null) {
        try {
          await removeFiles([uploaded]);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذّر الرفع. تأكد من الاتصال وصيغة الملف وحاول تاني.';
      });
    }
  }

  String _sizeText() {
    final mb = _size / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} ميجا';
  }

  Widget _pickButton(String label, IconData icon, Future<XFile?> Function() picker) {
    return OutlinedButton.icon(
      style: compactOutlined,
      onPressed: _busy ? null : () => _pick(picker),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    final isImage = f != null && !isVideoPath(f.path);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.isStory ? 'ستوري جديدة' : 'رفع فيديو'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: f == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.video_library_outlined, size: 48, color: AppColors.blue),
                        SizedBox(height: 8),
                        Text('اختار ملف من الأزرار تحت'),
                      ],
                    )
                  : isImage
                      ? Image.file(f, fit: BoxFit.cover, width: double.infinity, height: 220)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.movie_rounded, size: 52, color: AppColors.blue),
                            const SizedBox(height: 8),
                            Text(
                              f.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
            ),
            if (f != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'الحجم: ${_sizeText()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _pickButton(
                  'فيديو من المعرض',
                  Icons.video_library_rounded,
                  () => _picker.pickVideo(source: ImageSource.gallery),
                ),
                if (widget.isStory) ...[
                  _pickButton(
                    'صورة من المعرض',
                    Icons.photo_library_rounded,
                    () => _picker.pickImage(source: ImageSource.gallery),
                  ),
                  _pickButton(
                    'تصوير فيديو',
                    Icons.videocam_rounded,
                    () => _picker.pickVideo(
                      source: ImageSource.camera,
                      maxDuration: const Duration(seconds: 30),
                    ),
                  ),
                  _pickButton(
                    'تصوير صورة',
                    Icons.photo_camera_rounded,
                    () => _picker.pickImage(source: ImageSource.camera),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _caption,
              maxLines: 2,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
            ),
            if (!widget.isStory) ...[
              const SizedBox(height: 8),
              const Text('القسم', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c.title),
                      selected: _category == c.key,
                      onSelected: (_) => setState(() => _category = c.key),
                      selectedColor: AppColors.lightBlue,
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_busy || f == null) ? null : _upload,
              child: _busy
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('جاري الرفع...'),
                      ],
                    )
                  : Text(widget.isStory ? 'انشر الستوري' : 'ارفع الفيديو'),
            ),
          ],
        ),
      ),
    );
  }
}
