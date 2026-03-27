import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import '../core/constants.dart';

/// 音频/TTS 服务（儿童友好，语速 0.4）
class AudioService extends GetxService {
  late final FlutterTts _tts;
  final AudioPlayer _sfxPlayer = AudioPlayer();

  final RxBool isSpeaking = false.obs;
  bool get speaking => isSpeaking.value;

  @override
  void onInit() {
    super.onInit();
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage(AppConstants.ttsLanguage);       // 'zh-CN'
    await _tts.setSpeechRate(AppConstants.ttsRate);        // 0.4 儿童慢速
    await _tts.setPitch(AppConstants.ttsPitch);            // 1.0
    await _tts.setVolume(AppConstants.ttsVolume);          // 1.0

    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(() => isSpeaking.value = false);
    _tts.setErrorHandler((_) => isSpeaking.value = false);
    _tts.setCancelHandler(() => isSpeaking.value = false);
  }

  /// 朗读单词（读两遍，适合听写）
  Future<void> speakWord(String word, {int times = 2}) async {
    for (int i = 0; i < times; i++) {
      await _tts.setLanguage('en_US');
      await _tts.speak(word);
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    await _tts.setLanguage(AppConstants.ttsLanguage); // 恢复中文
  }

  /// 通用 TTS（中文）
  Future<void> speak(String text) async {
    await _tts.setLanguage(AppConstants.ttsLanguage);
    await _tts.speak(text);
  }

  /// 鼓励语（不等待完成，并行播放）
  Future<void> speakEncouragement(String message) async {
    await _tts.setLanguage(AppConstants.ttsLanguage);
    _tts.speak(message); // 不 await，平行说
  }

  /// 错误温柔纠正 TTS
  Future<void> speakWrongFeedback(String correctWord) async {
    await _tts.setLanguage(AppConstants.ttsLanguage);
    await _tts.speak('没关系宝贝，正确答案是 $correctWord');
  }

  /// 听写完成报告
  Future<void> speakReport(int correct, int total) async {
    final rate = (correct / total * 100).round();
    await _tts.setLanguage(AppConstants.ttsLanguage);
    await _tts.speak('听写完成！你答对了 $correct 个，总共 $total 个，正确率 $rate%。太棒了！');
  }

  /// 停止播放
  Future<void> stop() async {
    await _tts.stop();
    isSpeaking.value = false;
  }

  /// 播放音效（答对/答错）
  Future<void> playSound(String assetPath) async {
    try {
      await _sfxPlayer.play(AssetSource(assetPath));
    } catch (_) {
      // 音效文件缺失时静默跳过
    }
  }

  /// 答对音效
  Future<void> playSuccess() async {
    await playSound('sounds/success.mp3');
  }

  /// 答错音效
  Future<void> playError() async {
    await playSound('sounds/error.mp3');
  }

  @override
  void onClose() {
    _tts.stop();
    _sfxPlayer.dispose();
    super.onClose();
  }
}
