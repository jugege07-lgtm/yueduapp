import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../services/audio_player.dart';
import '../providers/reader_provider.dart';
import '../widgets/page_turn_reader.dart';
import '../widgets/reader_control_bar.dart';
import '../widgets/tts_floating_card.dart';

/// 阅读页：大白卡展示正文，仿真翻页，点中部唤起控制栏；
/// 退出时自动存档（dispose 中调用 saveProgress）。
class ReaderPage extends StatefulWidget {
  final Book book;
  final TtsAudioHandler handler;
  const ReaderPage({super.key, required this.book, required this.handler});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final ReaderProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ReaderProvider();
    _provider.open(widget.book, widget.handler);
  }

  @override
  void dispose() {
    _provider.saveProgress();
    if (_provider.ttsActive) _provider.closeTts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF222222),
          elevation: 0,
          title: Text(widget.book.title),
        ),
        body: Consumer<ReaderProvider>(
          builder: (ctx, p, _) {
            if (p.paragraphs.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF222222)),
              );
            }
            return LayoutBuilder(
              builder: (c, constraints) {
                final maxW = (constraints.maxWidth - 64).clamp(100.0, 100000.0);
                final maxH = (constraints.maxHeight - 64).clamp(100.0, 100000.0);
                // 首屏（或分页尚未计算）时计算分页
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (p.pages.isEmpty) p.computePages(maxW, maxH);
                });
                if (p.pages.isEmpty) return const SizedBox.shrink();

                final controlsOverlay = Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Column(
                    children: [
                      if (p.ttsActive) TtsFloatingCard(p),
                      ReaderControlBar(p),
                    ],
                  ),
                );

                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          elevation: 4,
                          clipBehavior: Clip.antiAlias,
                          child: PageTurnReader(
                            pages: p.pages,
                            initialIndex: p.currentPage,
                            onPageChanged: (i) {
                              p.currentPage = i;
                              p.saveProgress();
                            },
                            controls: controlsOverlay,
                            controlsVisible: p.controlsVisible,
                            onToggleControls: p.toggleControls,
                            textStyle: TextStyle(
                              fontSize: p.fontSize,
                              height: 1.7,
                              color: const Color(0xFF222222),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
