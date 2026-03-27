/// App 全局常量
class AppConstants {
  AppConstants._();

  // 唤醒词
  static const String wakeWord = '小助手';
  static const List<String> wakeWordVariants = ['小助手', '你好小助手'];

  // TTS 配置
  static const double ttsRate = 0.4;
  static const double ttsPitch = 1.0;
  static const double ttsVolume = 1.0;
  static const String ttsLanguage = 'zh-CN';

  // API 配置（v2 后端运行在 3001）
  static const String apiBaseUrl = 'http://localhost:3001/api/v1';
  static const int apiTimeoutSeconds = 30;

  // 本地 DB
  static const String dbName = 'words_dictation_v2.db';
  static const int dbVersion = 1;

  // 艾宾浩斯复习间隔（天）
  static const List<int> ebginghausIntervals = [1, 2, 4, 7, 15, 30];

  // TODO: 实现 - 补充更多常量
}
