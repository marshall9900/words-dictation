const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const { getAchievements, unlockAchievement } = require('../models');
const { query } = require('../config/database');

/**
 * GET /api/v1/achievement
 * 获取成就列表
 */
router.get('/', auth, async (req, res, next) => {
  try {
    const result = await getAchievements(req.user.userId);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/leaderboard
 * 积分排行榜
 */
router.get('/leaderboard', auth, async (req, res, next) => {
  try {
    const { type = 'weekly', limit = 20 } = req.query;

    const rankings = await query(
      `SELECT id, nickname, avatar_url, total_score
       FROM users
       ORDER BY total_score DESC
       LIMIT ?`,
      [Number(limit)]
    );

    const myRankRows = await query(
      `SELECT COUNT(*) + 1 AS rank
       FROM users
       WHERE total_score > (SELECT total_score FROM users WHERE id = ?)`,
      [req.user.userId]
    );

    res.json({
      rankings: rankings.map((u, i) => ({
        userId: u.id,
        nickname: u.nickname,
        avatar: u.avatar_url,
        score: u.total_score,
        rank: i + 1,
      })),
      myRank: myRankRows[0]?.rank || 1,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
