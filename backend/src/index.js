/**
 * Words Dictation v2 - 后端入口
 * 
 * Phase 1: 动态绘本图片+配音
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;

// ── 安全中间件 ────────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ── 请求限流 ─────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000'),
  max: parseInt(process.env.RATE_LIMIT_MAX || '100'),
  message: { success: false, error: 'Too many requests, please slow down' },
});
app.use('/api/', limiter);

// ── Body 解析 ─────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan('dev'));

// ── 本地文件静态服务（开发模式）────────────────────────────
if (process.env.NODE_ENV !== 'production') {
  app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));
}

// ── API 路由 ──────────────────────────────────────────────
app.use('/api/v1/picturebook', require('./routes/picturebook'));
app.use('/api/v1/user', require('./routes/user'));
app.use('/api/v1/dictation', require('./routes/dictation'));
app.use('/api/v1/evaluation', require('./routes/evaluation'));
app.use('/api/v1/wrongword', require('./routes/wrongword'));
app.use('/api/v1/achievement', require('./routes/achievement'));

// ── 健康检查 ──────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '2.0.0',
    phase: 'Phase 1 - PictureBook',
    timestamp: new Date().toISOString(),
  });
});

// ── 404 处理 ──────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, error: `Route not found: ${req.method} ${req.path}` });
});

// ── 全局错误处理 ──────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('[Error]', err);
  res.status(500).json({ success: false, error: err.message || 'Internal server error' });
});

// ── 启动 ─────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════╗
║     Words Dictation v2 Backend            ║
║     Phase 1: 动态绘本图片+配音              ║
╠═══════════════════════════════════════════╣
║  Port:    ${PORT}                             ║
║  Node:    ${process.version}                    ║
║  Env:     ${process.env.NODE_ENV || 'development'}              ║
╚═══════════════════════════════════════════╝
  `);
  console.log(`[Server] 🚀 API: http://localhost:${PORT}/api/v1`);
  console.log(`[Server] 🏥 Health: http://localhost:${PORT}/health`);

  if (!process.env.MINIMAX_API_KEY) {
    console.warn('[Server] ⚠️  MINIMAX_API_KEY not set - using MockProvider');
  }
  if (!process.env.TENCENT_SECRET_ID) {
    console.warn('[Server] ⚠️  TENCENT_SECRET_ID not set - using LocalStorage');
  }
});

module.exports = app;
