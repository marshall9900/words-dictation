import 'package:flutter/material.dart';
import 'constants.dart';

/// App 主题配置（儿童友好配色）
class AppTheme {
  AppTheme._();

  // ── 核心色板（与设计文档一致）─────────────────────────────────────────────
  static const Color primary    = Color(0xFF6C63FF);  // 活力紫
  static const Color secondary  = Color(0xFFFF6584);  // 珊瑚粉
  static const Color success    = Color(0xFF43D787);  // 薄荷绿
  static const Color warning    = Color(0xFFFFB347);  // 暖橙
  static const Color error      = Color(0xFFFF6B6B);  // 柔红
  static const Color bgLight    = Color(0xFFF8F9FF);  // 浅底

  // ── 别名兼容 ────────────────────────────────────────────────────────────
  static const Color primaryColor   = primary;
  static const Color secondaryColor = secondary;
  static const Color accentColor    = primary;
  static const Color backgroundColor = bgLight;
  static const Color errorColor     = error;
  static const Color successColor   = success;
  static const Color warningColor   = warning;

  // ── TTS 语速 ────────────────────────────────────────────────────────────
  static const double ttsRate = AppConstants.ttsRate; // 0.4

  // ── 字体大小（儿童大字）───────────────────────────────────────────────────
  static const double fontSizeLarge  = 28.0;
  static const double fontSizeMedium = 22.0;
  static const double fontSizeSmall = 18.0;

  // ── 圆角 ────────────────────────────────────────────────────────────────
  static const double borderRadius = 16.0;

  static ThemeData get lightTheme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    useMaterial3: true,
    scaffoldBackgroundColor: bgLight,
    appBarTheme: const AppBarTheme(backgroundColor: primary, foregroundColor: Colors.white, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
  );
}
