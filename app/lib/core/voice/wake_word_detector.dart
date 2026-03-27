import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../constants.dart';

/// 抽象接口：唤醒词检测器
abstract class WakeWordDetector {
  /// true = 检测到唤醒词
  Stream<bool> get onWakeWordDetected;

  Future<void> start();
  Future<void> stop();
  void dispose();
}

/// 基于 speech_to_text 的实现
/// 使用持续监听 + 关键词匹配检测唤醒词
class SttWakeWordDetector implements WakeWordDetector {
  final _controller = StreamController<bool>.broadcast();
  stt.SpeechToText? _stt;
  bool _isListening = false;
  final String _wakeWord = AppConstants.wakeWord;

  /// 是否处于唤醒后的指令监听模式（切换到 en_US）
  bool _commandMode = false;

  @override
  Stream<bool> get onWakeWordDetected => _controller.stream;

  @override
  Future<void> start() async {
    _stt = stt.SpeechToText();
    final available = await _stt!.initialize(
      onError: (error) {
        // 静默处理初始化错误，继续循环
      },
    );
    if (!available) return;
    _isListening = true;
    _commandMode = false;
    _startListeningLoop();
  }

  Future<void> _startListeningLoop() async {
    while (_isListening) {
      // 唤醒词检测阶段：zh_CN 持续监听
      if (!_commandMode) {
        await _stt!.listen(
          onResult: (result) {
            if (result.finalResult) {
              final text = result.recognizedWords.toLowerCase();
              if (text.contains(_wakeWord.toLowerCase())) {
                // 检测到唤醒词，切换到指令模式
                _commandMode = true;
                _controller.add(true);
              }
            }
          },
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 2),
          localeId: 'zh-CN',
        );
      } else {
        // 指令接收阶段：切换到 en_US，等待外部 VoiceAssistant 接管
        // 一旦发出唤醒信号，退出循环，由外部接管
        // 外部调用 stop() 后重新 start() 可恢复唤醒词监听
        _isListening = false;
        break;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// 外部 VoiceAssistant 完成指令处理后，调用此方法重新进入唤醒词监听模式
  void resetToWakeWordMode() {
    _commandMode = false;
    if (!_isListening) {
      _isListening = true;
      _startListeningLoop();
    }
  }

  @override
  Future<void> stop() async {
    _isListening = false;
    _commandMode = false;
    await _stt?.stop();
  }

  @override
  void dispose() {
    _isListening = false;
    _commandMode = false;
    _stt?.stop();
    _controller.close();
  }
}
