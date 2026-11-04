import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const blue = Color(0xFF0A74BF); // أزرار ونصوص مميزة
  static const sky = Color(0xFF1EA0F0); // إطارات وأيقونات
  static const bg = Color(0xFFEAF4FC);
  static const ink = Color(0xFF1B1F2A);
  static const muted = Color(0xFF4A5565);
  static const gold = Color(0xFFF5B82E);
  static const line = Color(0xFFC9D6E2);

  static const yellow = Color(0xFFFFF0C2);
  static const pink = Color(0xFFFDE1E4);
  static const green = Color(0xFFDDF4E4);
  static const peach = Color(0xFFFFE6D2);
  static const lightBlue = Color(0xFFD9ECFB);

  static const darkBg = Color(0xFF16222F);
  static const darkNav = Color(0xFF101A25);
  static const darkMuted = Color(0xFFAEB9C7);
  static const darkAccent = Color(0xFF5BBCF6);

  static const tileColors = [yellow, pink, green, peach];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.line, width: 2),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// أزرار صغيرة تُستخدم داخل Row أو Dialog (الثيم الأساسي يجعل الزر بعرض كامل)
final ButtonStyle compactFilled = FilledButton.styleFrom(
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 20),
);
final ButtonStyle compactOutlined = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 44),
  padding: const EdgeInsets.symmetric(horizontal: 20),
);

IconData categoryIcon(String key) {
  switch (key) {
    case 'family':
      return Icons.groups_rounded;
    case 'events':
      return Icons.event_rounded;
    case 'trips':
      return Icons.place_rounded;
    default:
      return Icons.photo_library_rounded;
  }
}

Color categoryColor(String key) {
  switch (key) {
    case 'family':
      return AppColors.yellow;
    case 'events':
      return AppColors.pink;
    case 'trips':
      return AppColors.green;
    default:
      return AppColors.peach;
  }
}

Color categoryIconColor(String key) {
  switch (key) {
    case 'family':
      return const Color(0xFFB7791F);
    case 'events':
      return const Color(0xFFC0425A);
    case 'trips':
      return const Color(0xFF2F855A);
    default:
      return const Color(0xFFC05621);
  }
}
