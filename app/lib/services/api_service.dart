import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../core/constants.dart';
import '../utils/spelling_evaluator.dart';
import 'local_db_service.dart';

/// 任务完成报告
class TaskReport {
  final int totalWords;
  final int correctCount;
  final double correctRate;
  final double score;
  final List<Map<String, dynamic>> wrongWords;
  final List<String> achievements;

  const TaskReport({
    required this.totalWords,
    required this.correctCount,
    required this.correctRate,
    required this.score,
    this.wrongWords = const [],
    this.achievements = const [],
  });

  factory TaskReport.fromJson(Map<String, dynamic> json) {
    return TaskReport(
      totalWords: (json['totalWords'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      correctRate: (json['correctRate'] as num?)?.toDouble() ?? 0.0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      wrongWords: (json['wrongWords'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      achievements:
          (json['achievements'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
  }
}

/// v2 后端 API 服务（纯 Dio，无 auth 包装器）
class ApiService extends GetxService {
  late final Dio _dio;
  final _evaluator = SpellingEvaluator();

  @override
  void onInit() {
    super.onInit();
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout:
          const Duration(seconds: AppConstants.apiTimeoutSeconds),
      receiveTimeout:
          const Duration(seconds: AppConstants.apiTimeoutSeconds),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  // ─── 听写任务 ───────────────────────────────────────────

  /// 创建听写任务
  Future<DictationTask?> createTask({
    List<String>? wordIds,
    int count = 10,
    int grade = 1,
  }) async {
    try {
      final body = <String, dynamic>{'count': count, 'grade': grade};
      if (wordIds != null) body['wordIds'] = wordIds;

      final resp = await _dio.post('/api/v1/dictation/task', data: body);
      return _parseTask(resp.data as Map<String, dynamic>);
    } catch (e) {
      print('[ApiService] createTask error: $e');
      return null;
    }
  }

  /// 获取听写任务详情
  Future<DictationTask?> getTask(String taskId) async {
    try {
      final resp = await _dio.get('/api/v1/dictation/task/$taskId');
      return _parseTask(resp.data as Map<String, dynamic>);
    } catch (e) {
      print('[ApiService] getTask error: $e');
      return null;
    }
  }

  /// 开始任务
  Future<void> startTask(String taskId) async {
    try {
      await _dio.put('/api/v1/dictation/task/$taskId/start');
    } catch (e) {
      print('[ApiService] startTask error: $e');
    }
  }

  /// 完成任务，返回报告
  Future<TaskReport> completeTask(String taskId) async {
    try {
      final resp =
          await _dio.post('/api/v1/dictation/task/$taskId/complete');
      final data = resp.data as Map<String, dynamic>;
      return TaskReport.fromJson(data['report'] as Map<String, dynamic>);
    } catch (e) {
      print('[ApiService] completeTask error: $e');
      // 离线兜底：返回空报告
      return const TaskReport(
        totalWords: 0,
        correctCount: 0,
        correctRate: 0.0,
        score: 0.0,
      );
    }
  }

  // ─── 评测 ───────────────────────────────────────────────

  /// 拼写评测（离线兜底：网络异常时使用 SpellingEvaluator）
  Future<EvaluationResult> evaluateSpelling({
    required String taskId,
    required String wordId,
    required String userInput,
  }) async {
    try {
      final resp = await _dio.post(
        '/api/v1/evaluation/spelling',
        data: {'taskId': taskId, 'wordId': wordId, 'userInput': userInput},
      );
      final data = resp.data as Map<String, dynamic>;
      return EvaluationResult.fromJson(data);
    } on DioException catch (e) {
      print('[ApiService] evaluateSpelling network error, falling back to offline: $e');
      // 离线兜底：尝试从本地 DB 读取标准词
      try {
        final db = Get.find<LocalDbService>();
        final ww = await db.getWrongWord(wordId);
        if (ww != null) {
          return _evaluator.evaluate(
            wordId: wordId,
            expectedWord: ww.word.word,
            actualAnswer: userInput,
          );
        }
      } catch (_) {}
      // 完全离线且 DB 没有：返回未知
      return EvaluationResult(
        wordId: wordId,
        expectedWord: '（离线）',
        actualAnswer: userInput,
        isCorrect: false,
        score: 0.0,
        suggestion: '离线模式无法评测',
      );
    }
  }

  // ─── 错词本 ─────────────────────────────────────────────

  /// 获取错词列表
  Future<List<WrongWord>> getWrongWords() async {
    try {
      final resp = await _dio.get('/api/v1/wrongword');
      final list = resp.data as List<dynamic>;
      return list.map((e) => _parseWrongWord(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[ApiService] getWrongWords error: $e');
      return [];
    }
  }

  /// 添加错词
  Future<void> addWrongWord(WrongWord ww) async {
    try {
      await _dio.post('/api/v1/wrongword', data: _wrongWordToJson(ww));
    } catch (e) {
      print('[ApiService] addWrongWord error: $e');
    }
  }

  /// 更新错词（PATCH）
  Future<void> updateWrongWord(WrongWord ww) async {
    try {
      await _dio.patch('/api/v1/wrongword/${ww.id}', data: _wrongWordToJson(ww));
    } catch (e) {
      print('[ApiService] updateWrongWord error: $e');
    }
  }

  // ─── 私有解析工具 ────────────────────────────────────────

  DictationTask _parseTask(Map<String, dynamic> json) {
    final wordsList = (json['words'] as List?)
            ?.map((e) => _parseWordItem(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DictationTask(
      taskId: json['taskId']?.toString() ?? json['id']?.toString() ?? '',
      bookId: json['bookId']?.toString(),
      words: wordsList,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      completedAt: _parseDateTime(json['completedAt']),
      totalWords: (json['totalWords'] as num?)?.toInt() ?? wordsList.length,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
    );
  }

  WordItem _parseWordItem(Map<String, dynamic> json) {
    return WordItem(
      id: json['id']?.toString() ?? json['wordId']?.toString() ?? '',
      word: json['word']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? json['translation']?.toString() ?? '',
      phonetic: json['phonetic']?.toString(),
      audioUrl: json['audioUrl']?.toString(),
      bookId: json['bookId']?.toString(),
      difficulty: (json['difficulty'] as num?)?.toInt(),
    );
  }

  WrongWord _parseWrongWord(Map<String, dynamic> json) {
    final wi = WordItem(
      id: json['wordId']?.toString() ?? '',
      word: json['word']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      phonetic: json['phonetic']?.toString(),
    );
    return WrongWord(
      wordId: json['wordId']?.toString() ?? '',
      word: wi,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      lastWrongAt: _parseDateTime(json['lastWrongAt']) ?? DateTime.now(),
      nextReviewAt: _parseDateTime(json['nextReviewAt']),
      sm2RepetitionCount: (json['repetitions'] as num?)?.toInt() ?? 0,
      sm2Easiness: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      sm2IntervalDays: (json['intervalDays'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> _wrongWordToJson(WrongWord ww) {
    return {
      'wordId': ww.wordId,
      'word': ww.word.word,
      'phonetic': ww.word.phonetic,
      'meaning': ww.word.meaning,
      'wrongCount': ww.wrongCount,
      'mastered': false,
      'nextReviewAt': ww.nextReviewAt?.toIso8601String(),
      'repetitions': ww.sm2RepetitionCount,
      'easeFactor': ww.sm2Easiness,
    };
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
