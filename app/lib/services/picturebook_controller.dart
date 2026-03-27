/// 动态绘本播放控制器（GetX）
/// 
/// 负责：图片帧展示、配音播放、自动翻页、时间轴同步

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum PictureBookState {
  idle,
  loading,
  playing,
  paused,
  completed,
  error,
}

class PictureBookController extends GetxController {
  final ApiService _api = ApiService();

  // ── 状态 ──────────────────────────────────────────────
  final Rx<PictureBookState> state = PictureBookState.idle.obs;
  final RxString errorMessage = ''.obs;
  final Rx<PictureBook?> book = Rx<PictureBook?>(null);
  final RxInt currentFrameIndex = 0.obs;
  final RxBool isAutoPlay = true.obs;

  // 生成任务
  final RxString jobId = ''.obs;
  final RxString jobStatus = ''.obs;
  Timer? _pollTimer;

  // 音频
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _audioSub;

  PictureBookTimeline? get timeline => book.value?.timeline;
  PictureBookFrame? get currentFrame =>
      timeline != null && currentFrameIndex.value < timeline!.frameCount
          ? timeline!.frames[currentFrameIndex.value]
          : null;
  int get totalFrames => timeline?.frameCount ?? 0;
  bool get hasNext => currentFrameIndex.value < totalFrames - 1;
  bool get hasPrev => currentFrameIndex.value > 0;

  @override
  void onClose() {
    _audioPlayer.dispose();
    _audioSub?.cancel();
    _pollTimer?.cancel();
    super.onClose();
  }

  // ── 核心方法 ──────────────────────────────────────────

  /// 加载并播放绘本
  Future<void> loadAndPlay({
    required String wordId,
    required String word,
    String? explanation,
    String? existingBookId,
  }) async {
    state.value = PictureBookState.loading;
    errorMessage.value = '';
    currentFrameIndex.value = 0;

    try {
      // 先尝试加载已有绘本
      PictureBook? existingBook;
      if (existingBookId != null) {
        existingBook = await _api.getPictureBook(existingBookId);
      } else {
        existingBook = await _api.getPictureBookByWord(wordId);
      }

      if (existingBook != null && existingBook.timeline != null) {
        book.value = existingBook;
        await _startPlayback();
        return;
      }

      // 没有缓存，触发生成
      final result = await _api.generatePictureBook(
        wordId: wordId,
        word: word,
        explanation: explanation,
        async_: true,
      );

      if (result['cached'] == true || result['data'] != null) {
        // 同步返回了结果
        final data = result['data'] as Map<String, dynamic>;
        // 如果 data 有 timeline，直接用
        if (data['timeline'] != null) {
          book.value = PictureBook.fromJson(data);
          await _startPlayback();
          return;
        }
        // 否则用 bookId 拉详情
        final bookIdResult = data['id'] ?? data['bookId'];
        if (bookIdResult != null) {
          final b = await _api.getPictureBook(bookIdResult.toString());
          if (b != null) {
            book.value = b;
            await _startPlayback();
            return;
          }
        }
      }

      if (result['jobId'] != null) {
        // 异步模式，开始轮询
        jobId.value = result['jobId'].toString();
        jobStatus.value = 'generating';
        _startPolling(wordId: wordId, word: word);
        return;
      }

      throw Exception('Unexpected response from server');
    } catch (e) {
      state.value = PictureBookState.error;
      errorMessage.value = e.toString();
    }
  }

  void _startPolling({required String wordId, required String word}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (jobId.value.isEmpty) return;
      final job = await _api.getJobStatus(jobId.value);
      if (job == null) return;

      jobStatus.value = job.state;

      if (job.isCompleted && job.result != null) {
        _pollTimer?.cancel();
        // 如果 result 没有 timeline，再拉一次完整详情
        PictureBook? finalBook = job.result;
        if (finalBook?.timeline == null && finalBook?.id != null) {
          finalBook = await _api.getPictureBook(finalBook!.id);
        }
        if (finalBook?.timeline != null) {
          book.value = finalBook;
          await _startPlayback();
        } else {
          state.value = PictureBookState.error;
          errorMessage.value = 'Failed to load picture book timeline';
        }
      } else if (job.isFailed) {
        _pollTimer?.cancel();
        state.value = PictureBookState.error;
        errorMessage.value = job.error ?? 'Generation failed';
      }
    });
  }

  Future<void> _startPlayback() async {
    if (timeline == null || timeline!.frameCount == 0) {
      state.value = PictureBookState.error;
      errorMessage.value = 'No frames to play';
      return;
    }

    state.value = PictureBookState.playing;
    currentFrameIndex.value = 0;
    await _playCurrentFrame();
  }

  Future<void> _playCurrentFrame() async {
    if (timeline == null) return;
    final frame = timeline!.frames[currentFrameIndex.value];

    // 播放当前帧配音
    if (frame.audioUrl != null && frame.audioUrl!.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        _audioSub?.cancel();

        await _audioPlayer.setUrl(frame.audioUrl!);
        await _audioPlayer.play();

        // 监听播放完成
        _audioSub = _audioPlayer.playerStateStream.listen((playerState) {
          if (playerState.processingState == ProcessingState.completed) {
            _audioSub?.cancel();
            if (isAutoPlay.value && state.value == PictureBookState.playing) {
              _onFrameCompleted();
            }
          }
        });
      } catch (e) {
        debugPrint('[PictureBook] Audio error: $e');
        // 音频播放失败，按时长等待后翻页
        _scheduleAutoAdvance(frame.durationMs);
      }
    } else {
      // 无音频，按时长等待后翻页
      _scheduleAutoAdvance(frame.durationMs);
    }
  }

  Timer? _autoAdvanceTimer;

  void _scheduleAutoAdvance(int durationMs) {
    _autoAdvanceTimer?.cancel();
    if (!isAutoPlay.value) return;
    _autoAdvanceTimer = Timer(Duration(milliseconds: durationMs), () {
      if (isAutoPlay.value && state.value == PictureBookState.playing) {
        _onFrameCompleted();
      }
    });
  }

  void _onFrameCompleted() {
    if (hasNext) {
      currentFrameIndex.value++;
      _playCurrentFrame();
    } else {
      // 全部播放完成
      state.value = PictureBookState.completed;
    }
  }

  // ── 用户交互 ──────────────────────────────────────────

  void nextFrame() {
    if (!hasNext) return;
    _stopCurrentAudio();
    currentFrameIndex.value++;
    if (state.value == PictureBookState.playing) {
      _playCurrentFrame();
    }
  }

  void prevFrame() {
    if (!hasPrev) return;
    _stopCurrentAudio();
    currentFrameIndex.value--;
    if (state.value == PictureBookState.playing) {
      _playCurrentFrame();
    }
  }

  void goToFrame(int index) {
    if (index < 0 || index >= totalFrames) return;
    _stopCurrentAudio();
    currentFrameIndex.value = index;
    if (state.value == PictureBookState.playing) {
      _playCurrentFrame();
    }
  }

  void pause() {
    if (state.value != PictureBookState.playing) return;
    _audioPlayer.pause();
    _autoAdvanceTimer?.cancel();
    state.value = PictureBookState.paused;
  }

  void resume() {
    if (state.value != PictureBookState.paused) return;
    state.value = PictureBookState.playing;
    _audioPlayer.play();
  }

  void replay() {
    _stopCurrentAudio();
    currentFrameIndex.value = 0;
    state.value = PictureBookState.playing;
    _playCurrentFrame();
  }

  void _stopCurrentAudio() {
    _audioSub?.cancel();
    _autoAdvanceTimer?.cancel();
    _audioPlayer.stop();
  }
}
