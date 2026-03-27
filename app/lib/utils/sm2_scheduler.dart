import '../models/models.dart';

/// SM-2 艾宾浩斯间隔重复算法调度器
/// 参考: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
class SM2Scheduler {
  /// 根据答题质量更新复习进度
  /// [quality]: 0-5 的评分（0=完全忘记, 5=完全记住）
  WrongWord updateSchedule(WrongWord word, {required int quality}) {
    // TODO: 实现 SM-2 算法
    // 1. 计算新的易度因子 EF' = EF + (0.1 - (5-q)(0.08 + (5-q)*0.02))
    // 2. 计算新的间隔天数：
    //    - n=1: 1天
    //    - n=2: 6天
    //    - n>2: interval * EF
    // 3. 如果质量 < 3，重置重复次数

    double newEasiness = word.sm2Easiness + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    newEasiness = newEasiness.clamp(1.3, double.infinity);

    int newRepetition;
    int newInterval;

    if (quality < 3) {
      newRepetition = 0;
      newInterval = 1;
    } else {
      newRepetition = word.sm2RepetitionCount + 1;
      if (newRepetition == 1) {
        newInterval = 1;
      } else if (newRepetition == 2) {
        newInterval = 6;
      } else {
        newInterval = (word.sm2IntervalDays * newEasiness).round();
      }
    }

    final nextReview = DateTime.now().add(Duration(days: newInterval));

    return word.copyWith(
      nextReviewAt: nextReview,
      sm2RepetitionCount: newRepetition,
      sm2Easiness: newEasiness,
      sm2IntervalDays: newInterval,
    );
  }

  /// 判断是否需要今日复习
  /// 条件：nextReviewAt 为 null（从未复习）或者已到复习时间
  bool isDueToday(WrongWord word) {
    if (word.nextReviewAt == null) return true;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return word.nextReviewAt!.isBefore(endOfToday) ||
           word.nextReviewAt!.isAtSameMomentAs(endOfToday) ||
           word.nextReviewAt!.isBefore(now);
  }

  /// 从错词列表中筛选今日需复习的单词
  List<WrongWord> filterDueWords(List<WrongWord> words) {
    return words.where(isDueToday).toList();
  }
}
