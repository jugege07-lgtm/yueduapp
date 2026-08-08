import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme.dart';
import 'data/book_store.dart';
import 'services/audio_player.dart';
import 'services/tts_service.dart';
import 'app_config.dart';
import 'pages/shelf_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 全局未捕获异常：写入 error.log，白屏时可用于定位
  _installErrorHandlers();

  // 本地存储（快，等它完成；失败有错误页兜底，不白屏）
  Object? initError;
  try {
    await BookStore.init();
  } catch (e, s) {
    initError = e;
    _writeErrorLog('BookStore.init 失败: $e\n$s');
  }

  // ⚠️ 重要：TTS（sherpa_onnx）与 audio_service 都不在启动时初始化，
  // 两者任何 native 层问题都会导致进程级白屏。全部改为用到时懒加载。
  // 这里仅创建纯本地播放器（just_audio），零原生服务注册。
  audioHandler = TtsAudioHandler();

  // 后台初始化离线 TTS（拷贝 45MB 模型到私有目录），不阻塞首帧；
  // 听书按钮在用户点击时会再次 init() 作为兜底（双保险）。
  unawaited(TtsService.instance.init());

  runApp(MyApp(fatalError: initError));
}

/// 捕获所有未捕获异常并写入应用私有目录 error.log（release 下可用）
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _writeErrorLog(
        'FlutterError: ${details.exceptionAsString()}\n${details.stack}');
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
  final Object? fatalError;
  const MyApp({super.key, this.fatalError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '阅读',
      debugShowCheckedModeBanner: false,
      theme: buildWhiteTheme(),
      home: fatalError == null ? const ShelfPage() : _ErrorPage(fatalError!),
    );
  }
}

/// 启动期致命错误的提示页（替代白屏，方便反馈）
class _ErrorPage extends StatelessWidget {
  final Object error;
  const _ErrorPage(this.error);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFF888888), size: 48),
              const SizedBox(height: 16),
              const Text('应用启动遇到问题',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ShelfPage()),
                ),
                child: const Text('继续（可能影响部分功能）'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
