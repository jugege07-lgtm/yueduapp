import 'dart:async';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'tts_service.dart';

/// 把 WAV 字节包装成 just_audio 可用的音频源
class BytesAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  BytesAudioSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(Uint8List.sublistView(bytes, start, end)),
      contentType: 'audio/wav',
    );
  }
}

/// 听书音频处理器：基于 audio_service 的前台 MediaSession，
/// 实现后台 / 锁屏播放，并暴露 播放/暂停/上一段/下一段 控制。
///
/// 段落合成由 [TtsService] 完成（离线），合成出的 WAV 交给 just_audio 播放；
/// 一段播放结束后自动合成并播放下一段。
class TtsAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  List<String> _paragraphs = [];
  int _index = 0;
  double _speed = 1.0;
  bool _active = false;

  TtsAudioHandler() {
    _player.playbackEventStream.listen(_onPlaybackEvent);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onCompleted();
    });
  }

  /// 设置待播放的段落序列，并从 [startIndex] 段、[speed] 倍速开始准备
  void prepare(List<String> paragraphs, int startIndex, double speed) {
    _paragraphs = paragraphs;
    _index = startIndex;
    _speed = speed;
  }

  /// 开始播放（从当前 _index 段起）
  Future<void> start() async {
    if (_paragraphs.isEmpty) return;
    _active = true;
    await _playIndex(_index);
  }

  Future<void> _playIndex(int index) async {
    if (!TtsService.instance.available) return;
    if (index < 0 || index >= _paragraphs.length) {
      await pause();
      return;
    }
    _index = index;
    final wav =
        await TtsService.instance.synthesize(_paragraphs[index], speed: _speed);
    await _player.setAudioSource(BytesAudioSource(wav), preload: true);
    _updateMediaItem();
    await _player.play();
  }

  void _updateMediaItem() {
    mediaItem.add(MediaItem(
      id: '$_index',
      title: '第 ${_index + 1} 段',
      artist: 'AI 听书',
      album: '本地 TXT 阅读器',
    ));
    playbackState.add(playbackState.value.copyWith(
      controls: _buildControls(true),
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      playing: true,
      processingState: AudioProcessingState.ready,
    ));
  }

  List<MediaControl> _buildControls(bool playing) => [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ];

  void _onPlaybackEvent(PlaybackEvent event) {
    playbackState.add(playbackState.value.copyWith(
      playing: _player.playing,
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState],
    ));
  }

  Future<void> _onCompleted() async {
    if (_index + 1 < _paragraphs.length) {
      await _playIndex(_index + 1);
    } else {
      _active = false;
      await pause();
    }
  }

  /// 改变倍速：重新用新倍速合成当前段（离线引擎级变速，音质更自然）
  void setSpeedExternal(double speed) {
    _speed = speed;
    if (_active) _playIndex(_index);
  }

  @override
  Future<void> play() async {
    if (!_active) {
      _active = true;
      await _playIndex(_index);
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _active = false;
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(
      controls: _buildControls(false),
      playing: false,
    ));
  }

  @override
  Future<void> skipToNext() async {
    if (_index + 1 < _paragraphs.length) await _playIndex(_index + 1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_index - 1 >= 0) await _playIndex(_index - 1);
  }

  @override
  Future<void> stop() async {
    _active = false;
    await _player.stop();
    await super.stop();
  }

  int get currentIndex => _index;
}
