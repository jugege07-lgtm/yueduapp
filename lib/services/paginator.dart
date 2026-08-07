import 'package:flutter/material.dart';
import 'package:characters/characters.dart';

/// 分页结果：页面文本列表 + 每页起始的段落索引（用于听书段落对齐）
class PaginationResult {
  final List<String> pages;
  final List<int> pageStartParagraph;
  PaginationResult(this.pages, this.pageStartParagraph);
}

/// 智能分页：用 TextPainter 测量，按段落/字符切页，保证不切字。
class Paginator {
  static PaginationResult paginate({
    required List<String> paragraphs,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
  }) {
    final pages = <String>[];
    final pageStartParagraph = <int>[];

    final painter = TextPainter(textDirection: TextDirection.ltr);
    String current = '';
    int currentStartPara = 0;

    void newPage(String content, int startPara) {
      pages.add(content);
      pageStartParagraph.add(startPara);
    }

    for (var pi = 0; pi < paragraphs.length; pi++) {
      final para = paragraphs[pi];

      // 尝试把当前段落并入本页
      final candidate = current.isEmpty ? para : '$current\n$para';
      painter.text = TextSpan(text: candidate, style: style);
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight) {
        current = candidate;
      } else {
        // 当前页已满，先收尾
        if (current.isNotEmpty) {
          newPage(current, currentStartPara);
          current = '';
        }

        // 单独一段是否也超页
        painter.text = TextSpan(text: para, style: style);
        painter.layout(maxWidth: maxWidth);

        if (painter.height <= maxHeight) {
          current = para;
          currentStartPara = pi;
        } else {
          // 超长段落：逐字符安全切分（不切字）
          String chunk = '';
          int chunkStartPara = pi;
          for (final ch in para.characters) {
            final test = chunk.isEmpty ? ch : '$chunk$ch';
            painter.text = TextSpan(text: test, style: style);
            painter.layout(maxWidth: maxWidth);
            if (painter.height > maxHeight && chunk.isNotEmpty) {
              newPage(chunk, chunkStartPara);
              chunk = ch;
            } else {
              chunk = test;
            }
          }
          current = chunk;
          currentStartPara = chunkStartPara;
        }
      }
    }

    if (current.isNotEmpty) newPage(current, currentStartPara);
    return PaginationResult(pages, pageStartParagraph);
  }
}
