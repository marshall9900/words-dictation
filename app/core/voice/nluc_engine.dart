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

class NLUResult {
  final VoiceIntent intent;
  final String query; // 原始识别文字
  final double confidence; // 0.0-1.0

  const NLUResult({
    required this.intent,
    required this.query,
    required this.confidence,
  });
}

class NLUEngine {
  /// 将语音识别文字解析为 Intent
  /// 本地兜底：关键词匹配（离线可用）
  /// 远程：MiniMax T2R API（若可用）
  Future<NLUResult> parse(String recognizedText) async {
    final text = recognizedText.toLowerCase().trim();

    // 本地关键词匹配（优先级高，离线可用）
    final local = _localParse(text);
    if (local != null) return local;

    // 远程解析（可选）
    try {
      return await _remoteParse(text);
    } catch (_) {
      return NLUResult(intent: VoiceIntent.unknown, query: text, confidence: 0);
    }
  }

  NLUResult? _localParse(String text) {
    // startDictation: "开始听写" / "听写" / "start dictation" / "start"
    if (text.contains('开始听写') ||
        text.contains('听写') ||
        text.contains('start') ||
        text.contains('dictation')) {
      return NLUResult(
        intent: VoiceIntent.startDictation,
        query: text,
        confidence: 0.95,
      );
    }
    // nextWord: "下一题" / "下一个" / "next" / "skip"
    if (text.contains('下一题') ||
        text.contains('下一个') ||
        text.contains('next') ||
        text.contains('skip')) {
      return NLUResult(
        intent: VoiceIntent.nextWord,
        query: text,
        confidence: 0.95,
      );
    }
    // repeatWord: "复读" / "再说一遍" / "repeat" / "again"
    if (text.contains('复读') ||
        text.contains('再说一遍') ||
        text.contains('repeat') ||
        text.contains('again')) {
      return NLUResult(
        intent: VoiceIntent.repeatWord,
        query: text,
        confidence: 0.95,
      );
    }
    // openWrongWords: "打开错词本" / "错词本" / "wrong words"
    if (text.contains('错词本') || text.contains('wrong')) {
      return NLUResult(
        intent: VoiceIntent.openWrongWords,
        query: text,
        confidence: 0.95,
      );
    }
    // goBack: "返回" / "上一页" / "back"
    if (text.contains('返回') ||
        text.contains('上一页') ||
        text.contains('back')) {
      return NLUResult(
        intent: VoiceIntent.goBack,
        query: text,
        confidence: 0.95,
      );
    }
    // restart: "重新开始" / "再来" / "restart" / "reset"
    if (text.contains('重新开始') ||
        text.contains('restart') ||
        text.contains('reset')) {
      return NLUResult(
        intent: VoiceIntent.restart,
        query: text,
        confidence: 0.95,
      );
    }
    // submit: "提交" / "答完了" / "submit" / "done"
    if (text.contains('提交') ||
        text.contains('答完了') ||
        text.contains('submit') ||
        text.contains('done')) {
      return NLUResult(
        intent: VoiceIntent.submit,
        query: text,
        confidence: 0.95,
      );
    }
    return null;
  }

  Future<NLUResult> _remoteParse(String text) async {
    // TODO: 调用 MiniMax T2R API
    // POST https://api.minimax.io/v1/text/to_text
    // body: {"model": "T2R", "text": "<recognizedText>"}
    // 返回结构化 Intent（Phase 2 实现）
    throw UnimplementedError('Phase 2');
  }
}
