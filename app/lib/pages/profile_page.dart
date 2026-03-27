import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/local_db_service.dart';
import '../core/theme.dart';

class ProfileController extends GetxController {
  final _db = Get.find<LocalDbService>();
  final totalWords = 0.obs;
  final masteredWords = 0.obs;
  final totalPractice = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final words = await _db.getWrongWords();
    masteredWords.value = words.where((w) => w.mastered).length;
    totalWords.value = words.length;
    totalPractice.value = words.fold(0, (sum, w) => sum + w.wrongCount);
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('我的'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 头像区
          Center(
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.child_care, size: 48, color: AppTheme.primary),
                ),
                const SizedBox(height: 12),
                const Text('小学生', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Text('8岁 · 小学二年级', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 学习统计
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📊 学习统计', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatTile('🎯', '${controller.totalPractice}', '练习次数'),
                    _StatTile('📝', '${controller.totalWords}', '总错词'),
                    _StatTile('✅', '${controller.masteredWords}', '已掌握'),
                  ],
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 设置区
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.volume_up,
                  title: '语音设置',
                  subtitle: 'TTS语速: 0.4x (儿童慢速)',
                  onTap: () => Get.snackbar('小Wo', '语音设置即将开放', duration: const Duration(seconds: 2)),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.mic,
                  title: '唤醒词',
                  subtitle: '"小助手"（暂不支持自定义）',
                  onTap: () => Get.snackbar('小Wo', '自定义唤醒词 Phase 2 支持', duration: const Duration(seconds: 2)),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: '关于',
                  subtitle: 'Words Dictation v2.0',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 版本信息
          const Center(
            child: Text('Words Dictation v2.0 · Phase 1',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  const _StatTile(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
