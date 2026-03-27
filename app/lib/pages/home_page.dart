import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/local_db_service.dart';
import '../core/theme.dart';

class HomeController extends GetxController {
  final _api = Get.find<ApiService>();
  final _db = Get.find<LocalDbService>();

  final todayDueCount = 0.obs;
  final totalWrongCount = 0.obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadStats();
  }

  Future<void> _loadStats() async {
    isLoading.value = true;
    try {
      final words = await _db.getWrongWords();
      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      todayDueCount.value = words.where((w) =>
        w.nextReviewAt == null || w.nextReviewAt!.isBefore(endOfToday)
      ).length;
      totalWrongCount.value = words.length;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> startDictation() async {
    final task = await _api.createTask(count: 10);
    if (task != null) {
      Get.toNamed('/dictation', arguments: task);
    } else {
      Get.snackbar('小Wo', '创建任务失败，请检查网络', duration: const Duration(seconds: 3));
    }
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primary, Color(0xFF9C8FFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('你好，宝贝！👋',
                            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('今天也要加油哦～',
                            style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                    const Spacer(),
                    Obx(() => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.mic, color: Colors.white, size: 28),
                          Text(
                            controller.todayDueCount.value > 0
                                ? '${controller.todayDueCount.value}个待复习'
                                : '小Wo在线',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

              // 主内容卡片
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // 快速开始听写
                        _ActionCard(
                          icon: '🎧',
                          title: '开始听写',
                          subtitle: '10个随机单词',
                          color: AppTheme.primary,
                          onTap: controller.startDictation,
                        ),
                        const SizedBox(height: 16),

                        // 今日待复习
                        Obx(() => _ActionCard(
                          icon: '📚',
                          title: '今日待复习',
                          subtitle: controller.todayDueCount.value > 0
                              ? '${controller.todayDueCount.value}个错词等着你'
                              : '太棒了，今天没有待复习！',
                          color: controller.todayDueCount.value > 0
                              ? AppTheme.warning
                              : AppTheme.success,
                          onTap: () => Get.toNamed('/wrong-words'),
                        )),
                        const SizedBox(height: 16),

                        // 总错词统计
                        Obx(() => _ActionCard(
                          icon: '📝',
                          title: '错词本',
                          subtitle: '共 ${controller.totalWrongCount.value} 个错词',
                          color: AppTheme.secondary,
                          onTap: () => Get.toNamed('/wrong-words'),
                        )),

                        const Spacer(),

                        // 小Wo状态指示
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const _BreathingDot(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('小Wo同学 在线',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('喊"小助手"即可唤醒语音助手',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreathingDot extends StatefulWidget {
  const _BreathingDot();
  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
    _ac.repeat(reverse: true);
  }
  @override
  void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 14, height: 14,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.success),
        ),
      ),
    );
  }
}
