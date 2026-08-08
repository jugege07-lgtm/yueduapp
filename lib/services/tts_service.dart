import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'wav_encoder.dart';
import 'tts_model_config.dart';

/// AI 离线听书核心：封装 sherpa_onnx 离线神经语音合成。
/// - 首次初始化时把 assets/tts-model 下的模型文件拷贝到应用私有目录
///   （onnxruntime 需要真实文件路径，不能直接读 asset）。
/// - synthesize() 把一段文本合成为 WAV 字节（带倍速、可选说话人 sid）。
class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  sherpa_onnx.OfflineTts? _tts;
  String? _modelDir;
  bool available = false; // 模型是否就绪（未下载时为 false）

  int currentSpeakerId = 0; // 当前选中的说话人（音色），0 为默认
  int speakerCount = 187; // 模型说话人总数（fanchen-C 为 187；加载后若可获取则自动更新）

  Future<void> init() async {
    if (_tts != null) return;
    try {
      _modelDir = await _prepareModelDir();
      final config = getTtsConfig(_modelDir!);
      _tts = sherpa_onnx.OfflineTts(config);
      available = true;
      // 尝试读取说话人数量（多说话人模型如 fanchen-C 有 187 个音色可选）
      try {
        final n = (_tts as dynamic).numSpeakers;
        if (n is int && n > 1) speakerCount = n;
      } catch (_) {
        // 单说话人或绑定未暴露该 API：保持默认
      }
    } catch (e) {
      // 模型未下载或路径不匹配：听书功能不可用，但 App 其余功能正常
      available = false;
      debugPrint('[TtsService] 离线语音模型未就绪：$e');
    }
  }

  /// 拷贝资源模型到应用支持目录，并返回该目录路径
  Future<String> _prepareModelDir() async {
    final appDir = await getApplicationSupportDirectory();
    final target = Directory('${appDir.path}/tts-model');
    if (!await target.exists()) await target.create(recursive: true);

    // manifest.txt 由下载脚本生成，列出所有需要拷贝的模型文件。
    // 若尚未下载（manifest 不存在），直接返回目录即可（available 会为 false）。
    String manifestContent;
    try {
      manifestContent =
          await rootBundle.loadString('assets/tts-model/manifest.txt');
    } catch (_) {
      return target.path;
    }
    final files =
        manifestContent.split('\n').where((l) => l.trim().isNotEmpty);

    for (final f in files) {
      final out = File('${target.path}/$f');
      if (!await out.exists()) {
        final data = await rootBundle.load('assets/tts-model/$f');
        await out.writeAsBytes(data.buffer.asUint8List());
      }
    }
    return target.path;
  }

  /// 合成文本为 WAV 字节。[speed] 由听书倍速滑块控制（1.0~5.0）。
  /// [sid] 选择说话人（音色）；不传则用 [currentSpeakerId]。
  Future<Uint8List> synthesize(String text,
      {double speed = 1.0, int? sid}) async {
    if (_tts == null) {
      await init();
      if (_tts == null) return Uint8List(0);
    }
    try {
      // sherpa_onnx 1.13.x 的 generate 只接受命名参数；sid 选说话人（音色）
      final audio = _tts!.generate(
          text: text, sid: sid ?? currentSpeakerId, speed: speed);
      return WavEncoder.encode(audio.samples, audio.sampleRate);
    } catch (e) {
      debugPrint('[TtsService] 合成失败: $e');
      return Uint8List(0);
    }
  }
}
