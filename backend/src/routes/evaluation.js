const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const { evaluatePronunciation } = require('../ai');
const { recordWordResult, queryOne } = require('../models');

// ── 拼写评测（本地计算，无需 API）────────────────────────────

/**
 * POST /api/v1/evaluation/spelling
 * 拼写评测（基于 Levenshtein 编辑距离）
 */
router.post('/spelling', auth, async (req, res, next) => {
  try {
    const { taskId, wordId, userInput } = req.body;
    if (!wordId || userInput === undefined) {
      return res.status(400).json({ code: 'ERR_INVALID_INPUT', message: '参数不完整' });
    }

    // 查找单词（从 task_words 关联）
    const { query } = require('../config/database');
    const taskWordRows = await query(
      `SELECT tw.id AS task_word_id, w.word, w.phonetic, w.meaning
       FROM task_words tw
       JOIN words w ON tw.word_id = w.id
       WHERE tw.task_id = ? AND tw.word_id = ?`,
      [taskId, wordId]
    );

    if (!taskWordRows.length) {
      return res.status(404).json({ code: 'ERR_WORD_NOT_FOUND', message: '单词不存在' });
    }

    const { task_word_id, word, phonetic, meaning } = taskWordRows[0];
    const result = _evaluateSpelling(word, (userInput || '').trim().toLowerCase());

    // 保存评测结果
    if (task_word_id) {
      await query(
        `UPDATE task_words 
         SET spelling_input = ?, spelling_score = ?, is_correct = ?, evaluated_at = NOW()
         WHERE id = ?`,
        [userInput, result.score, result.isCorrect, task_word_id]
      );
    }

    res.json({
      wordId,
      word,
      phonetic,
      meaning,
      spellingScore: result.score,
      isCorrect: result.isCorrect,
      feedback: result.feedback,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/evaluation/pronunciation
 * 发音评测（调用讯飞 API，开发阶段模拟）
 */
router.post('/pronunciation', auth, async (req, res, next) => {
  try {
    const { taskId, wordId, audio_base64 } = req.body;
    if (!wordId || !audio_base64) {
      return res.status(400).json({ code: 'ERR_INVALID_INPUT', message: '参数不完整' });
    }

    const { query } = require('../config/database');
    const rows = await query(
      `SELECT tw.id AS task_word_id, w.word, w.phonetic
       FROM task_words tw
       JOIN words w ON tw.word_id = w.id
       WHERE tw.task_id = ? AND tw.word_id = ?`,
      [taskId, wordId]
    );

    if (!rows.length) {
      return res.status(404).json({ code: 'ERR_WORD_NOT_FOUND', message: '单词不存在' });
    }

    const { task_word_id, word, phonetic } = rows[0];

    // 调用 AI 发音评测（TODO: 真实接入讯飞）
    const evalResult = await evaluatePronunciation(word, audio_base64);

    // 更新 task_words 中的发音分
    await query(
      `UPDATE task_words SET pronunciation_score = ? WHERE id = ?`,
      [evalResult.score, task_word_id]
    );

    res.json({
      wordId,
      word,
      phonetic,
      pronunciationScore: evalResult.score,
      integrity: evalResult.integrity,
      fluency: evalResult.fluency,
      accuracy: evalResult.accuracy,
      phonemeDetails: evalResult.details || [],
      feedback: _pronunciationFeedback(evalResult.score),
      isMock: evalResult.isMock || false,
    });
  } catch (err) {
    next(err);
  }
});

// ── 内部工具函数 ──────────────────────────────────────────

/**
 * 拼写评测：Levenshtein 编辑距离
 */
function _evaluateSpelling(standard, input) {
  const std = standard.toLowerCase().trim();
  const usr = input.toLowerCase().trim();

  if (std === usr) {
    return { score: 100, isCorrect: true, feedback: '完全正确！太棒了 🎉' };
  }

  const dist = _levenshtein(std, usr);
  const maxLen = Math.max(std.length, usr.length);
  const score = Math.max(0, Math.round(100 - (dist / maxLen) * 100));
  const isCorrect = score >= 90;

  let feedback;
  if (score >= 80) {
    feedback = `拼写基本正确，注意细节 👍。正确：${standard}`;
  } else if (score >= 60) {
    feedback = `加油！正确答案是 ${standard}`;
  } else {
    feedback = `多练练，正确答案是 ${standard}`;
  }

  return { score, isCorrect, feedback };
}

function _levenshtein(a, b) {
  const m = a.length, n = b.length;
  const dp = Array.from({ length: m + 1 }, (_, i) =>
    Array.from({ length: n + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0))
  );
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] = a[i - 1] === b[j - 1]
        ? dp[i - 1][j - 1]
        : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
    }
  }
  return dp[m][n];
}

function _pronunciationFeedback(score) {
  if (score >= 90) return '发音非常棒！🌟';
  if (score >= 80) return '发音不错，继续加油！👍';
  if (score >= 60) return '发音基本正确，多练练更完美 💪';
  return '发音需要改进，跟着音标多模仿 📚';
}

module.exports = router;
