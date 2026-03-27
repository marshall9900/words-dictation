import '../nluc_engine.dart';

/// 意图处理器上下文
class IntentHandlerContext {
  final VoiceIntent intent;
  final String query;
  final double confidence;

  IntentHandlerContext({
    required this.intent,
    required this.query,
    required this.confidence,
  });
}

/// 意图处理器抽象接口
abstract class IntentHandler {
  /// 是否可以处理该意图
  bool canHandle(VoiceIntent intent);

  /// 执行意图处理逻辑
  Future<void> handle(IntentHandlerContext ctx);
}
