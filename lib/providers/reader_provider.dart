import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/txt_loader.dart';
import '../services/paginator.dart';
import '../services/audio_player.dart';

/// 阅读页状态管理：当前书、分页结果、页码、字号、听书状态、控制栏显隐。
class ReaderProvider extends ChangeNotifier {
  Book? book;
  List<String> paragraphs = [];
  List<String> pages = [];
  List<int> pageStartParagraph = [];
  int currentPage = 0;
  double fontSize = 18;
  bool ttsActive = false;
  bool controlsVisible = false;
  bool showFontPanel = false;
  late TtsAudioHandler handler;

  double _lastW = 0;
  double _lastH = 0;

  Future<void> open(Book b, TtsAudioHandler h) async {
    book = b;
    handler = h;
    fontSize = 18;
    currentPage = b.currentPage;
    controlsVisible = false;
    ttsActive = false;
    showFontPanel = false;
    final text = await TxtLoader.loadText(b.path);
    paragraphs = TxtLoader.splitParagraphs(text);
    notifyListeners();
  }

  /// 根据可用区域计算分页（字号或内容变化时重算）
  void computePages(double maxWidth, double maxHeight) {
    _lastW = maxWidth;
    _lastH = maxHeight;
    final style = TextStyle(
      fontSize: fontSize,
      height: 1.7,
      color: const Color(0xFF222222),
    );
    final r = Paginator.paginate(
      paragraphs: paragraphs,
      style: style,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    pages = r.pages;
    pageStartParagraph = r.pageStartParagraph;
    if (currentPage >= pages.length) currentPage = pages.length - 1;
    notifyListeners();
  }

  void goToPage(int i) {
    if (i < 0 || i >= pages.length) return;
    currentPage = i;
    controlsVisible = false;
    notifyListeners();
  }

  void nextPage() => goToPage(currentPage + 1);
  void prevPage() => goToPage(currentPage - 1);

  void toggleControls() {
    controlsVisible = !controlsVisible;
    notifyListeners();
  }

  void hideControls() {
    controlsVisible = false;
    notifyListeners();
  }

  void setFontSize(double s) {
    fontSize = s.clamp(12, 30);
    if (_lastW > 0) {
      computePages(_lastW, _lastH);
    } else {
      notifyListeners();
    }
  }

  /// 当前页对应的段落索引（用于听书从当前位置开始）
  int get currentParagraph =>
      pageStartParagraph.isNotEmpty && currentPage < pageStartParagraph.length
          ? pageStartParagraph[currentPage]
          : 0;

  /// 开启 / 关闭 AI 听书
  Future<void> toggleTts() async {
    if (book == null) return;
    if (ttsActive) {
      await handler.pause();
      ttsActive = false;
    } else {
      handler.loadPlaylist(paragraphs, currentParagraph, book!.ttsSpeed);
      await handler.start();
      ttsActive = true;
    }
    notifyListeners();
  }

  Future<void> closeTts() async {
    await handler.stop();
    ttsActive = false;
    notifyListeners();
  }

  /// 设置倍速并持久化（每本书独立记忆）
  void setSpeed(double s) {
    if (book == null) return;
    book!.ttsSpeed = s;
    book!.save();
    handler.setSpeedExternal(s);
    notifyListeners();
  }

  /// 退出阅读时存档：页码、段落、进度百分比、上次阅读时间
  Future<void> saveProgress() async {
    if (book == null) return;
    book!.currentPage = currentPage;
    book!.currentParagraph = currentParagraph;
    book!.progressPercent =
        pages.isEmpty ? 0 : (currentPage + 1) / pages.length;
    book!.lastReadAt = DateTime.now().millisecondsSinceEpoch;
    await book!.save();
  }
}
