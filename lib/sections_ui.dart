import 'dart:math';

import 'package:flutter/material.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

/// إضافة قسم جديد أو تعديل قسم. بترجّع true لو اتحفظ.
Future<bool> showSectionDialog(BuildContext context, {Category? edit}) async {
  final res = await showDialog<_SectionResult>(
    context: context,
    builder: (_) => _SectionDialog(edit: edit),
  );
  if (res == null) return false;
  try {
    if (edit == null) {
      final key = 'c_${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(1000)}';
      await sb.from('sections').insert({
        'key': key,
        'title': res.title,
        'icon': res.icon,
        'color': res.color,
        'created_by': myId,
      });
    } else {
      await sb.from('sections').update({
        'title': res.title,
        'icon': res.icon,
        'color': res.color,
      }).eq('key', edit.key);
    }
    await refreshSections();
    return true;
  } catch (_) {
    if (context.mounted) {
      showMsg(context, 'تعذّر حفظ القسم. تأكد إنك شغّلت sections_saves.sql');
    }
    return false;
  }
}

/// قائمة خيارات القسم (تعديل / حذف). بترجّع true لو حصل تغيير.
Future<bool> showSectionOptions(BuildContext context, Category c) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('تعديل القسم'),
            onTap: () => Navigator.of(ctx).pop('edit'),
          ),
          if (c.key != 'family')
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFB3261E)),
              title: const Text('حذف القسم', style: TextStyle(color: Color(0xFFB3261E))),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  if (choice == 'edit') return showSectionDialog(context, edit: c);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('حذف قسم ${c.title}؟'),
      content: const Text('الفيديوهات اللي فيه مش هتتحذف، هتنتقل لقسم "لمّة العيلة".'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: compactFilled,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await sb.from('sections').delete().eq('key', c.key);
    await refreshSections();
    return true;
  } catch (_) {
    if (context.mounted) showMsg(context, 'تعذّر حذف القسم');
    return false;
  }
}

class _SectionResult {
  final String title;
  final int icon;
  final int color;
  const _SectionResult(this.title, this.icon, this.color);
}

class _SectionDialog extends StatefulWidget {
  final Category? edit;
  const _SectionDialog({this.edit});

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.edit?.title ?? '');
  late int _icon = (widget.edit?.icon ?? 4) % sectionIcons.length;
  late int _color = (widget.edit?.color ?? 4) % sectionColors.length;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.edit == null ? 'قسم جديد' : 'تعديل القسم'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'اسم القسم'),
            ),
            const SizedBox(height: 8),
            const Text('الأيقونة'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < sectionIcons.length; i++)
                  InkWell(
                    onTap: () => setState(() => _icon = i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _icon == i ? AppColors.lightBlue : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _icon == i ? AppColors.blue : AppColors.line,
                          width: _icon == i ? 2 : 1,
                        ),
                      ),
                      child: Icon(sectionIcons[i], size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('اللون'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                for (var i = 0; i < sectionColors.length; i++)
                  InkWell(
                    onTap: () => setState(() => _color = i),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: sectionColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == i ? AppColors.blue : AppColors.line,
                          width: _color == i ? 3 : 1,
                        ),
                      ),
                    ),
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
            final t = _c.text.trim();
            if (t.isEmpty) return;
            Navigator.of(context).pop(_SectionResult(t, _icon, _color));
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
