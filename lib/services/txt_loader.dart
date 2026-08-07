import 'dart:io';
import 'package:flutter_charset_detector/flutter_charset_detector.dart';

/// TXT 加载与分段：读文件 -> 识别编码 -> 解码文本 -> 按段落切分。
/// 大文件策略：整篇解码后按段落切分，阅读时只渲染邻近页（分段预加载）。
class TxtLoader {
  /// 读取并解码文件为字符串
  static Future<String> loadText(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = await CharsetDetector.autoDecode(bytes);
    return decoded.string;
  }

  /// 按换行切分为段落（去除空行）
  static List<String> splitParagraphs(String text) {
    return text
        .split(RegExp(r'\r\n|\r|\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }
}
