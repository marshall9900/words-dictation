/**
 * 动态绘本 API 路由
 * 
 * POST   /api/v1/picturebook/generate       - 生成动态绘本
 * GET    /api/v1/picturebook/:id             - 获取绘本详情（含时间轴）
 * GET    /api/v1/picturebook/:id/audio       - 获取配音音频列表
 * GET    /api/v1/picturebook/:id/frames      - 获取图片帧列表
 * GET    /api/v1/picturebook/word/:wordId    - 按单词获取绘本（复用缓存）
 * GET    /api/v1/picturebook/job/:jobId      - 查询生成任务状态
 */

const express = require('express');
const Joi = require('joi');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();

const { auth } = require('../middleware/auth');
const { generatePictureBook, getPictureBookById, getLatestPictureBookByWord } = require('../services/picturebook');
const { enqueueGeneration, getJobStatus } = require('../queue/picturebook');
const db = require('../db');
const redis = require('../config/redis');

// ── 输入验证 ────────────────────────────────────────────────

const generateSchema = Joi.object({
  wordId: Joi.string().required(),
  word: Joi.string().min(1).max(100).required(),
  explanation: Joi.string().max(2000).optional().allow(''),
  async: Joi.boolean().default(true), // true=队列异步，false=同步等待
});

// ── 路由实现 ────────────────────────────────────────────────

/**
 * POST /api/v1/picturebook/generate
 * 生成动态绘本（免费功能）
 */
router.post('/generate', auth, async (req, res) => {
  const { error, value } = generateSchema.validate(req.body);
  if (error) return res.status(400).json({ success: false, error: error.message });

  const { wordId, word, explanation, async: isAsync } = value;
  const userId = req.user.id;

  try {
    // 检查缓存（同一单词 24h 内不重复生成）
    const cacheKey = `picturebook:word:${wordId}`;
    const cached = await redis.get(cacheKey);
    if (cached) {
      const cachedData = JSON.parse(cached);
      return res.json({
        success: true,
        data: cachedData,
        cached: true,
      });
    }

    // 检查 DB 中是否已有该单词的绘本
    const existing = await getLatestPictureBookByWord(wordId);
    if (existing && existing.status === 'active') {
      // 缓存并返回
      await redis.setex(cacheKey, parseInt(process.env.PICTUREBOOK_CACHE_TTL || '86400'), JSON.stringify(existing));
      return res.json({ success: true, data: existing, cached: true });
    }

    if (isAsync) {
      // 异步模式：放入队列
      const job = await enqueueGeneration({
        wordId,
        word,
        explanation,
        userId,
        seed: Math.floor(Math.random() * 999999) + 1,
      });

      return res.status(202).json({
        success: true,
        jobId: job.id,
        message: 'PictureBook generation queued',
        statusUrl: `/api/v1/picturebook/job/${job.id}`,
      });
    } else {
      // 同步模式：直接生成（适合开发测试，小用户量）
      const result = await generatePictureBook({
        wordId,
        word,
        explanation,
        userId,
        seed: Math.floor(Math.random() * 999999) + 1,
      });

      // 缓存结果
      await redis.setex(cacheKey, parseInt(process.env.PICTUREBOOK_CACHE_TTL || '86400'), JSON.stringify(result));

      return res.json({ success: true, data: result });
    }
  } catch (err) {
    console.error('[PictureBook Route] generate error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/picturebook/job/:jobId
 * 查询异步生成任务状态
 */
router.get('/job/:jobId', auth, async (req, res) => {
  try {
    const status = await getJobStatus(req.params.jobId);
    if (!status) return res.status(404).json({ success: false, error: 'Job not found' });
    res.json({ success: true, data: status });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/picturebook/word/:wordId
 * 按单词 ID 获取最新绘本
 */
router.get('/word/:wordId', auth, async (req, res) => {
  try {
    const cacheKey = `picturebook:word:${req.params.wordId}`;
    const cached = await redis.get(cacheKey);
    if (cached) {
      return res.json({ success: true, data: JSON.parse(cached), cached: true });
    }

    const book = await getLatestPictureBookByWord(req.params.wordId);
    if (!book) return res.status(404).json({ success: false, error: 'PictureBook not found' });

    await redis.setex(cacheKey, 86400, JSON.stringify(book));
    res.json({ success: true, data: book });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/picturebook/:id
 * 获取绘本详情（含时间轴）
 */
router.get('/:id', auth, async (req, res) => {
  try {
    const book = await getPictureBookById(req.params.id);
    if (!book) return res.status(404).json({ success: false, error: 'PictureBook not found' });
    res.json({ success: true, data: book });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/picturebook/:id/frames
 * 获取图片帧列表（从时间轴中提取）
 */
router.get('/:id/frames', auth, async (req, res) => {
  try {
    const book = await getPictureBookById(req.params.id);
    if (!book) return res.status(404).json({ success: false, error: 'PictureBook not found' });

    const frames = (book.timeline?.frames || []).map(f => ({
      index: f.index,
      image: f.image,
      durationMs: f.durationMs,
      text: f.text,
    }));

    res.json({ success: true, data: { bookId: req.params.id, frames } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * GET /api/v1/picturebook/:id/audio
 * 获取配音音频列表（从时间轴中提取）
 */
router.get('/:id/audio', auth, async (req, res) => {
  try {
    const book = await getPictureBookById(req.params.id);
    if (!book) return res.status(404).json({ success: false, error: 'PictureBook not found' });

    const audios = (book.timeline?.frames || []).map(f => ({
      index: f.index,
      audio: f.audio,
      durationMs: f.durationMs,
      text: f.text,
    }));

    res.json({ success: true, data: { bookId: req.params.id, audios } });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
