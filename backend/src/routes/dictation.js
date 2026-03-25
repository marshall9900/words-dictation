const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const {
  createDictationTask, getTask, updateTaskStatus,
  getWordsByGrade, getWordsByIds, searchWords, completeTask,
  upsertWrongWord, addLearningRecord, addScore, unlockAchievement,
} = require('../models');
const { ocrExtractWords } = require('../ai');

/**
 * POST /api/v1/dictation/scan
 * 拍照识别作业，生成听写任务
 */
router.post('/scan', auth, async (req, res, next) => {
  try {
    const { image_base64, grade } = req.body;
    if (!image_base64) {
      return res.status(400).json({ code: 'ERR_INVALID_INPUT', message: '缺少图片数据' });
    }

    // Step 1: OCR 识别单词
    const extractedWords = await ocrExtractWords(image_base64);

    // Step 2: 词库匹配
    const matchedWords = await searchWords(extractedWords);

    // 如果 OCR 没匹配到词，使用年级词库补充
    let finalWords = matchedWords;
    if (finalWords.length === 0) {
      const userGrade = grade || req.user.grade || 1;
      finalWords = await getWordsByGrade(userGrade, 10);
    }

    // Step 3: 创建听写任务（最多 10 个词）
    const selectedWords = finalWords.slice(0, 10);
    const task = await createDictationTask({
      userId: req.user.userId,
      words: selectedWords,
      source: 'photo',
    });

    res.status(201).json(formatTask(task));
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/dictation/task
 * 手动创建听写任务
 */
router.post('/task', auth, async (req, res, next) => {
  try {
    const { wordIds, count = 10, grade } = req.body;

    let words;
    if (wordIds && wordIds.length > 0) {
      words = await getWordsByIds(wordIds);
    } else {
      const g = grade || req.user.grade || 1;
      words = await getWordsByGrade(g, count);
    }

    if (words.length === 0) {
      return res.status(404).json({ code: 'ERR_WORD_NOT_FOUND', message: '未找到单词' });
    }

    const task = await createDictationTask({
      userId: req.user.userId,
      words: words.slice(0, count),
      source: 'manual',
    });

    res.status(201).json(formatTask(task));
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/dictation/task/:taskId
 * 获取任务详情
 */
router.get('/task/:taskId', auth, async (req, res, next) => {
  try {
    const task = await getTask(req.params.taskId);
    if (!task || task.user_id !== req.user.userId) {
      return res.status(404).json({ code: 'ERR_TASK_NOT_FOUND', message: '任务不存在' });
    }
    res.json(formatTask(task));
  } catch (err) {
    next(err);
  }
});

/**
 * PUT /api/v1/dictation/task/:taskId/start
 * 开始任务
 */
router.put('/task/:taskId/start', auth, async (req, res, next) => {
  try {
    await updateTaskStatus(req.params.taskId, 'in_progress');
    res.json({ status: 'in_progress', startedAt: new Date() });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/dictation/task/:taskId/complete
 * 完成任务，生成打卡报告
 */
router.post('/task/:taskId/complete', auth, async (req, res, next) => {
  try {
    const { taskId } = req.params;
    const userId = req.user.userId;

    const task = await completeTask(taskId);
    if (!task) {
      return res.status(404).json({ code: 'ERR_TASK_NOT_FOUND', message: '任务不存在' });
    }

    // 给用户加分
    await addScore(userId, task.score || 0);

    // 记录学习历史 & 错词本
    const wrongWords = [];
    for (const tw of task.words || []) {
      await addLearningRecord({
        userId,
        wordId: tw.word_id,
        taskId,
        actionType: tw.is_correct ? 'correct' : 'wrong',
        spellingScore: tw.spelling_score,
        pronunciationScore: tw.pronunciation_score,
      });

      if (!tw.is_correct) {
        await upsertWrongWord(userId, tw.word_id);
        wrongWords.push({ word: tw.word, phonetic: tw.phonetic, meaning: tw.meaning });
      }
    }

    // 检查成就
    const newAchievements = [];
    if (task.correct_count === task.total_words && task.total_words > 0) {
      const a = await unlockAchievement(userId, 'perfect_round');
      if (a) newAchievements.push(a.name);
    }

    const correctRate = task.total_words > 0
      ? task.correct_count / task.total_words
      : 0;

    res.json({
      report: {
        totalWords: task.total_words,
        correctCount: task.correct_count,
        correctRate,
        duration: 0, // TODO: 计算实际时长
        score: task.score,
        wrongWords,
        achievements: newAchievements,
      },
    });
  } catch (err) {
    next(err);
  }
});

function formatTask(task) {
  return {
    taskId: task.id,
    userId: task.user_id,
    source: task.source,
    status: task.status,
    totalWords: task.total_words,
    correctCount: task.correct_count,
    score: task.score,
    words: (task.words || []).map(w => ({
      taskWordId: w.id,
      wordId: w.word_id || w.id,
      word: w.word,
      phonetic: w.phonetic,
      meaning: w.meaning,
      audioUrl: w.audio_url,
      grade: w.grade,
      difficulty: w.difficulty,
      orderIndex: w.order_index,
    })),
    createdAt: task.created_at,
  };
}

module.exports = router;
