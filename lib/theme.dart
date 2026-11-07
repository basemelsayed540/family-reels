import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';

class AppColors {
  static const blue = Color(0xFF0A74BF); // أزرار ونصوص مميزة
  static const sky = Color(0xFF1EA0F0); // إطارات وأيقونات
  static const bg = Color(0xFFF5F7FA);
  static const ink = Color(0xFF1B1F2A);
  static const muted = Color(0xFF4A5565);
  static const gold = Color(0xFFF5B82E);
  static const line = Color(0xFFDBDFE4);

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(44),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(40),
        side: const BorderSide(color: AppColors.line, width: 1),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700),
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
  minimumSize: const Size(0, 38),
  padding: const EdgeInsets.symmetric(horizontal: 16),
);
final ButtonStyle compactOutlined = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 38),
  padding: const EdgeInsets.symmetric(horizontal: 16),
);

const sectionIcons = <IconData>[
  Icons.groups_rounded,
  Icons.event_rounded,
  Icons.place_rounded,
  Icons.photo_library_rounded,
  Icons.cake_rounded,
  Icons.favorite_rounded,
  Icons.restaurant_rounded,
  Icons.flight_rounded,
  Icons.sports_soccer_rounded,
  Icons.child_care_rounded,
  Icons.mosque_rounded,
  Icons.celebration_rounded,
];

const sectionColors = <Color>[
  AppColors.yellow,
  AppColors.pink,
  AppColors.green,
  AppColors.peach,
  AppColors.lightBlue,
  Color(0xFFE8DDF8),
];

const sectionIconColors = <Color>[
  Color(0xFFB7791F),
  Color(0xFFC0425A),
  Color(0xFF2F855A),
  Color(0xFFC05621),
  Color(0xFF0A74BF),
  Color(0xFF6B46C1),
];

IconData categoryIcon(String key) =>
    sectionIcons[categoryOf(key).icon.abs() % sectionIcons.length];

Color categoryColor(String key) =>
    sectionColors[categoryOf(key).color.abs() % sectionColors.length];

Color categoryIconColor(String key) =>
    sectionIconColors[categoryOf(key).color.abs() % sectionIconColors.length];
