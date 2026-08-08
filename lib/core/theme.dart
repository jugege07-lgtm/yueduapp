import 'package:flutter/material.dart';
import 'constants.dart';

/// 全局纯白主题：根页面固定 #FFFFFF，卡片统一圆角 12 + 轻微阴影
ThemeData buildWhiteTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.white,
    canvasColor: AppColors.white,
    primaryColor: AppColors.text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: AppTheme.cardElevation,
      shadowColor: AppColors.cardShadow,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
    ),
    dividerColor: Colors.transparent,
    useMaterial3: true,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.text,
    ),
  );
}
