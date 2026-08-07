import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// 离线 TTS 模型配置。
///
/// ⚠️ 重要：不同模型的文件结构不同。请运行 `tools/download_tts_model.sh`
/// 下载一个中文（或你想要的）VITS 模型，然后打开该模型解压后的目录，
/// 对照里面的实际文件名修改下面的字段（参考官方 example/lib/model.dart）。
///
/// 典型中文 VITS 模型包含：model.onnx、tokens.txt、lexicon.txt、
/// espeak-ng-data/（或 dict/）。把对应路径拼接在 [modelDir] 之后即可。
sherpa_onnx.OfflineTtsConfig getTtsConfig(String modelDir) {
  return sherpa_onnx.OfflineTtsConfig(
    model: sherpa_onnx.OfflineTtsModelConfig(
      vits: sherpa_onnx.OfflineTtsVitsModelConfig(
        model: '$modelDir/model.onnx',
        tokens: '$modelDir/tokens.txt',
        lexicon: '$modelDir/lexicon.txt',
        dataDir: '$modelDir/espeak-ng-data',
        dictDir: '$modelDir/dict',
      ),
    ),
  );
}
