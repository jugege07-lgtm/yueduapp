import 'dart:io';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// 离线 TTS 模型配置（自动识别模型文件，无需手动改路径）。
///
/// 不管下载的模型解压后是扁平结构还是嵌套在子目录里，这里都会递归扫描
/// [modelDir]，自动定位 .onnx 模型、tokens.txt、lexicon.txt、espeak-ng-data、
/// dict 等文件，拼接成正确的配置。这样换模型时不必改代码。
sherpa_onnx.OfflineTtsConfig getTtsConfig(String modelDir) {
  final dir = Directory(modelDir);
  final files = dir.existsSync()
      ? dir.listSync(recursive: true).whereType<File>().toList()
      : <File>[];
  final dirs = dir.existsSync()
      ? dir.listSync(recursive: true).whereType<Directory>().toList()
      : <Directory>[];

  bool _named(File f, String name) {
    final p = f.path;
    return p.endsWith('/$name') || p.endsWith('\\$name');
  }

  bool _dirNamed(Directory d, String name) {
    final p = d.path;
    return p.endsWith('/$name') || p.endsWith('\\$name');
  }

  String? _firstFile(String name) {
    try {
      return files.firstWhere((f) => _named(f, name)).path;
    } catch (_) {
      return null;
    }
  }

  String? _firstOnnx() {
    try {
      return files
          .firstWhere((f) {
            final p = f.path.toLowerCase();
            return p.endsWith('.onnx') && !p.endsWith('.onnx.json');
          })
          .path;
    } catch (_) {
      return null;
    }
  }

  String? _firstDir(String name) {
    try {
      return dirs.firstWhere((d) => _dirNamed(d, name)).path;
    } catch (_) {
      return null;
    }
  }

  final model = _firstOnnx();
  final tokens = _firstFile('tokens.txt');
  final lexicon = _firstFile('lexicon.txt');
  final dataDir = _firstDir('espeak-ng-data');
  final dictDir = _firstDir('dict');

  return sherpa_onnx.OfflineTtsConfig(
    model: sherpa_onnx.OfflineTtsModelConfig(
      vits: sherpa_onnx.OfflineTtsVitsModelConfig(
        model: model ?? '',
        tokens: tokens ?? '',
        lexicon: lexicon ?? '',
        dataDir: dataDir ?? '',
        dictDir: dictDir ?? '',
      ),
    ),
  );
}
