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
  const Category(this.key, this.title);
}

const categories = <Category>[
  Category('family', 'لمّة العيلة'),
  Category('events', 'مناسبات'),
  Category('trips', 'رحلات'),
  Category('memories', 'ذكريات'),
];

String categoryTitle(String key) =>
    categories.firstWhere((c) => c.key == key, orElse: () => categories.first).title;
