const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { createUser, findUserById, updateUser } = require('../models');
const { signToken, auth } = require('../middleware/auth');

/**
 * POST /api/v1/user/register-guest
 * 游客快速注册（无需手机号）
 */
router.post('/register-guest', async (req, res, next) => {
  try {
    const { nickname = '小学生', grade = 1 } = req.body;
    const user = await createUser({ nickname, grade });
    const token = signToken({ userId: user.id, nickname: user.nickname, is_premium: user.is_premium || false });

    res.status(201).json({
      user: formatUser(user),
      token,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/user/profile
 * 获取用户信息
 */
router.get('/profile', auth, async (req, res, next) => {
  try {
    const user = await findUserById(req.user.userId);
    if (!user) {
      return res.status(404).json({ code: 'ERR_USER_NOT_FOUND', message: '用户不存在' });
    }
    res.json({ user: formatUser(user) });
  } catch (err) {
    next(err);
  }
});

/**
 * PUT /api/v1/user/profile
 * 更新用户信息
 */
router.put('/profile', auth, async (req, res, next) => {
  try {
    const { nickname, grade, avatar_url } = req.body;
    const user = await updateUser(req.user.userId, { nickname, grade, avatar_url });
    res.json({ user: formatUser(user) });
  } catch (err) {
    next(err);
  }
});

function formatUser(u) {
  return {
    userId: u.id,
    nickname: u.nickname,
    avatarUrl: u.avatar_url,
    grade: u.grade,
    totalScore: u.total_score,
    currentStreak: u.current_streak ?? u.streak_days ?? 0,
    // Fix: 添加 is_premium 字段，前端依赖此字段判断用户类型
    // Phase 2: 产品分层时再做校验逻辑
    is_premium: u.is_premium || false,
    createdAt: u.created_at,
  };
}

module.exports = router;
