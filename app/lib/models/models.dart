/// Words Dictation v2 - 数据模型
library models;

// ── 动态绘本模型 ──────────────────────────────────────────

/// 绘本帧（一张图片 + 一段配音）
class PictureBookFrame {
  final int index;
  final String text;       // 讲解文字
  final String? imageUrl;  // 图片 CDN URL
  final String? audioUrl;  // 音频 CDN URL
  final int durationMs;    // 预估时长（毫秒）

  const PictureBookFrame({
    required this.index,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    required this.durationMs,
  });

  factory PictureBookFrame.fromJson(Map<String, dynamic> json) {
    return PictureBookFrame(
      index: json['index'] ?? 0,
      text: json['text'] ?? '',
      imageUrl: json['image'],
      audioUrl: json['audio'],
      durationMs: json['durationMs'] ?? 4000,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'text': text,
    'image': imageUrl,
    'audio': audioUrl,
    'durationMs': durationMs,
  };
}

/// 动态绘本时间轴
class PictureBookTimeline {
  final String bookId;
  final String wordId;
  final String word;
  final List<PictureBookFrame> frames;
  final int totalDurationMs;
  final String? generatedAt;

  const PictureBookTimeline({
    required this.bookId,
    required this.wordId,
    required this.word,
    required this.frames,
    required this.totalDurationMs,
    this.generatedAt,
  });

  factory PictureBookTimeline.fromJson(Map<String, dynamic> json) {
    final framesJson = json['frames'] as List? ?? [];
    return PictureBookTimeline(
      bookId: json['bookId'] ?? '',
      wordId: json['wordId'] ?? '',
      word: json['word'] ?? '',
      frames: framesJson.map((f) => PictureBookFrame.fromJson(f as Map<String, dynamic>)).toList(),
      totalDurationMs: json['totalDurationMs'] ?? 0,
      generatedAt: json['generatedAt'],
    );
  }

  int get frameCount => frames.length;
  Duration get totalDuration => Duration(milliseconds: totalDurationMs);
}

/// 动态绘本记录
class PictureBook {
  final String id;
  final String wordId;
  final String word;
  final String status;
  final PictureBookTimeline? timeline;
  final String? timelineUrl;
  final int frameCount;
  final int totalDurationMs;
  final DateTime? createdAt;

  const PictureBook({
    required this.id,
    required this.wordId,
    required this.word,
    required this.status,
    this.timeline,
    this.timelineUrl,
    required this.frameCount,
    required this.totalDurationMs,
    this.createdAt,
  });

  factory PictureBook.fromJson(Map<String, dynamic> json) {
    PictureBookTimeline? timeline;
    if (json['timeline'] != null) {
      timeline = PictureBookTimeline.fromJson(json['timeline'] as Map<String, dynamic>);
    }

    return PictureBook(
      id: json['id'] ?? json['bookId'] ?? '',
      wordId: json['wordId'] ?? json['word_id'] ?? '',
      word: json['word'] ?? '',
      status: json['status'] ?? 'active',
      timeline: timeline,
      timelineUrl: json['timelineUrl'] ?? json['timeline_url'],
      frameCount: json['frameCount'] ?? json['frame_count'] ?? 0,
      totalDurationMs: json['totalDurationMs'] ?? json['total_duration_ms'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
}

// ── 用户模型 ──────────────────────────────────────────────

class User {
  final String id;
  final String nickname;
  final int grade;
  final bool isPremium;
  final int totalScore;
  final int streakDays;

  const User({
    required this.id,
    required this.nickname,
    required this.grade,
    required this.isPremium,
    required this.totalScore,
    required this.streakDays,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '小学生',
      grade: json['grade'] ?? 3,
      isPremium: (json['is_premium'] == 1 || json['is_premium'] == true),
      totalScore: json['total_score'] ?? 0,
      streakDays: json['streak_days'] ?? 0,
    );
  }
}

// ── 单词模型 ──────────────────────────────────────────────

class Word {
  final String id;
  final String word;
  final String? phonetic;
  final String? translation;
  final String? exampleSentence;
  final String? explanation;
  final int difficulty;

  const Word({
    required this.id,
    required this.word,
    this.phonetic,
    this.translation,
    this.exampleSentence,
    this.explanation,
    required this.difficulty,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] ?? '',
      word: json['word'] ?? '',
      phonetic: json['phonetic'],
      translation: json['translation'],
      exampleSentence: json['example_sentence'],
      explanation: json['explanation'],
      difficulty: json['difficulty'] ?? 2,
    );
  }
}

// ── 生成任务状态 ──────────────────────────────────────────

class GenerationJob {
  final String jobId;
  final String state; // waiting | active | completed | failed
  final int progress;
  final PictureBook? result;
  final String? error;

  const GenerationJob({
    required this.jobId,
    required this.state,
    required this.progress,
    this.result,
    this.error,
  });

  factory GenerationJob.fromJson(Map<String, dynamic> json) {
    return GenerationJob(
      jobId: json['jobId'] ?? '',
      state: json['state'] ?? 'waiting',
      progress: json['progress'] ?? 0,
      result: json['result'] != null
          ? PictureBook.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      error: json['error'],
    );
  }

  bool get isCompleted => state == 'completed';
  bool get isFailed => state == 'failed';
  bool get isPending => state == 'waiting' || state == 'active';
}
