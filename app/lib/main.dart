import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/theme.dart';
import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/local_db_service.dart';
import 'core/voice/voice_assistant.dart';
import 'pages/home_page.dart';
import 'pages/dictation_page.dart';
import 'pages/wrong_words_page.dart';
import 'pages/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 全局服务注册 ─────────────────────────────────────────
  Get.put(ApiService());          // HTTP API
  Get.put(AudioService());        // TTS + 音效

  // 本地 DB（Web 兼容 try-catch）
  try {
    await LocalDbService.instance.init();
    Get.put(LocalDbService.instance);
  } catch (e) {
    debugPrint('[main] LocalDbService init failed (web?): $e');
  }

  // 语音助手（最后注册，依赖以上服务）
  Get.put(VoiceAssistant());

  runApp(const WordsDictationApp());
}

class WordsDictationApp extends StatelessWidget {
  const WordsDictationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '单词听写',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const MainNavPage()),
        GetPage(name: '/dictation', page: () => const DictationPage()),
        GetPage(name: '/wrong-words', page: () => const WrongWordsPage()),
        GetPage(name: '/profile', page: () => const ProfilePage()),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 主导航（底部 Tab Bar）
// ─────────────────────────────────────────────────────────────────────────────
class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  int _currentIndex = 0;

  final _pages = const [
    HomePage(),
    WrongWordsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Obx(() => BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: AppTheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '错词本'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      )),
    );
  }
}
