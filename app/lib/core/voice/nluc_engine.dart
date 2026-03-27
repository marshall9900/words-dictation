/// 语音意图枚举
enum VoiceIntent {
  unknown,
  startDictation,
  nextWord,
  repeatWord,
  openWrongWords,
  goBack,
  restart,
  submit,
}

/// NLU 引擎：将语音文本解析为 VoiceIntent
class NLUEngine {
  /// 解析语音文本，返回对应意图
  VoiceIntent parse(String text) {
    // TODO: 实现
    return VoiceIntent.unknown;
  }

  /// 初始化引擎（加载意图规则）
  Future<void> initialize() async {
    // TODO: 实现
  }
}
