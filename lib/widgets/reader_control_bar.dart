import 'package:flutter/material.dart';
import '../providers/reader_provider.dart';
import '../services/tts_service.dart';

/// 阅读页底部悬浮控件卡片：返回书架 / 开启 AI 听书 / 字体调节。
class ReaderControlBar extends StatelessWidget {
  final ReaderProvider p;
  const ReaderControlBar(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              tooltip: '返回书架',
            ),
            IconButton(
              onPressed: () async {
                // 兜底：首次进入 App 后台 init 还没完成时，用户点击会主动再试一次
                if (!TtsService.instance.available) {
                  await TtsService.instance.init();
                }
                if (!TtsService.instance.available) {
                  final err = TtsService.instance.lastError.isEmpty
                      ? '未知错误'
                      : TtsService.instance.lastError;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('听书初始化失败：$err'),
                    ),
                  );
                  return;
                }
                await p.toggleTts();
              },
              icon: Icon(p.ttsActive ? Icons.volume_up : Icons.headphones),
              tooltip: 'AI 听书',
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => p.setFontSize(p.fontSize - 1),
                  icon: const Icon(Icons.remove),
                  tooltip: '减小字号',
                ),
                Text(
                  '${p.fontSize.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                IconButton(
                  onPressed: () => p.setFontSize(p.fontSize + 1),
                  icon: const Icon(Icons.add),
                  tooltip: '增大字号',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
