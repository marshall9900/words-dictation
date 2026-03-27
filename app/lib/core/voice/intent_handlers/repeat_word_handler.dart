import 'package:get/get.dart';
import 'intent_handler.dart';
import '../nluc_engine.dart';
import '../../../pages/dictation_page.dart';

/// 重复单词 Handler
class RepeatWordHandler implements IntentHandler {
  @override
  bool canHandle(VoiceIntent intent) => intent == VoiceIntent.repeatWord;

  @override
  Future<void> handle(IntentHandlerContext ctx) async {
    if (!Get.isRegistered<DictationController>(tag: 'DictationController')) return;
    final c = Get.find<DictationController>(tag: 'DictationController');
    await c.repeatWord();
  }
}
