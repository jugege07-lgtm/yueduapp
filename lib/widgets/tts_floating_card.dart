import 'package:flutter/material.dart';
import '../providers/reader_provider.dart';

/// AI 听书悬浮卡片：播放/暂停、上一段、下一段、倍速滑块（实时显示）、关闭。
/// 倍速硬锁 1.0x ~ 5.0x（0.1x 步进），并从当前书读取/记忆倍速。
class TtsFloatingCard extends StatelessWidget {
  final ReaderProvider p;
  const TtsFloatingCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final speed = p.book?.ttsSpeed ?? 1.0;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => p.handler.skipToPrevious(),
                  icon: const Icon(Icons.skip_previous),
                  tooltip: '上一段',
                ),
                IconButton(
                  onPressed: () => p.toggleTts(),
                  icon: Icon(p.ttsActive
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill),
                  iconSize: 32,
                  tooltip: p.ttsActive ? '暂停' : '播放',
                ),
                IconButton(
                  onPressed: () => p.handler.skipToNext(),
                  icon: const Icon(Icons.skip_next),
                  tooltip: '下一段',
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => p.closeTts(),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭听书',
                ),
              ],
            ),
            Row(
              children: [
                const Text(
                  '倍速',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
                Expanded(
                  child: Slider(
                    min: 1.0,
                    max: 5.0,
                    divisions: 40,
                    value: speed,
                    label: '${speed.toStringAsFixed(1)}x',
                    onChanged: (v) =>
                        p.setSpeed((v * 10).roundToDouble() / 10),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${speed.toStringAsFixed(1)}x',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
