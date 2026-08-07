import 'services/audio_player.dart';

/// 全局持有的 TTS 音频处理器（由 main 初始化），
/// 书架页与阅读页共用，用于驱动后台/锁屏播放。
late TtsAudioHandler audioHandler;
