import 'package:get/get.dart';
import 'intent_handler.dart';
import '../nluc_engine.dart';
import '../../../pages/dictation_page.dart';

/// 重新开始当前单词 Handler
class RestartHandler implements IntentHandler {
  @override
  bool canHandle(VoiceIntent intent) => intent == VoiceIntent.restart;

  @override
  Future<void> handle(IntentHandlerContext ctx) async {
    if (!Get.isRegistered<DictationController>(tag: 'DictationController')) return;
    final c = Get.find<DictationController>(tag: 'DictationController');
    c.restartCurrentWord();
  }
}
