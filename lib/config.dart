// إعدادات عامة. المفتاح هنا هو المفتاح العام (publishable) وآمن في الكود،
// والحماية الفعلية من قواعد الصلاحيات (RLS) في قاعدة البيانات.
class AppConfig {
  static const appName = 'لمّتنا';

  static const supabaseUrl = 'https://nehnurjucexqoczhsysy.supabase.co';
  static const supabaseKey = 'sb_publishable_l5Wmj9BpErBaYcQJI1GvRw_tLgoz_Fw';

  static const bucket = 'media';
  static const maxUploadBytes = 50 * 1024 * 1024; // حد الخطة المجانية

  // رابط التحديثات (GitHub Releases)
  static const releaseBase =
      'https://github.com/basemelsayed540/family-reels/releases/download/latest-apk';
  static const versionUrl = '$releaseBase/version.json';
  static const apkUrl = '$releaseBase/lammatna.apk';
}

class Category {
  final String key;
  final String title;
  final int icon; // رقم الأيقونة في sectionIcons
  final int color; // رقم اللون في sectionColors
  final String? createdBy;
  const Category(this.key, this.title, {this.icon = 0, this.color = 0, this.createdBy});
}

/// الأقسام. بتتحدّث من قاعدة البيانات (جدول sections) وفيه قيم افتراضية لو الجدول مش موجود.
List<Category> categories = [
  const Category('family', 'لمّة العيلة', icon: 0, color: 0),
  const Category('events', 'مناسبات', icon: 1, color: 1),
  const Category('trips', 'رحلات', icon: 2, color: 2),
  const Category('memories', 'ذكريات', icon: 3, color: 3),
];

Category categoryOf(String key) =>
    categories.firstWhere((c) => c.key == key, orElse: () => categories.first);

String categoryTitle(String key) => categoryOf(key).title;
