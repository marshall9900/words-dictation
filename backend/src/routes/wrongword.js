const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const { getWrongWords, markWrongWordMastered, deleteWrongWord } = require('../models');

/**
 * GET /api/v1/wrongword
 * 获取错词本列表
 */
router.get('/', auth, async (req, res, next) => {
  try {
    const { status = 'all', page = 1, pageSize = 20 } = req.query;
    const result = await getWrongWords(req.user.userId, {
      status,
      page: Number(page),
      pageSize: Number(pageSize),
    });

    // 计算 due count
    const dueCount = result.items.filter(w => {
      const next = w.next_review_at ? new Date(w.next_review_at) : null;
      return !next || next <= new Date();
    }).length;

    res.json({
      items: result.items.map(formatWrongWord),
      total: result.total,
      dueCount,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/v1/wrongword/:wordId/mastered
 * 标记为已掌握
 */
router.post('/:wordId/mastered', auth, async (req, res, next) => {
  try {
    await markWrongWordMastered(req.user.userId, req.params.wordId);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /api/v1/wrongword/:wordId
 * 移除错词
 */
router.delete('/:wordId', auth, async (req, res, next) => {
  try {
    await deleteWrongWord(req.user.userId, req.params.wordId);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
});

function formatWrongWord(w) {
  return {
    wordId: w.word_id,
    word: w.word,
    phonetic: w.phonetic,
    meaning: w.meaning,
    wrongCount: w.wrong_count,
    lastWrongAt: w.last_wrong_at,
    mastered: w.mastered,
    videoUrl: w.video_url,
    nextReviewAt: w.next_review_at,
  };
}

module.exports = router;
