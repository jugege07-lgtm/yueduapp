import 'dart:math';
import 'dart:typed_data';

/// 将 sherpa_onnx 合成的 Float32 音频样本编码为 16-bit PCM 的 WAV 字节，
/// 供 just_audio 直接播放。
class WavEncoder {
  static Uint8List encode(Float32List samples, int sampleRate) {
    final byteData = ByteData(44 + samples.length * 2);

    _writeString(byteData, 0, 'RIFF');
    byteData.setUint32(4, 36 + samples.length * 2, Endian.little);
    _writeString(byteData, 8, 'WAVE');
    _writeString(byteData, 12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // PCM 块大小
    byteData.setUint16(20, 1, Endian.little); // 格式 = PCM
    byteData.setUint16(22, 1, Endian.little); // 单声道
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little); // 字节率
    byteData.setUint16(32, 2, Endian.little); // 块对齐
    byteData.setUint16(34, 16, Endian.little); // 位深
    _writeString(byteData, 36, 'data');
    byteData.setUint32(40, samples.length * 2, Endian.little);

    var offset = 44;
    for (final s in samples) {
      final clamped = s.clamp(-1.0, 1.0);
      final pcm = (clamped * 32767).round();
      byteData.setInt16(offset, pcm, Endian.little);
      offset += 2;
    }
    return byteData.buffer.asUint8List();
  }

  static void _writeString(ByteData data, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
