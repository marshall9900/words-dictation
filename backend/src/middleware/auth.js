/**
 * JWT 认证中间件
 */

const jwt = require('jsonwebtoken');

function auth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const token = authHeader.slice(7);
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'dev_secret');
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid token' });
  }
}

/**
 * 可选认证（不强制，有 token 就解码）
 */
function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    try {
      req.user = jwt.verify(token, process.env.JWT_SECRET || 'dev_secret');
    } catch (_) {}
  }
  next();
}

/**
 * 需要付费用户
 * Phase 2: 产品分层 - 暂时注释掉 is_premium 校验
 */
function requirePremium(req, res, next) {
  // Phase 2: is_premium 校验暂时跳过，本期不做产品分层
  // if (!req.user) return res.status(401).json({ success: false, error: 'Unauthorized' });
  // if (!req.user.is_premium) {
  //   return res.status(403).json({ success: false, error: 'Premium subscription required' });
  // }
  next();
}

/**
 * 生成 JWT Token
 * Fix: 添加 is_premium 字段到 JWT payload
 */
function signToken(payload) {
  const secret = process.env.JWT_SECRET || 'dev_secret';
  const expiresIn = process.env.JWT_EXPIRES_IN || '7d';
  const enriched = {
    ...payload,
    is_premium: payload.is_premium || false,
  };
  return require('jsonwebtoken').sign(enriched, secret, { expiresIn });
}

// Alias for backwards compatibility
const authMiddleware = auth;

module.exports = { auth, authMiddleware, optionalAuth, requirePremium, signToken };
