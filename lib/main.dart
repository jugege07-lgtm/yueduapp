import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'core/theme.dart';
import 'data/book_store.dart';
import 'services/tts_service.dart';
import 'services/audio_player.dart';
import 'app_config.dart';
import 'pages/shelf_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储
  await BookStore.init();
  // 初始化离线 TTS（首次会拷贝模型到私有目录）
  await TtsService.instance.init();
  // 初始化后台/锁屏音频处理器
  audioHandler = await AudioService.init(
    builder: () => TtsAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.txtreader.tts',
      androidNotificationChannelName: 'AI 听书',
      androidNotificationOngoing: true,
      notificationColor: Color(0xFFFFFFFF),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '纯白阅读',
      debugShowCheckedModeBanner: false,
      theme: buildWhiteTheme(),
      home: const ShelfPage(),
    );
  }
}
