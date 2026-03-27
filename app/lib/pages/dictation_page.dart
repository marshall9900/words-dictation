import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/voice/nluc_engine.dart';
import '../core/voice/voice_assistant.dart';
import '../models/models.dart';
import '../services/audio_service.dart';
import '../services/local_db_service.dart';
import '../services/api_service.dart';
import '../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 听写状态机
// ─────────────────────────────────────────────────────────────────────────────
enum DictationState {
  idle,
  reading,       // TTS 朗读中
  waiting,       // 等待用户输入
  recording,     // 录音中
  evaluating,    // 评测中
  result,        // 显示结果
  finished,      // 听写完成
  listening,     // 语音指令监听中
}

// ─────────────────────────────────────────────────────────────────────────────
// 听写页 Controller
// ─────────────────────────────────────────────────────────────────────────────
class DictationController extends GetxController {
  final DictationTask task;
  DictationController(this.task);

  final state = DictationState.idle.obs;
  final currentIndex = 0.obs;
  final spellingInput = ''.obs;
  final lastResult = Rx<EvaluationResult?>(null);
  final results = <EvaluationResult>[].obs;
  final speechAvailable = false.obs;

  late final AudioService _audio;
  late final ApiService _api;
  final _speech = stt.SpeechToText();

  WordItem get currentWord => task.words[currentIndex.value];
  bool get isLastWord => currentIndex.value >= task.words.length - 1;

  @override
  void onInit() {
    super.onInit();
    _audio = Get.find<AudioService>();
    _api = Get.find<ApiService>();
    _initSpeech();
    _startCurrent();
  }

  Future<void> _initSpeech() async {
    speechAvailable.value = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && state.value == DictationState.recording) {
          _onSpeechDone();
        }
      },
      onError: (e) {
        if (state.value == DictationState.recording) {
          state.value = DictationState.waiting;
          Get.snackbar('小Wo', '没听清楚，请再说一遍', duration: const Duration(seconds: 2));
        }
      },
    );
    if (!speechAvailable.value) {
      debugPrint('[Dictation] 语音识别不可用');
    }
  }

  // 开始朗读当前单词
  Future<void> _startCurrent() async {
    state.value = DictationState.reading;
    spellingInput.value = '';
    lastResult.value = null;
    await _audio.speakWord(currentWord.word, times: 2);
    state.value = DictationState.waiting;
  }

  // ── 语音输入 ─────────────────────────────────────────────────────────────

  Future<void> startVoiceInput() async {
    if (state.value != DictationState.waiting && state.value != DictationState.listening) return;
    if (!speechAvailable.value) {
      Get.snackbar('小Wo', '语音识别不可用，请检查麦克风权限');
      return;
    }
    state.value = DictationState.recording;
    spellingInput.value = '';
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          spellingInput.value = result.recognizedWords.trim();
          _onSpeechDone();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  Future<void> stopVoiceInput() async {
    await _speech.stop();
    if (state.value == DictationState.recording) _onSpeechDone();
  }

  void _onSpeechDone() async {
    if (spellingInput.value.isEmpty) {
      state.value = DictationState.waiting;
      Get.snackbar('小Wo', '没有听到声音，请再说一遍', duration: const Duration(seconds: 2));
      return;
    }
    await submitSpelling(spellingInput.value);
  }

  // ── 评测 ─────────────────────────────────────────────────────────────────

  Future<void> submitSpelling(String input) async {
    if (state.value != DictationState.waiting && state.value != DictationState.recording) return;
    state.value = DictationState.evaluating;

    EvaluationResult result;
    try {
      result = await _api.evaluateSpelling(
        taskId: task.taskId,
        wordId: currentWord.id,
        userInput: input,
      );
    } catch (_) {
      // 离线兜底：本地评测
      final std = currentWord.word.toLowerCase().trim();
      final usr = input.toLowerCase().trim();
      final isCorrect = std == usr;
      result = EvaluationResult(
        wordId: currentWord.id,
        expectedWord: currentWord.word,
        actualAnswer: input,
        isCorrect: isCorrect,
        score: isCorrect ? 1.0 : 0.0,
        suggestion: isCorrect ? null : '正确答案：${currentWord.word}',
      );
    }

    results.add(result);
    lastResult.value = result;
    state.value = DictationState.result;

    if (result.isCorrect) {
      await _audio.playSuccess();
      await _audio.speakEncouragement('太棒了宝贝！你真棒！');
    } else {
      await _audio.playError();
      await _audio.speakWrongFeedback(currentWord.word);
      // 错词本：累加 wrongCount（Bug 修复）
      final db = Get.find<LocalDbService>();
      final existing = await db.getWrongWord(currentWord.id);
      final newCount = (existing?.wrongCount ?? 0) + 1;
      final wrong = WrongWord(
        wordId: currentWord.id,
        word: currentWord,
        wrongCount: newCount,
        lastWrongAt: DateTime.now(),
      );
      await db.saveWrongWord(wrong);
    }
  }

  // ── 导航 ─────────────────────────────────────────────────────────────────

  void nextWord() {
    if (isLastWord) {
      _audio.speakReport(correctCount, task.words.length);
      state.value = DictationState.finished;
      return;
    }
    currentIndex.value++;
    _startCurrent();
  }

  Future<void> repeatWord() async {
    if (_audio.isSpeaking.value) return; // TTS 播放中不重复
    await _audio.speakWord(currentWord.word);
  }

  void restartCurrentWord() {
    _startCurrent();
  }

  // ── 最终得分 ─────────────────────────────────────────────────────────────

  int get totalScore {
    int score = 0;
    for (final r in results) {
      score += r.isCorrect ? 10 : 2;
    }
    return score;
  }

  int get correctCount => results.where((r) => r.isCorrect).length;

  // ── 语音模式 ─────────────────────────────────────────────────────────────

  void enterVoiceMode() {
    if (Get.isRegistered<VoiceAssistant>()) {
      Get.find<VoiceAssistant>().enterDictationMode();
    }
    if (!Get.isRegistered<DictationController>(tag: 'DictationController')) {
      Get.put(this, tag: 'DictationController');
    }
    _waitForVoiceCommand();
  }

  void _waitForVoiceCommand() {
    state.value = DictationState.listening;
  }

  void handleVoiceCommand(VoiceIntent intent) {
    switch (intent) {
      case VoiceIntent.nextWord:
        if (state.value == DictationState.result) nextWord();
        break;
      case VoiceIntent.repeatWord:
        repeatWord();
        break;
      case VoiceIntent.restart:
        restartCurrentWord();
        break;
      case VoiceIntent.submit:
        if (state.value == DictationState.recording) stopVoiceInput();
        break;
      default:
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 听写页面 UI
// ─────────────────────────────────────────────────────────────────────────────
class DictationPage extends StatelessWidget {
  final DictationTask? task;
  const DictationPage({super.key, this.task});

  @override
  Widget build(BuildContext context) {
    final t = task ?? (Get.arguments as DictationTask);
    final controller = Get.put(DictationController(t), tag: 'DictationController');

    return Scaffold(
      appBar: AppBar(
        title: Obx(() =>
            Text('第 ${controller.currentIndex.value + 1}/${t.words.length} 个词')),
        backgroundColor: AppTheme.primary,
        actions: [
          Obx(() => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '🎤 ${controller.speechAvailable.value ? "语音就绪" : "语音不可用"}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )),
        ],
      ),
      body: Obx(() => _buildBody(context, controller)),
      // 底部常驻呼吸灯麦克风指示器
      bottomNavigationBar: _VoiceIndicator(controller),
    );
  }

  Widget _buildBody(BuildContext context, DictationController c) {
    return switch (c.state.value) {
      DictationState.finished => _buildFinishedView(context, c),
      DictationState.result    => _buildResultView(context, c),
      _                        => _buildDictationView(context, c),
    };
  }

  // ── 听写中视图 ─────────────────────────────────────────────────────────

  Widget _buildDictationView(BuildContext context, DictationController c) {
    final isRecording  = c.state.value == DictationState.recording;
    final isEvaluating = c.state.value == DictationState.evaluating;
    final isReading    = c.state.value == DictationState.reading;
    final isListening  = c.state.value == DictationState.listening;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (c.currentIndex.value + 1) / c.task.words.length,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WordCard(c, isReading: isReading),
                const SizedBox(height: 32),
                _buildStateHint(c.state.value),
                const SizedBox(height: 16),
                Obx(() => _buildRecognizedText(c)),
                const SizedBox(height: 36),
                _buildActionButtons(context, c, isRecording, isEvaluating, isReading, isListening),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateHint(DictationState state) {
    return switch (state) {
      DictationState.reading    => const _PulsingText('🔊 仔细听发音...'),
      DictationState.waiting    => const _PulsingText('👂 听到了就点击麦克风'),
      DictationState.recording  => const _RecordingIndicator(),
      DictationState.evaluating => const _PulsingText('⏳ 评测中...'),
      DictationState.listening  => const _PulsingText('🎤 我在听，请说指令...'),
      _                         => const SizedBox.shrink(),
    };
  }

  Widget _buildRecognizedText(DictationController c) {
    if (c.state.value == DictationState.evaluating ||
        c.state.value == DictationState.result) return const SizedBox.shrink();
    final text = c.spellingInput.value;
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Text('"$text"', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AppTheme.primary)),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    DictationController c,
    bool isRecording,
    bool isEvaluating,
    bool isReading,
    bool isListening,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleButton(icon: Icons.replay, label: '再听',
              onPressed: isEvaluating || isReading ? null : c.repeatWord,
              color: Colors.grey.shade400, size: 56),
            const SizedBox(width: 24),
            _MicButton(
              isRecording: isRecording,
              onPressed: isEvaluating || isReading ? null
                : isRecording ? c.stopVoiceInput : c.startVoiceInput,
            ),
            const SizedBox(width: 24),
            _CircleButton(icon: Icons.skip_next, label: '跳过',
              onPressed: isEvaluating || isReading || isRecording ? null : () => c.nextWord(),
              color: Colors.grey.shade400, size: 56),
          ],
        ),
        if (!isRecording && !isEvaluating && !isReading && !isListening)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('👆 点击麦克风，说出你听到的单词',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
        if (isListening)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('🎤 说"下一题"或"复读"来控制',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
      ],
    );
  }

  // ── 结果视图 ───────────────────────────────────────────────────────────

  Widget _buildResultView(BuildContext context, DictationController c) {
    final result = c.lastResult.value!;
    final isCorrect = result.isCorrect;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, v, _) => Transform.scale(scale: v,
                child: Text(isCorrect ? '🎉' : '😅', style: const TextStyle(fontSize: 80))),
            ),
            const SizedBox(height: 16),
            Text(isCorrect ? '太棒了！答对了！' : '加油宝贝，下次一定行！',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16)],
              ),
              child: Column(
                children: [
                  Text(c.currentWord.word,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  const SizedBox(height: 4),
                  Text(c.currentWord.phonetic, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(c.currentWord.meaning, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
                  if (!isCorrect) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text('你说的：${c.spellingInput.value}',
                              style: const TextStyle(color: AppTheme.error, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('正确答案：${c.currentWord.word}',
                              style: const TextStyle(color: AppTheme.success, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: c.nextWord,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              child: Text(c.isLastWord ? '查看报告 📊' : '下一个词 →',
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 完成视图 ───────────────────────────────────────────────────────────

  Widget _buildFinishedView(BuildContext context, DictationController c) {
    final correct = c.correctCount;
    final total = c.task.words.length;
    final rate = total > 0 ? correct / total : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(rate >= 0.8 ? '🏆' : rate >= 0.6 ? '👍' : '💪',
                style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            const Text('听写完成！', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16)],
              ),
              child: Column(
                children: [
                  _summaryRow('✅ 答对', '$correct 个'),
                  _summaryRow('❌ 答错', '${total - correct} 个'),
                  _summaryRow('🎯 正确率', '${(rate * 100).toStringAsFixed(0)}%'),
                  _summaryRow('⭐ 本次积分', '+${c.totalScore}'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(onPressed: () => Get.back(), child: const Text('返回首页')),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Get.toNamed('/wrong-words'),
                  child: const Text('复习错词 📝'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 底部呼吸灯麦克风指示器
// ─────────────────────────────────────────────────────────────────────────────
class _VoiceIndicator extends StatelessWidget {
  final DictationController c;
  const _VoiceIndicator(this.c);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppTheme.bgLight,
      child: Obx(() {
        final isActive = c.state.value == DictationState.listening ||
                         c.state.value == DictationState.waiting ||
                         c.state.value == DictationState.recording;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BreathingMic(isActive: isActive),
            const SizedBox(width: 8),
            Text(
              isActive ? '小Wo同学 在线' : '小Wo同学 待机中',
              style: TextStyle(
                fontSize: 13,
                color: isActive ? AppTheme.primary : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _BreathingMic extends StatefulWidget {
  final bool isActive;
  const _BreathingMic({required this.isActive});
  @override
  State<_BreathingMic> createState() => _BreathingMicState();
}

class _BreathingMicState extends State<_BreathingMic> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_BreathingMic old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _ac.repeat(reverse: true);
    if (!widget.isActive && old.isActive) { _ac.stop(); _ac.reset(); }
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: widget.isActive ? _anim.value : 0.3,
        child: const Icon(Icons.mic, color: AppTheme.primary, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 麦克风大按钮
// ─────────────────────────────────────────────────────────────────────────────
class _MicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback? onPressed;
  const _MicButton({required this.isRecording, this.onPressed});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) _ac.repeat(reverse: true);
    if (!widget.isRecording && old.isRecording) { _ac.stop(); _ac.reset(); }
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, child) => Transform.scale(
        scale: widget.isRecording ? _scale.value : 1.0,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isRecording ? AppTheme.error : AppTheme.primary,
            boxShadow: [
              BoxShadow(
                color: (widget.isRecording ? AppTheme.error : AppTheme.primary)
                    .withOpacity(_glow.value),
                blurRadius: widget.isRecording ? 30 : 15,
                spreadRadius: widget.isRecording ? 5 : 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(48),
              onTap: widget.onPressed,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white, size: widget.isRecording ? 40 : 44),
                  const SizedBox(height: 2),
                  Text(widget.isRecording ? '停止' : '说话',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 圆形图标按钮
// ─────────────────────────────────────────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  const _CircleButton({required this.icon, required this.label,
    this.onPressed, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed != null ? color.withOpacity(0.15) : color.withOpacity(0.05),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(size / 2),
              onTap: onPressed,
              child: Icon(icon,
                  color: onPressed != null ? color : color.withOpacity(0.4), size: size * 0.45),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(onPressed != null ? 1 : 0.4))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 朗读中喇叭动画
// ─────────────────────────────────────────────────────────────────────────────
class _WordCard extends StatelessWidget {
  final DictationController c;
  final bool isReading;
  const _WordCard(this.c, {required this.isReading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isReading
              ? [AppTheme.primary, const Color(0xFF9C8FFF)]
              : [const Color(0xFF56CCF2), const Color(0xFF2F80ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isReading ? AppTheme.primary : const Color(0xFF2F80ED)).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _AnimatedSpeaker(isActive: isReading),
          const SizedBox(height: 16),
          Text(
            isReading ? '仔细听发音' : '听到后点击麦克风',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _AnimatedSpeaker extends StatefulWidget {
  final bool isActive;
  const _AnimatedSpeaker({required this.isActive});
  @override
  State<_AnimatedSpeaker> createState() => _AnimatedSpeakerState();
}

class _AnimatedSpeakerState extends State<_AnimatedSpeaker> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }
  @override
  void didUpdateWidget(_AnimatedSpeaker old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _ac.repeat(reverse: true);
    if (!widget.isActive && old.isActive) { _ac.stop(); _ac.reset(); }
  }
  @override
  void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) => Transform.scale(
        scale: widget.isActive ? 1.0 + _ac.value * 0.2 : 1.0,
        child: const Icon(Icons.volume_up, color: Colors.white, size: 56),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 录音中波纹指示器
// ─────────────────────────────────────────────────────────────────────────────
class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator();
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator> with TickerProviderStateMixin {
  late AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          final offset = (i - 2).abs() / 4;
          final height = 12.0 + 16 * (((_ac.value - offset) % 1.0)) * 10;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6,
            height: height.clamp(8.0, 28.0),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.6 + offset * 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 脉冲动画文字
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingText extends StatefulWidget {
  final String text;
  const _PulsingText(this.text);
  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ac);
  }
  @override
  void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Text(widget.text, style: const TextStyle(fontSize: 18, color: AppTheme.primary)),
  );
}
