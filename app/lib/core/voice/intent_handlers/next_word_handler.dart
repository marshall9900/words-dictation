import 'package:get/get.dart';
import 'intent_handler.dart';
import '../nluc_engine.dart';
import '../../../pages/dictation_page.dart';

/// 下一个单词 Handler
class NextWordHandler implements IntentHandler {
  @override
  bool canHandle(VoiceIntent intent) => intent == VoiceIntent.nextWord;

  @override
  Future<void> handle(IntentHandlerContext ctx) async {
    if (!Get.isRegistered<DictationController>(tag: 'DictationController')) return;
    final c = Get.find<DictationController>(tag: 'DictationController');
    c.nextWord();
  }
}
