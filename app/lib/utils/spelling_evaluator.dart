import '../models/models.dart';

/// 离线拼写评测器
/// 不依赖网络，在本地完成拼写对比和评分
class SpellingEvaluator {
  /// 评测拼写结果
  EvaluationResult evaluate({
    required String wordId,
    required String expectedWord,
    required String actualAnswer,
  }) {
    // TODO: 实现 - 拼写对比（忽略大小写、去除首尾空格）
    final normalized = actualAnswer.trim().toLowerCase();
    final expected = expectedWord.trim().toLowerCase();
    final isCorrect = normalized == expected;

    return EvaluationResult(
      wordId: wordId,
      expectedWord: expectedWord,
      actualAnswer: actualAnswer,
      isCorrect: isCorrect,
      score: isCorrect ? 1.0 : 0.0,
    );
  }

  /// 计算编辑距离（用于相似度评分）
  int editDistance(String s1, String s2) {
    // TODO: 实现 - Levenshtein 距离
    return 0;
  }

  /// 生成纠错提示
  String? generateSuggestion(String expected, String actual) {
    // TODO: 实现 - 指出具体拼写错误位置
    return null;
  }
}
