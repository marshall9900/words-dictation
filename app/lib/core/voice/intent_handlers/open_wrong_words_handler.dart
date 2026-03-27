import 'package:get/get.dart';
import 'intent_handler.dart';
import '../nluc_engine.dart';

/// 打开错词本 Handler
class OpenWrongWordsHandler implements IntentHandler {
  static const String _wrongWordsRoute = '/wrong-words';

  @override
  bool canHandle(VoiceIntent intent) => intent == VoiceIntent.openWrongWords;

  @override
  Future<void> handle(IntentHandlerContext ctx) async {
    Get.toNamed(_wrongWordsRoute);
  }
}
