/// 动态绘本播放页面
/// 
/// 卡通绘本风格，图片帧展示 + 配音播放 + 自动翻页
/// 参考 UI 设计规范：温暖卡通风格，圆角大字，活泼配色

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shimmer/shimmer.dart';
import '../models/models.dart';
import '../services/picturebook_controller.dart';

/// 颜色主题（卡通绘本风格）
class PictureBookTheme {
  static const Color primary = Color(0xFF4ECDC4);      // 薄荷绿
  static const Color secondary = Color(0xFFFFE66D);    // 明黄
  static const Color accent = Color(0xFFFF6B6B);       // 珊瑚红
  static const Color background = Color(0xFFFFF9F0);   // 奶油白
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textLight = Color(0xFF7F8C8D);
}

class PictureBookPage extends StatelessWidget {
  final String wordId;
  final String word;
  final String? explanation;
  final String? existingBookId;

  const PictureBookPage({
    Key? key,
    required this.wordId,
    required this.word,
    this.explanation,
    this.existingBookId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PictureBookController(), tag: wordId);

    // 触发加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadAndPlay(
        wordId: wordId,
        word: word,
        explanation: explanation,
        existingBookId: existingBookId,
      );
    });

    return Scaffold(
      backgroundColor: PictureBookTheme.background,
      appBar: _buildAppBar(context, word),
      body: Obx(() => _buildBody(controller)),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String word) {
    return AppBar(
      backgroundColor: PictureBookTheme.primary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: Text(
        '📖 $word',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBody(PictureBookController controller) {
    switch (controller.state.value) {
      case PictureBookState.loading:
        return _buildLoadingView(controller);
      case PictureBookState.error:
        return _buildErrorView(controller);
      case PictureBookState.playing:
      case PictureBookState.paused:
      case PictureBookState.completed:
        return _buildPlayerView(controller);
      default:
        return _buildLoadingView(controller);
    }
  }

  // ── Loading 状态 ────────────────────────────────────────

  Widget _buildLoadingView(PictureBookController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 动画占位图（实际项目可换成 Lottie 动画）
          Shimmer.fromColors(
            baseColor: Colors.grey[200]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: 320,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Obx(() => Text(
            controller.jobStatus.value == 'generating'
                ? '🎨 AI 正在为你绘制专属绘本...'
                : '📚 加载中...',
            style: const TextStyle(
              fontSize: 18,
              color: PictureBookTheme.textLight,
              fontWeight: FontWeight.w500,
            ),
          )),
          const SizedBox(height: 12),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              color: PictureBookTheme.primary,
              backgroundColor: Color(0xFFE8F8F7),
              minHeight: 6,
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 错误状态 ────────────────────────────────────────────

  Widget _buildErrorView(PictureBookController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😅', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              '哎呀，绘本加载失败了',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: PictureBookTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Obx(() => Text(
              controller.errorMessage.value,
              style: const TextStyle(
                fontSize: 14,
                color: PictureBookTheme.textLight,
              ),
              textAlign: TextAlign.center,
            )),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => controller.loadAndPlay(
                wordId: wordId,
                word: word,
                explanation: explanation,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新生成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PictureBookTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 播放器主界面 ────────────────────────────────────────

  Widget _buildPlayerView(PictureBookController controller) {
    return Column(
      children: [
        // 图片帧区域
        Expanded(
          flex: 5,
          child: _buildFrameArea(controller),
        ),

        // 讲解文字
        _buildTextArea(controller),

        // 翻页指示器
        _buildPageIndicator(controller),

        // 控制按钮
        _buildControls(controller),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFrameArea(PictureBookController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Obx(() {
          final frame = controller.currentFrame;
          if (frame == null) return const SizedBox.shrink();

          return _FrameImage(
            key: ValueKey(frame.index),
            imageUrl: frame.imageUrl,
            word: word,
          );
        }),
      ),
    );
  }

  Widget _buildTextArea(PictureBookController controller) {
    return Obx(() {
      final frame = controller.currentFrame;
      if (frame == null) return const SizedBox.shrink();

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(frame.index),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: PictureBookTheme.primary.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            frame.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: PictureBookTheme.textPrimary,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPageIndicator(PictureBookController controller) {
    if (controller.totalFrames <= 1) return const SizedBox.shrink();

    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AnimatedSmoothIndicator(
        activeIndex: controller.currentFrameIndex.value,
        count: controller.totalFrames,
        effect: const ExpandingDotsEffect(
          activeDotColor: PictureBookTheme.primary,
          dotColor: Color(0xFFD5F5F3),
          dotHeight: 8,
          dotWidth: 8,
          expansionFactor: 3,
        ),
        onDotClicked: (index) => controller.goToFrame(index),
      ),
    ));
  }

  Widget _buildControls(PictureBookController controller) {
    return Obx(() {
      final isCompleted = controller.state.value == PictureBookState.completed;
      final isPlaying = controller.state.value == PictureBookState.playing;
      final isPaused = controller.state.value == PictureBookState.paused;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 上一帧
            _ControlButton(
              icon: Icons.skip_previous_rounded,
              onTap: controller.hasPrev ? controller.prevFrame : null,
              color: PictureBookTheme.textLight,
              size: 40,
            ),
            const SizedBox(width: 16),

            // 播放/暂停/重播
            if (isCompleted)
              _ControlButton(
                icon: Icons.replay_rounded,
                onTap: controller.replay,
                color: PictureBookTheme.primary,
                size: 64,
                isPrimary: true,
              )
            else if (isPlaying)
              _ControlButton(
                icon: Icons.pause_rounded,
                onTap: controller.pause,
                color: PictureBookTheme.primary,
                size: 64,
                isPrimary: true,
              )
            else
              _ControlButton(
                icon: Icons.play_arrow_rounded,
                onTap: controller.resume,
                color: PictureBookTheme.primary,
                size: 64,
                isPrimary: true,
              ),

            const SizedBox(width: 16),

            // 下一帧
            _ControlButton(
              icon: Icons.skip_next_rounded,
              onTap: controller.hasNext ? controller.nextFrame : null,
              color: PictureBookTheme.textLight,
              size: 40,
            ),
          ],
        ),
      );
    });
  }
}

// ── 子组件 ────────────────────────────────────────────────

class _FrameImage extends StatelessWidget {
  final String? imageUrl;
  final String word;

  const _FrameImage({Key? key, this.imageUrl, required this.word}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8F8F7),
      highlightColor: Colors.white,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildFallback() {
    // 当图片加载失败或未生成时，显示卡通文字占位
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📖', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              word.toUpperCase(),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final bool isPrimary;

  const _ControlButton({
    required this.icon,
    this.onTap,
    required this.color,
    required this.size,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    if (isPrimary) {
      return Material(
        color: isDisabled ? Colors.grey[300] : color,
        borderRadius: BorderRadius.circular(size / 2),
        elevation: isDisabled ? 0 : 6,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.55),
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(icon),
      onPressed: onTap,
      iconSize: size * 0.8,
      color: isDisabled ? Colors.grey[300] : color,
    );
  }
}
