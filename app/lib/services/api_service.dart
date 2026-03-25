/// API 服务层 - 封装所有后端接口调用
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  String? _authToken;

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api/v1',
  );

  Future<void> init() async {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // 请求拦截器（自动附带 Token）
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token 过期，清除本地登录态
          clearToken();
        }
        handler.next(error);
      },
    ));

    // 加载已保存的 token
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  Future<String?> getToken() async {
    if (_authToken != null) return _authToken;
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    return _authToken;
  }

  Future<void> saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ── 绘本 API ──────────────────────────────────────────

  /// 生成动态绘本（异步队列模式）
  Future<Map<String, dynamic>> generatePictureBook({
    required String wordId,
    required String word,
    String? explanation,
    bool async_ = true,
  }) async {
    final res = await _dio.post('/picturebook/generate', data: {
      'wordId': wordId,
      'word': word,
      if (explanation != null) 'explanation': explanation,
      'async': async_,
    });
    return res.data as Map<String, dynamic>;
  }

  /// 获取绘本详情（含时间轴）
  Future<PictureBook?> getPictureBook(String bookId) async {
    try {
      final res = await _dio.get('/picturebook/$bookId');
      final data = (res.data as Map<String, dynamic>)['data'];
      return PictureBook.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 按单词获取最新绘本
  Future<PictureBook?> getPictureBookByWord(String wordId) async {
    try {
      final res = await _dio.get('/picturebook/word/$wordId');
      final data = (res.data as Map<String, dynamic>)['data'];
      return PictureBook.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 查询异步任务状态
  Future<GenerationJob?> getJobStatus(String jobId) async {
    try {
      final res = await _dio.get('/picturebook/job/$jobId');
      final data = (res.data as Map<String, dynamic>)['data'];
      return GenerationJob.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 等待任务完成（轮询，最多等待指定时间）
  Future<PictureBook?> waitForJob(
    String jobId, {
    Duration timeout = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final job = await getJobStatus(jobId);
      if (job == null) return null;
      if (job.isCompleted && job.result != null) return job.result;
      if (job.isFailed) throw Exception('PictureBook generation failed: ${job.error}');
      await Future.delayed(pollInterval);
    }
    throw TimeoutException('PictureBook generation timed out', timeout);
  }
}
