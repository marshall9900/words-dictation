import 'package:get/get.dart';
import 'intent_handler.dart';
import '../nluc_engine.dart';

/// 返回上一页 Handler
class GoBackHandler implements IntentHandler {
  @override
  bool canHandle(VoiceIntent intent) => intent == VoiceIntent.goBack;

  @override
  Future<void> handle(IntentHandlerContext ctx) async {
    Get.back();
  }
}
