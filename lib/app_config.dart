import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'services/audio_player.dart';

/// 全局持有的音频处理器：
/// - 启动时为纯本地播放器（just_audio，零原生服务注册，避免启动崩溃/白屏）
/// - 用户首次开启听书时，后台尝试升级为 audio_service 版（通知栏/锁屏控制）
late TtsAudioHandler audioHandler;

/// 后台尝试升级为带锁屏控制的 audio_service 版；失败或超时保持本地播放，
/// 不影响听书功能本身。
Future<void> upgradeAudioHandler() async {
  try {
    final h = await AudioService.init(
      builder: () => TtsAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.txtreader.tts',
        androidNotificationChannelName: 'AI 听书',
        androidNotificationOngoing: true,
        notificationColor: Color(0xFFFFFFFF),
      ),
    ).timeout(const Duration(seconds: 8));
    audioHandler = h;
  } catch (_) {
    // 保持本地播放器，不影响听书
  }
}
