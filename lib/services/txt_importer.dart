import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_charset_detector/flutter_charset_detector.dart';
import '../models/book.dart';

/// 导入 TXT：调用系统文件管理器，仅显示 .txt，支持多选，
/// 逐文件自动识别编码（UTF-8 / GBK 等）。
class TxtImporter {
  static Future<List<Book>> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      allowMultiple: true,
    );
    if (result == null) return [];

    final imported = <Book>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final bytes = await File(path).readAsBytes();
      // 自动识别编码并解码（无需手动区分 UTF-8 / GBK）
      final decoded = await CharsetDetector.autoDecode(bytes);

      imported.add(Book(
        title: _fileName(path),
        path: path,
        encoding: decoded.charset,
      ));
    }
    return imported;
  }

  static String _fileName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    if (name.toLowerCase().endsWith('.txt')) {
      return name.substring(0, name.length - 4);
    }
    return name;
  }
}
