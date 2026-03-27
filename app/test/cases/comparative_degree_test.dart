/// 比较级绘本测试用例
/// 目标用户：8岁小女生
/// 单词：beautiful → more beautiful（比较级）
///
/// 运行方式（Flutter 设备/模拟器）：
///   cd app && flutter test test/cases/comparative_degree_test.dart
///   或在设备上直接启动 PictureBookPage 并传入以下参数

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:words_dictation_v2/pages/picture_book_page.dart';

/// ─────────────────────────────────────────────────────────────────
/// 绘本内容设计
/// ─────────────────────────────────────────────────────────────────
///
/// 单词：beautiful（美丽的）
// 基础级：beautiful   比较级：more beautiful   最高级：most beautiful
//
// 故事线：Lily（一个小女孩）去花园，发现不同的花都很漂亮，
//         她发现"这朵比那朵更美"，自然引出比较级概念。

const Map<String, dynamic> kComparativeDegreeBook = {
  // ── 基础信息 ──────────────────────────────────────────────────
  'wordId': 'word_beautiful_001',
  'word': 'beautiful',
  'phonetic': '/ˈbjuːtɪfl/',
  'meaning': '美丽的，漂亮的',

  // ── 绘本讲解（每句一段配音 + 一张卡通图）─────────────────────────
  // 面向8岁女生：Lily主角，花园场景，色彩鲜艳，童趣盎然
  'explanation':
    'One day, a cute girl named Lily went to a beautiful garden. '
    'She saw many pretty flowers. "This flower is beautiful!" said Lily. '
    'Then she saw a bigger red rose. "Oh! This one is MORE BEAUTIFUL than that one!" '
    '"Beautiful" is an adjective. When we compare two things, we can say "more beautiful". '
    'That\'s the comparative form! Lily learned something new today!',

  // ── API 调用（后端需启动在 localhost:3001）─────────────────────
  // POST /api/v1/picturebook/generate
  // Body:
  'apiPayload': {
    'wordId': 'word_beautiful_001',
    'word': 'beautiful',
    'explanation':
      'One day, a cute girl named Lily went to a beautiful garden. '
      'She saw many pretty flowers. "This flower is beautiful!" said Lily. '
      'Then she saw a bigger red rose. "Oh! This one is MORE BEAUTIFUL than that one!" '
      '"Beautiful" is an adjective. When we compare two things, we say "more beautiful". '
      'That\'s the comparative form! Lily learned something new today!',
    'async': false,  // 同步生成（测试用）
  },

  // ── MiniMax 图片生成提示词（卡通绘本风格）─────────────────────
  'imagePrompts': [
    // Frame 1: Lily出场 + 花园全景
    'A children\'s cartoon picture book illustration, child-friendly, vivid colors. '
    'A cute 8-year-old girl named Lily with long curly hair standing in a beautiful sunny garden full of colorful flowers. '
    'The word "BEAUTIFUL" displayed in bold pink bubble letters at the bottom. '
    'Bright cheerful background with butterflies and sunshine. No extra text.',

    // Frame 2: Lily看到一朵花
    'A children\'s cartoon picture book illustration, child-friendly, vivid colors. '
    'Lily pointing excitedly at a pretty pink flower with a big smile. '
    'She says "This flower is BEAUTIFUL!" '
    'Speech bubble: "This flower is beautiful!" '
    'Bright garden background, butterflies. No extra text.',

    // Frame 3: Lily发现更美的玫瑰
    'A children\'s cartoon picture book illustration, child-friendly, vivid colors. '
    'Lily looking amazed at a big beautiful red rose, eyes wide with wonder. '
    'Speech bubble: "Oh! This one is MORE BEAUTIFUL than that one!" '
    'A comparison showing the pink flower and the red rose side by side. '
    'Sparkles around the red rose. No extra text.',

    // Frame 4: 语法讲解（图文对照）
    'A children\'s cartoon picture book illustration, child-friendly, vivid colors. '
    'Lily\'s diary open with cute handwriting, showing the grammar pattern. '
    'Left page: "beautiful ✗" with a cute sad face. '
    'Right page: "MORE BEAUTIFUL ✓" with sparkles and stars. '
    'A cute cartoon owl teacher pointing at the book. '
    'Pink and purple color scheme. No extra text.',

    // Frame 5: 总结 + 鼓励
    'A children\'s cartoon picture book illustration, child-friendly, vivid colors. '
    'Lily giving a big thumbs up with a huge happy smile, standing in the garden. '
    'Behind her: all the flowers are blooming and colorful. '
    'Speech bubble: "I can use MORE BEAUTIFUL now! I\'m so smart!" '
    'Rainbow in the sky, confetti, happy butterflies. No extra text.',
  ],

  // ── MiniMax TTS 配音脚本 ───────────────────────────────────────
  // speed: 0.8（比成人慢，适合8岁儿童）
  // language: en-US
  'audioScripts': [
    'Hi! I\'m Lily. Today we\'re learning a wonderful word. Let\'s say it together: beautiful!',
    'Look at this flower. It is SO beautiful! Say it with me: beautiful!',
    'Oh wow! This red rose is even prettier! We say: This rose is MORE BEAUTIFUL than that one!',
    'So when we compare two things, beautiful becomes MORE BEAUTIFUL. '
    'Let\'s remember: beautiful → more beautiful! Great job!',
    'Amazing! You\'re so smart! Now you know how to use more beautiful! Great job, superstar!',
  ],

  // ── 评测用例 ──────────────────────────────────────────────────
  'quiz': [
    {
      'question': '"这朵花比那朵更漂亮" 用英语怎么说？',
      'options': ['This flower is beautiful.', 'This flower is more beautiful than that one.', 'The flower is bigger.'],
      'correct': 1,
    },
    {
      'question': '"beautiful" 的比较级是什么？',
      'options': ['beautifuller', 'more beautiful', 'most beautiful'],
      'correct': 1,
    },
  ],
};

// ─────────────────────────────────────────────────────────────────
/// Flutter Widget 测试
// ─────────────────────────────────────────────────────────────────
void main() {
  testWidgets('Comparative degree picture book loads correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PictureBookPage(
          wordId: kComparativeDegreeBook['wordId'] as String,
          word: kComparativeDegreeBook['word'] as String,
          explanation: kComparativeDegreeBook['explanation'] as String,
        ),
      ),
    );

    // 验证页面标题显示单词
    expect(find.text('beautiful'), findsOneWidget);
  });
}
