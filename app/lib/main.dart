/// Words Dictation v2 - 主入口
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'services/api_service.dart';
import 'pages/picture_book_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 API 服务
  await ApiService().init();
  
  runApp(const WordsDictationApp());
}

class WordsDictationApp extends StatelessWidget {
  const WordsDictationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '单词听写',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4ECDC4),
          background: const Color(0xFFFFF9F0),
        ),
        fontFamily: 'Rounded',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4ECDC4),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: const _DevHomePage(), // 开发入口，正式版替换为主导航页
      getPages: [
        GetPage(
          name: '/picturebook',
          page: () {
            final args = Get.arguments as Map<String, dynamic>? ?? {};
            return PictureBookPage(
              wordId: args['wordId'] ?? 'test_word_id',
              word: args['word'] ?? 'apple',
              explanation: args['explanation'],
              existingBookId: args['bookId'],
            );
          },
        ),
      ],
    );
  }
}

/// 开发测试主页（快速验证绘本功能）
class _DevHomePage extends StatelessWidget {
  const _DevHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final words = [
      {'wordId': 'w001', 'word': 'apple', 'explanation': 'An apple is a round red or green fruit. It grows on trees. The word apple starts with the letter A.'},
      {'wordId': 'w002', 'word': 'elephant', 'explanation': 'An elephant is a very big animal. It has a long trunk and big ears. Elephants are grey and friendly.'},
      {'wordId': 'w003', 'word': 'butterfly', 'explanation': 'A butterfly is a beautiful insect with colorful wings. It starts life as a caterpillar.'},
      {'wordId': 'w004', 'word': 'garden', 'explanation': 'A garden is a place where flowers and vegetables grow. People enjoy spending time in gardens.'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        title: const Text('📚 Words Dictation v2'),
        backgroundColor: const Color(0xFF4ECDC4),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '🎯 Phase 1: 动态绘本演示',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '点击任意单词，体验 AI 动态绘本',
              style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          ...words.map((w) => _WordCard(
            wordId: w['wordId']!,
            word: w['word']!,
            explanation: w['explanation']!,
          )).toList(),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final String wordId;
  final String word;
  final String explanation;

  const _WordCard({
    required this.wordId,
    required this.word,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: const Color(0xFF4ECDC4).withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => Get.toNamed('/picturebook', arguments: {
          'wordId': wordId,
          'word': word,
          'explanation': explanation,
        }),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('📖', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7F8C8D),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF4ECDC4), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
