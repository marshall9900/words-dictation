import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/models.dart';
import '../services/local_db_service.dart';
import '../services/audio_service.dart';
import '../core/theme.dart';

/// 错词本 Controller
class WrongWordsController extends GetxController {
  final _db = Get.find<LocalDbService>();
  final _audio = Get.find<AudioService>();

  final allWords = <WrongWord>[].obs;
  final todayWords = <WrongWord>[].obs;
  final futureWords = <WrongWord>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadWords();
  }

  Future<void> loadWords() async {
    isLoading.value = true;
    try {
      final all = await _db.getWrongWords();
      allWords.value = all;
      todayWords.value = all.where(_isDueToday).toList();
      futureWords.value = all.where((w) => !_isDueToday(w) && !(w.mastered)).toList();
    } finally {
      isLoading.value = false;
    }
  }

  bool _isDueToday(WrongWord w) {
    if (w.nextReviewAt == null) return true;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return w.nextReviewAt!.isBefore(endOfToday) || w.nextReviewAt!.isBefore(now);
  }

  /// 播放单词发音
  Future<void> playWord(WrongWord w) async {
    await _audio.speakWord(w.word.word);
  }

  /// 删除已掌握的词
  Future<void> markAsMastered(String wordId) async {
    final w = allWords.firstWhere((x) => x.wordId == wordId);
    final updated = w.copyWith(mastered: true, nextReviewAt: null);
    await _db.updateWrongWord(updated);
    await loadWords();
  }

  /// 发起一轮复习听写（只包含今日待复习词）
  void startReview() {
    if (todayWords.isEmpty) {
      Get.snackbar('小Wo', '今日没有待复习的词啦！', duration: const Duration(seconds: 2));
      return;
    }
    final task = DictationTask(
      taskId: 'review_${DateTime.now().millisecondsSinceEpoch}',
      words: todayWords.map((w) => w.word).toList(),
      createdAt: DateTime.now(),
    );
    Get.toNamed('/dictation', arguments: task);
  }
}

/// 错词本页面
class WrongWordsPage extends StatelessWidget {
  const WrongWordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(WrongWordsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('错词本'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadWords,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = controller.allWords;
        if (all.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text('太棒了！没有错词！',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('继续保持～', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadWords,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 今日待复习
              if (controller.todayWords.isNotEmpty) ...[
                _SectionHeader(
                  title: '📚 今日待复习',
                  count: controller.todayWords.length,
                  color: AppTheme.warning,
                ),
                ...controller.todayWords.map((w) => _WrongWordTile(w, controller)),
                const SizedBox(height: 24),
              ],

              // 未来复习
              if (controller.futureWords.isNotEmpty) ...[
                _SectionHeader(
                  title: '📅 稍后复习',
                  count: controller.futureWords.length,
                  color: AppTheme.primary,
                ),
                ...controller.futureWords.map((w) => _WrongWordTile(w, controller)),
                const SizedBox(height: 24),
              ],

              // 一键复习按钮
              if (controller.todayWords.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: controller.startReview,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('开始复习 (${controller.todayWords.length}个)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              // 统计
              _StatsCard(controller),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _WrongWordTile extends StatelessWidget {
  final WrongWord w;
  final WrongWordsController c;
  const _WrongWordTile(this.w, this.c);

  String _nextReviewLabel(WrongWord w) {
    if (w.nextReviewAt == null) return '待复习';
    final diff = w.nextReviewAt!.difference(DateTime.now());
    if (diff.isNegative) return '今日';
    if (diff.inDays == 0) return '今天';
    if (diff.inDays == 1) return '明天';
    return '${diff.inDays}天后';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => c.playWord(w),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 发音按钮
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.volume_up, color: AppTheme.primary),
                  onPressed: () => c.playWord(w),
                ),
              ),
              const SizedBox(width: 12),
              // 单词信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.word.word,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(w.word.phonetic ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(w.word.meaning,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // 复习信息
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('错${w.wrongCount}次',
                        style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Text(_nextReviewLabel(w),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (w.mastered)
                    const Text('✓ 已掌握', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                ],
              ),
              // 标为已掌握
              if (!w.mastered)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                  onPressed: () => c.markAsMastered(w.wordId),
                  tooltip: '标记为已掌握',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final WrongWordsController c;
  const _StatsCard(this.c);

  @override
  Widget build(BuildContext context) {
    final total = c.allWords.length;
    final mastered = c.allWords.where((w) => w.mastered).length;
    final dueToday = c.todayWords.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 学习统计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: '总错词', value: '$total', color: AppTheme.primary),
              _StatItem(label: '今日待复习', value: '$dueToday', color: AppTheme.warning),
              _StatItem(label: '已掌握', value: '$mastered', color: AppTheme.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}
