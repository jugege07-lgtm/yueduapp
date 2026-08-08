import 'dart:io';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// 离线 TTS 模型配置（自动识别模型文件）。
///
/// 扫描 [modelDir] 下的所有文件，自动定位：
/// - 模型 .onnx
/// - tokens.txt
/// - lexicon.txt（非 piper 模型需要）
/// - espeak-ng-data（piper VITS 模型需要 espeak-ng 处理拼音）
/// - dict/（可选）
///
/// piper VITS（如 vits-piper-zh_CN-huayan-medium）通常**没有 lexicon.txt 也没有 dict/**，
/// lexicon/dictDir 字段保留为空字符串，sherpa-onnx 原生层会忽略它们（取决于 native 实现）。
/// 若报 "Empty token ids" 等问题，多半是模型文件不完整或 dataDir 路径错。
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

  // 必填三项必须存在，否则视为模型不完整
  if (model == null || tokens == null) {
    throw StateError(
        'TTS 模型不完整：未找到 .onnx 模型或 tokens.txt（目录: $modelDir）');
  }

  return sherpa_onnx.OfflineTtsConfig(
    model: sherpa_onnx.OfflineTtsModelConfig(
      vits: sherpa_onnx.OfflineTtsVitsModelConfig(
        model: model,
        tokens: tokens,
        // piper VITS 用 espeak-ng 处理，不需要 lexicon/dict；找不到就空串
        lexicon: lexicon ?? '',
        dataDir: dataDir ?? '',
        dictDir: dictDir ?? '',
        lengthScale: 1.0, // 默认速度由 generate 的 speed 参数控制
      ),
      numThreads: 2, // 2 线程在小米 15 上较快且不卡顿
      debug: false,
      provider: 'cpu',
    ),
  );
}