import 'package:get/get.dart';
import 'intent_handler.dart';
import '../nluc_engine.dart';
import '../../../services/api_service.dart';
import '../../../services/audio_service.dart';
import '../../../pages/dictation_page.dart';

/// 路由常量（临时定义，待统一到 AppRoutes）
class _Routes {
  static const String dictation = '/dictation';
  static const String wrongWords = '/wrong-words';
}

/// 开始听写 Handler
class StartDictationHandler implements IntentHandler {
  @override
  bool canHandle(VoiceIntent intent) => intent == VoiceIntent.startDictation;

  @override
  Future<void> handle(IntentHandlerContext ctx) async {
    // 1. 创建听写任务
    final api = Get.find<ApiService>();
    final task = await api.createTask(count: 10);
    if (task == null) {
      Get.snackbar(
        '小Wo',
        '创建听写任务失败，请检查网络',
        duration: const Duration(seconds: 3),
      );
      return;
    }
    // 2. 跳转听写页
    Get.toNamed(_Routes.dictation, arguments: task);
    // 3. 通知 DictationController 进入语音模式
    await Future.delayed(const Duration(milliseconds: 500));
    if (Get.isRegistered<DictationController>(tag: 'DictationController')) {
      Get.find<DictationController>(tag: 'DictationController').enterVoiceMode();
    }
    // 4. TTS 反馈
    final audio = Get.find<AudioService>();
    await audio.speak('好的，开始听写！');
  }
}
