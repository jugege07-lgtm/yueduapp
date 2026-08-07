import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:page_turn_animation/page_turn_animation.dart';

/// 仿真翻页阅读区：用 page_turn_animation 实现真实书页卷曲效果。
/// - 左右滑动翻页（上一页 / 下一页）
/// - 点击页面中部唤起/隐藏控制栏
/// - 控制栏（底部悬浮控件 + 听书卡片）作为独立浮层叠加，不参与翻页动画捕获
class PageTurnReader extends StatefulWidget {
  final List<String> pages;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;
  final Widget controls; // 控制栏浮层（不随翻页捕获）
  final bool controlsVisible;
  final VoidCallback onToggleControls;
  final TextStyle textStyle;

  const PageTurnReader({
    super.key,
    required this.pages,
    required this.initialIndex,
    required this.onPageChanged,
    required this.controls,
    required this.controlsVisible,
    required this.onToggleControls,
    required this.textStyle,
  });

  @override
  State<PageTurnReader> createState() => _PageTurnReaderState();
}

enum _Phase { idle, capturing, animating }

class _PageTurnReaderState extends State<PageTurnReader>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late int _targetIndex;
  bool _isForward = true;
  _Phase _phase = _Phase.idle;
  ui.Image? _currentImage;
  ui.Image? _targetImage;
  final GlobalKey _currentKey = GlobalKey();
  final GlobalKey _targetKey = GlobalKey();
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  );
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  static const _style = PageTurnStyle(
    backgroundColor: Color(0xFFFFFFFF),
    shadowColor: Colors.black,
    shadowOpacity: 0.5,
    shadowBlurRadius: 18,
    segments: 80,
    curlIntensity: 1.0,
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.pages.length - 1);
  }

  @override
  void didUpdateWidget(covariant PageTurnReader old) {
    super.didUpdateWidget(old);
    // 重新分页后，钳制当前页索引不越界
    if (widget.pages != old.pages && _phase == _Phase.idle) {
      if (_currentIndex >= widget.pages.length) {
        _currentIndex = widget.pages.length - 1;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _curve.dispose();
    _disposeImages();
    super.dispose();
  }

  void _disposeImages() {
    _currentImage?.dispose();
    _targetImage?.dispose();
    _currentImage = null;
    _targetImage = null;
  }

  Future<void> _turn(bool forward) async {
    if (_phase != _Phase.idle) return;
    final next = forward ? _currentIndex + 1 : _currentIndex - 1;
    if (next < 0 || next >= widget.pages.length) return;

    _isForward = forward;
    _targetIndex = next;
    setState(() => _phase = _Phase.capturing);
    await _captureImages();
    if (!mounted) return;
    setState(() => _phase = _Phase.animating);
    _controller.reset();
    await _controller.forward();
    if (!mounted) return;
    _disposeImages();
    setState(() {
      _currentIndex = _targetIndex;
      _phase = _Phase.idle;
    });
    widget.onPageChanged(_currentIndex);
  }

  Future<void> _captureImages() async {
    final pr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cb = _currentKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (cb != null) _currentImage = await cb.toImage(pixelRatio: pr);
    final tb = _targetKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (tb != null) _targetImage = await tb.toImage(pixelRatio: pr);
  }

  Widget _buildPage(String text) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Text(text, style: widget.textStyle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCurrent = _currentIndex >= 0 && _currentIndex < widget.pages.length;
    final showTarget = _phase != _Phase.idle &&
        _targetIndex >= 0 &&
        _targetIndex < widget.pages.length;

    return Stack(
      children: [
        // 内容层（翻页动画在此）
        if (_phase == _Phase.capturing) ...[
          Positioned.fill(
            child: RepaintBoundary(
              key: _currentKey,
              child: _buildPage(widget.pages[_currentIndex]),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              key: _targetKey,
              child: _buildPage(widget.pages[_targetIndex]),
            ),
          ),
        ] else if (_phase == _Phase.animating && showTarget) ...[
          Positioned.fill(child: _buildPage(widget.pages[_targetIndex])),
          if (_isForward && _currentImage != null)
            PageTurnAnimation(
              image: _currentImage!,
              animation: _curve,
              direction: PageTurnDirection.forward,
              edge: PageTurnEdge.right,
              style: _style,
            )
          else if (!_isForward && _targetImage != null)
            Stack(
              children: [
                Positioned.fill(
                    child: RawImage(image: _currentImage, fit: BoxFit.fill)),
                PageTurnAnimation(
                  image: _targetImage!,
                  animation: _curve,
                  direction: PageTurnDirection.backward,
                  edge: PageTurnEdge.right,
                  style: _style,
                ),
              ],
            ),
        ] else if (showCurrent)
          Positioned.fill(child: _buildPage(widget.pages[_currentIndex])),

        // 手势层：点击中部切换控制栏；左右滑动翻页
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onToggleControls,
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity == null) return;
              if (d.primaryVelocity! < 0) {
                _turn(true); // 向左滑 -> 下一页
              } else if (d.primaryVelocity! > 0) {
                _turn(false); // 向右滑 -> 上一页
              }
            },
          ),
        ),

        // 控制栏浮层（不参与翻页捕获）
        if (widget.controlsVisible) widget.controls,
      ],
    );
  }
}
