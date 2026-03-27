import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'nluc_engine.dart';
import 'wake_word_detector.dart';

/// 语音助手状态枚举
enum VoiceAssistantState {
  idle,
  listening,
  executing,
  dictationMode,
}

/// 语音助手全局服务（GetX Service）
class VoiceAssistant extends GetxService {
  final _state = VoiceAssistantState.idle.obs;
  final _lastIntent = Rx<VoiceIntent?>(null);
  final _wakeWordDetector = SttWakeWordDetector();
  final _nlucEngine = NLUEngine();
  stt.SpeechToText? _stt;

  VoiceAssistantState get state => _state.value;
  VoiceIntent? get lastIntent => _lastIntent.value;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    _stt = stt.SpeechToText();
    await _stt!.initialize();

    // 监听唤醒词
    _wakeWordDetector.onWakeWordDetected.listen((detected) {
      if (detected) {
        _state.value = VoiceAssistantState.listening;
        _listenForCommand();
      }
    });

    // 启动唤醒词监听
    await _wakeWordDetector.start();
  }

  /// 开始听写模式：关闭唤醒词监听，进入 dictationMode
  void enterDictationMode() {
    _wakeWordDetector.stop();
    _state.value = VoiceAssistantState.dictationMode;
  }

  /// 退出听写模式：恢复唤醒词监听
  void exitDictationMode() {
    _state.value = VoiceAssistantState.idle;
    _wakeWordDetector.start(); // 恢复唤醒词监听
  }

  /// 在 dictationMode 中响应语音指令
  Future<void> handleDictationCommand(String recognizedText) async {
    if (_state.value != VoiceAssistantState.dictationMode) return;

    _state.value = VoiceAssistantState.executing;
    final result = await _nlucEngine.parse(recognizedText);
    _lastIntent.value = result.intent;

    if (result.intent == VoiceIntent.goBack) {
      exitDictationMode();
      Get.back();
      return;
    }

    // 其他指令通过 tag 查找 DictationController 执行（避免循环依赖）
    try {
      // ignore: avoid_dynamic_calls
      final dc = Get.find(tag: 'DictationController');
      // ignore: avoid_dynamic_calls
      dc.handleVoiceCommand(result.intent);
    } catch (_) {
      // DictationController 尚未注册，忽略
    }

    _state.value = VoiceAssistantState.dictationMode;
  }

  /// 通用指令处理（listening 状态）
  Future<void> _listenForCommand() async {
    await _stt!.listen(
      onResult: (result) {
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            _executeCommand(text);
          }
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'zh_CN',
    );
  }

  Future<void> _executeCommand(String text) async {
    _state.value = VoiceAssistantState.executing;
    final result = await _nlucEngine.parse(text);
    _lastIntent.value = result.intent;

    // 根据 intent 跳转页面
    if (result.intent == VoiceIntent.startDictation) {
      Get.toNamed('/dictation');
      // 通知 DictationController 进入听写模式（延迟引用，避免循环依赖）
      try {
        // ignore: avoid_dynamic_calls
        final dc = Get.find(tag: 'DictationController');
        // ignore: avoid_dynamic_calls
        dc.enterVoiceMode();
      } catch (_) {
        // DictationController 尚未注册，忽略
      }
      _state.value = VoiceAssistantState.idle;
      return;
    }

    if (result.intent == VoiceIntent.openWrongWords) {
      Get.toNamed('/wrong_words');
      _state.value = VoiceAssistantState.idle;
      return;
    }

    // 未知指令，提示后恢复
    Get.snackbar('小Wo', '没听懂，请再说一遍',
        duration: const Duration(seconds: 2));
    _state.value = VoiceAssistantState.listening;
    _listenForCommand();
  }

  @override
  void onClose() {
    _wakeWordDetector.dispose();
    _stt?.stop();
    super.onClose();
  }
}
