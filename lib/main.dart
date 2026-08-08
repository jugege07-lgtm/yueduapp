import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'core/theme.dart';
import 'data/book_store.dart';
import 'services/tts_service.dart';
import 'services/audio_player.dart';
import 'app_config.dart';
import 'pages/shelf_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局未捕获异常：写入 error.log，白屏时可用于定位
  _installErrorHandlers();

  // 本地存储（快，等它完成）
  try {
    await BookStore.init();
  } catch (e, s) {
    debugPrint('[main] BookStore.init 失败: $e');
    _writeErrorLog('BookStore.init 失败: $e\n$s');
  }

  // 离线 TTS：模型拷贝较大（几十 MB），放后台执行，绝不阻塞首帧
  unawaited(TtsService.instance.init());

  // 后台/锁屏音频：失败或超时都不阻断启动，降级为本地播放器
  try {
    audioHandler = await AudioService.init(
      builder: () => TtsAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.txtreader.tts',
        androidNotificationChannelName: 'AI 听书',
        androidNotificationOngoing: true,
        notificationColor: Color(0xFFFFFFFF),
      ),
    ).timeout(const Duration(seconds: 8), onTimeout: () {
      debugPrint('[main] AudioService.init 超时，降级为本地播放器');
      return TtsAudioHandler();
    });
  } catch (e, s) {
    debugPrint('[main] AudioService.init 失败，降级为本地播放器: $e');
    _writeErrorLog('AudioService.init 失败: $e\n$s');
    audioHandler = TtsAudioHandler();
  }

  runApp(const MyApp());
}

/// 捕获所有未捕获异常并写入应用私有目录 error.log（release 下可用）
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _writeErrorLog('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _writeErrorLog('Uncaught: $error\n$stack');
    return true; // 已处理，不让进程直接退出
  };
}

void _writeErrorLog(String msg) {
  unawaited(() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/error.log');
      await f.writeAsString('${DateTime.now()}\n$msg\n\n',
          mode: FileMode.append);
    } catch (_) {}
  }());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '阅读',
      debugShowCheckedModeBanner: false,
      theme: buildWhiteTheme(),
      home: const ShelfPage(),
    );
  }
}
