import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

/// رفع ريلز أو ستوري (ملف أو أكتر) لأي عضو مقبول
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
  final List<File> _files = [];
  final Map<String, int> _sizes = {};
  int _done = 0;
  String _category = categories.first.key;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _addXFiles(List<XFile> xs, {bool videosOnly = false}) async {
    var skipped = 0;
    for (final x in xs) {
      if (videosOnly && !isVideoPath(x.path)) {
        skipped++;
        continue;
      }
      if (_files.any((f) => f.path == x.path)) continue;
      final f = File(x.path);
      _sizes[f.path] = await f.length();
      _files.add(f);
    }
    if (!mounted) return;
    setState(() {
      _error = skipped > 0 ? 'تم تجاهل $skipped ملف لأنه مش فيديو' : null;
    });
  }

  Future<void> _pickMany({bool videosOnly = false}) async {
    try {
      final xs = await _picker.pickMultipleMedia();
      if (xs.isEmpty) return;
      await _addXFiles(xs, videosOnly: videosOnly);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر فتح الملفات');
    }
  }

  Future<void> _pickOne(Future<XFile?> Function() picker) async {
    try {
      final x = await picker();
      if (x == null) return;
      await _addXFiles([x]);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر فتح الملف');
    }
  }

  void _removeAt(int i) {
    setState(() {
      _sizes.remove(_files[i].path);
      _files.removeAt(i);
    });
  }

  Future<void> _upload() async {
    if (_files.isEmpty) return;
    final tooBig = _files.where((f) => (_sizes[f.path] ?? 0) > AppConfig.maxUploadBytes).length;
    if (tooBig > 0) {
      setState(() => _error = '$tooBig ملف أكبر من 50 ميجا. شيله أو اختار أصغر.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _done = 0;
    });
    final table = widget.isStory ? 'stories' : 'videos';
    final folder = widget.isStory ? 'stories' : 'videos';
    final failed = <File>[];
    for (var i = 0; i < _files.length; i++) {
      final f = _files[i];
      String? uploaded;
      try {
        final path =
            '$folder/${myId}_${DateTime.now().millisecondsSinceEpoch}_$i.${extOf(f.path)}';
        await uploadFile(path, f);
        uploaded = path;
        await sb.from(table).insert({
          'user_id': myId,
          'path': path,
          'caption': _caption.text.trim(),
          if (!widget.isStory) 'category': _category,
        });
        if (mounted) setState(() => _done = i + 1);
      } catch (_) {
        failed.add(f);
        if (uploaded != null) {
          try {
            await removeFiles([uploaded]);
          } catch (_) {}
        }
      }
    }
    if (!mounted) return;
    if (failed.isEmpty) {
      showMsg(
        context,
        widget.isStory
            ? (_files.length > 1 ? 'تم نشر ${_files.length} ستوري' : 'تم نشر الستوري')
            : (_files.length > 1 ? 'تم رفع ${_files.length} فيديو' : 'تم رفع الفيديو'),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _files
          ..clear()
          ..addAll(failed);
        _error = 'فشل رفع ${failed.length} ملف. اتأكد من الاتصال وحاول تاني.';
      });
    }
  }

  String _totalSizeText() {
    final total = _sizes.values.fold<int>(0, (a, b) => a + b);
    return '${(total / (1024 * 1024)).toStringAsFixed(1)} ميجا';
  }

  Widget _pickButton(String label, IconData icon, Future<void> Function() action) {
    return OutlinedButton.icon(
      style: compactOutlined,
      onPressed: _busy ? null : action,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.isStory ? 'ستوري جديدة' : 'رفع فيديو'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_files.isEmpty)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.video_library_outlined, size: 44, color: AppColors.blue),
                    SizedBox(height: 8),
                    Text('اختار ملف أو أكتر من الأزرار تحت'),
                  ],
                ),
              )
            else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _files.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, i) {
                  final f = _files[i];
                  final isVid = isVideoPath(f.path);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: isVid
                            ? Container(
                                color: AppColors.lightBlue,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.movie_rounded,
                                  size: 36,
                                  color: AppColors.blue,
                                ),
                              )
                            : Image.file(f, fit: BoxFit.cover, cacheWidth: 300),
                      ),
                      PositionedDirectional(
                        top: 4,
                        end: 4,
                        child: InkWell(
                          onTap: _busy ? null : () => _removeAt(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_files.length} ملف · ${_totalSizeText()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _pickButton(
                  widget.isStory ? 'صور وفيديوهات من المعرض' : 'فيديوهات من المعرض',
                  Icons.video_library_rounded,
                  () => _pickMany(videosOnly: !widget.isStory),
                ),
                if (widget.isStory) ...[
                  _pickButton(
                    'تصوير فيديو',
                    Icons.videocam_rounded,
                    () => _pickOne(
                      () => _picker.pickVideo(
                        source: ImageSource.camera,
                        maxDuration: const Duration(seconds: 30),
                      ),
                    ),
                  ),
                  _pickButton(
                    'تصوير صورة',
                    Icons.photo_camera_rounded,
                    () => _pickOne(() => _picker.pickImage(source: ImageSource.camera)),
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
              onPressed: (_busy || _files.isEmpty) ? null : _upload,
              child: _busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('جاري الرفع ($_done/${_files.length})...'),
                      ],
                    )
                  : Text(
                      widget.isStory
                          ? (_files.length > 1 ? 'انشر ${_files.length} ستوري' : 'انشر الستوري')
                          : (_files.length > 1 ? 'ارفع ${_files.length} فيديو' : 'ارفع الفيديو'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
