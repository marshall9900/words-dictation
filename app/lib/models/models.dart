/// 单词条目
class WordItem {
  final String id;
  final String word;
  final String meaning;        // 含义（API 返回 meaning）
  final String? phonetic;
  final String? audioUrl;
  final String? bookId;
  final int? difficulty;       // 0.0-1.0，API 字段 difficulty

  const WordItem({
    required this.id,
    required this.word,
    required this.meaning,
    this.phonetic,
    this.audioUrl,
    this.bookId,
    this.difficulty,
  });

  factory WordItem.fromJson(Map<String, dynamic> json) {
    return WordItem(
      id: json['wordId'] as String? ?? json['id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      phonetic: json['phonetic'] as String?,
      audioUrl: json['audioUrl'] as String?,
      bookId: json['bookId'] as String?,
      difficulty: json['difficulty'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'wordId': id, 'word': word, 'meaning': meaning,
    'phonetic': phonetic, 'audioUrl': audioUrl,
    'bookId': bookId, 'difficulty': difficulty,
  };

  /// v2 后端 task word 格式兼容
  factory WordItem.fromTaskWord(Map<String, dynamic> json) {
    return WordItem(
      id: json['wordId'] as String? ?? json['id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      meaning: json['meaning'] as String? ?? json['translation'] as String? ?? '',
      phonetic: json['phonetic'] as String?,
      audioUrl: json['audioUrl'] as String?,
      bookId: json['bookId'] as String?,
      difficulty: json['difficulty'] as int?,
    );
  }
}

/// 错词记录（艾宾浩斯复习）
class WrongWord {
  final String wordId;              // 单词 ID（不是 UUID，是 wordId）
  final WordItem word;              // 单词详情
  final int wrongCount;            // 错词次数
  final DateTime? lastWrongAt;    // 上次错误时间
  final DateTime? nextReviewAt;   // 下次复习时间（SM-2）
  final int sm2RepetitionCount;    // SM-2: 连续正确次数
  final double sm2Easiness;        // SM-2: 易度因子 (默认 2.5)
  final int sm2IntervalDays;       // SM-2: 当前间隔天数
  final bool mastered;            // 是否已掌握

  const WrongWord({
    required this.wordId,
    required this.word,
    required this.wrongCount,
    this.lastWrongAt,
    this.nextReviewAt,
    this.sm2RepetitionCount = 0,
    this.sm2Easiness = 2.5,
    this.sm2IntervalDays = 1,
    this.mastered = false,
  });

  factory WrongWord.fromJson(Map<String, dynamic> json) {
    return WrongWord(
      wordId: json['wordId'] as String? ?? json['id'] as String? ?? '',
      word: WordItem(
        id: json['wordId'] as String? ?? '',
        word: json['word'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        phonetic: json['phonetic'] as String?,
      ),
      wrongCount: json['wrongCount'] as int? ?? 0,
      lastWrongAt: json['lastWrongAt'] != null
          ? DateTime.tryParse(json['lastWrongAt'] as String)
          : null,
      nextReviewAt: json['nextReviewAt'] != null
          ? DateTime.tryParse(json['nextReviewAt'] as String)
          : null,
      sm2RepetitionCount: json['repetitions'] as int? ?? 0,
      sm2Easiness: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      sm2IntervalDays: json['intervalDays'] as int? ?? 1,
      mastered: json['mastered'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'wordId': wordId,
    'wrongCount': wrongCount,
    'lastWrongAt': lastWrongAt?.toIso8601String(),
    'nextReviewAt': nextReviewAt?.toIso8601String(),
    'repetitions': sm2RepetitionCount,
    'easeFactor': sm2Easiness,
    'intervalDays': sm2IntervalDays,
    'mastered': mastered,
  };

  WrongWord copyWith({
    String? wordId, WordItem? word, int? wrongCount,
    DateTime? lastWrongAt, DateTime? nextReviewAt,
    int? sm2RepetitionCount, double? sm2Easiness,
    int? sm2IntervalDays, bool? mastered,
  }) {
    return WrongWord(
      wordId: wordId ?? this.wordId,
      word: word ?? this.word,
      wrongCount: wrongCount ?? this.wrongCount,
      lastWrongAt: lastWrongAt ?? this.lastWrongAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      sm2RepetitionCount: sm2RepetitionCount ?? this.sm2RepetitionCount,
      sm2Easiness: sm2Easiness ?? this.sm2Easiness,
      sm2IntervalDays: sm2IntervalDays ?? this.sm2IntervalDays,
      mastered: mastered ?? this.mastered,
    );
  }
}

/// 听写任务
class DictationTask {
  final String taskId;              // API 返回 taskId（兼容字段）
  final String? bookId;
  final List<WordItem> words;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int totalWords;
  final int correctCount;
  final int score;
  final String? status;

  const DictationTask({
    required this.taskId,
    this.bookId,
    required this.words,
    required this.createdAt,
    this.completedAt,
    this.totalWords = 0,
    this.correctCount = 0,
    this.score = 0,
    this.status,
  });

  // 兼容：从 API 原始数据构造（v2 后端 task 格式）
  factory DictationTask.fromJson(Map<String, dynamic> json) {
    final wordsList = (json['words'] as List<dynamic>?)
        ?.map((w) => WordItem.fromTaskWord(w as Map<String, dynamic>))
        .toList() ?? [];
    return DictationTask(
      taskId: json['taskId'] as String? ?? json['id'] as String? ?? '',
      bookId: json['bookId'] as String?,
      words: wordsList,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      totalWords: json['totalWords'] as int? ?? wordsList.length,
      correctCount: json['correctCount'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      status: json['status'] as String?,
    );
  }
}

/// 拼写评测结果
class EvaluationResult {
  final String wordId;
  final String expectedWord;
  final String actualAnswer;
  final bool isCorrect;
  final double score;
  final String? suggestion;
  final int? spellingScore;     // v2 API 返回

  const EvaluationResult({
    required this.wordId,
    required this.expectedWord,
    required this.actualAnswer,
    required this.isCorrect,
    required this.score,
    this.suggestion,
    this.spellingScore,
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    final isCorrect = json['isCorrect'] as bool? ?? false;
    return EvaluationResult(
      wordId: json['wordId'] as String? ?? '',
      expectedWord: json['word'] as String? ?? '',
      actualAnswer: json['spellingInput'] as String? ?? '',
      isCorrect: isCorrect,
      score: (json['spellingScore'] as num?)?.toDouble() ??
             (isCorrect ? 1.0 : 0.0),
      suggestion: json['feedback'] as String?,
      spellingScore: json['spellingScore'] as int?,
    );
  }
}

/// 听写完成报告
class TaskReport {
  final int totalWords;
  final int correctCount;
  final double correctRate;
  final int score;
  final List<WordItem> wrongWords;

  const TaskReport({
    required this.totalWords,
    required this.correctCount,
    required this.correctRate,
    required this.score,
    required this.wrongWords,
  });

  factory TaskReport.fromJson(Map<String, dynamic> json) {
    final report = json['report'] as Map<String, dynamic>? ?? json;
    return TaskReport(
      totalWords: report['totalWords'] as int? ?? 0,
      correctCount: report['correctCount'] as int? ?? 0,
      correctRate: (report['correctRate'] as num?)?.toDouble() ?? 0.0,
      score: report['score'] as int? ?? 0,
      wrongWords: (report['wrongWords'] as List<dynamic>?)
          ?.map((w) => WordItem.fromTaskWord(w as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
