import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

final RegExp _urlRe = RegExp(r'(https?://[^\s]+|www\.[^\s]+)', caseSensitive: false);
const String _trailing = '.,;:!?؟،)]}»"\'';

/// نص بيحوّل أي رابط فيه لرابط يتفتح بالضغط عليه
class LinkText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  const LinkText(this.text, {super.key, this.style, this.maxLines});

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String url) async {
    final fixed = url.toLowerCase().startsWith('http') ? url : 'https://$url';
    try {
      final ok = await launchUrl(Uri.parse(fixed), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showMsg(context, 'تعذّر فتح الرابط');
    } catch (_) {
      if (mounted) showMsg(context, 'تعذّر فتح الرابط');
    }
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _urlRe.allMatches(text)) {
      var url = m.group(0)!;
      var end = m.end;
      while (url.isNotEmpty && _trailing.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
        end--;
      }
      if (url.isEmpty) continue;
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final rec = TapGestureRecognizer()..onTap = () => _open(url);
      _recognizers.add(rec);
      spans.add(
        TextSpan(
          text: url,
          recognizer: rec,
          style: const TextStyle(
            color: AppColors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
      );
      last = end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}
