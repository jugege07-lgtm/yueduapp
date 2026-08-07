import 'package:flutter/material.dart';

/// 全局配色与尺寸常量（纯白卡片风格）
class AppColors {
  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF222222); // 阅读正文黑字
  static const subText = Color(0xFF888888); // 次要信息
  static const track = Color(0xFFEEEEEE); // 进度条底色
  static const cardShadow = Color(0x0A000000); // 轻微阴影
}

/// 卡片与圆角等视觉规范
class AppTheme {
  static const double cardRadius = 12.0; // 所有卡片统一圆角
  static const double cardElevation = 2.0; // 轻微阴影
}

/// 听书倍速参数（硬锁范围）
class TtsSpeed {
  static const double min = 1.0;
  static const double max = 5.0;
  static const double step = 0.1; // 0.1x 步进
  static const int divisions = 40; // (5.0-1.0)/0.1
}

/// 其它常量
class AppConst {
  static const String appTitle = '阅读';
  static const String shelfTitle = '我的小说';
  static const String modelAssetDir = 'assets/tts-model';
}
