/**
 * 数据库迁移脚本 - v2
 * 
 * 运行: node src/db/migrate.js
 */

require('dotenv').config();
const { getPool } = require('./index');

const migrations = [
  // 用户表（兼容 v1）
  `CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(50),
    avatar_url VARCHAR(500),
    grade TINYINT DEFAULT 3 COMMENT '年级1-6',
    is_premium TINYINT DEFAULT 0 COMMENT '0=免费 1=付费',
    premium_expires_at DATETIME,
    parent_phone VARCHAR(20),
    total_score INT DEFAULT 0,
    streak_days INT DEFAULT 0,
    last_active_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

  // 单词表
  `CREATE TABLE IF NOT EXISTS words (
    id VARCHAR(36) PRIMARY KEY,
    word VARCHAR(100) NOT NULL,
    phonetic VARCHAR(100) COMMENT '音标',
    translation VARCHAR(500) COMMENT '中文释义',
    example_sentence TEXT COMMENT '例句',
    explanation TEXT COMMENT '单词讲解（用于绘本脚本）',
    difficulty TINYINT DEFAULT 2 COMMENT '1-5',
    grade TINYINT DEFAULT 3 COMMENT '适合年级',
    category VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_word (word)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

  // 动态绘本记录表
  `CREATE TABLE IF NOT EXISTS picturebooks (
    id VARCHAR(36) PRIMARY KEY,
    word_id VARCHAR(36) NOT NULL,
    word VARCHAR(100) NOT NULL,
    user_id VARCHAR(36),
    timeline_url VARCHAR(1000) COMMENT '时间轴 JSON 的 URL',
    timeline JSON COMMENT '时间轴 JSON 内联存储（Fix: 避免存储依赖断裂）',
    status ENUM('pending','generating','active','failed','rejected') DEFAULT 'pending',
    frame_count INT DEFAULT 0,
    total_duration_ms INT DEFAULT 0,
    moderation_status ENUM('pending','passed','failed','manual_review') DEFAULT 'passed',
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_word_id (word_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

  // 听写任务表
  `CREATE TABLE IF NOT EXISTS dictation_tasks (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    name VARCHAR(200),
    status ENUM('active','completed','abandoned') DEFAULT 'active',
    total_words INT DEFAULT 0,
    completed_words INT DEFAULT 0,
    correct_count INT DEFAULT 0,
    score INT DEFAULT 0,
    source ENUM('photo','manual','wrong_review') DEFAULT 'manual',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME,
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

  // 任务单词表
  `CREATE TABLE IF NOT EXISTS task_words (
    id VARCHAR(36) PRIMARY KEY,
    task_id VARCHAR(36) NOT NULL,
    word_id VARCHAR(36) NOT NULL,
    word VARCHAR(100) NOT NULL,
    is_correct TINYINT DEFAULT 0,
    spelling_score DECIMAL(5,2),
    pronunciation_score DECIMAL(5,2),
    attempt_count TINYINT DEFAULT 0,
    user_input VARCHAR(200),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_task_id (task_id),
    FOREIGN KEY (task_id) REFERENCES dictation_tasks(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

  // 错词本
  `CREATE TABLE IF NOT EXISTS wrong_words (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    word_id VARCHAR(36) NOT NULL,
    word VARCHAR(100) NOT NULL,
    wrong_count INT DEFAULT 1,
    last_wrong_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    mastered TINYINT DEFAULT 0,
    next_review_at DATETIME,
    review_count INT DEFAULT 0,
    picturebook_id VARCHAR(36) COMMENT '关联的动态绘本',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_word (user_id, word_id),
    INDEX idx_user_id (user_id),
    INDEX idx_next_review (next_review_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,

  // 成就表
  `CREATE TABLE IF NOT EXISTS achievements (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    achievement_type VARCHAR(50) NOT NULL,
    achievement_name VARCHAR(100),
    unlocked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
];

async function migrate() {
  const pool = getPool();
  console.log('[Migrate] Starting database migration...');

  for (let i = 0; i < migrations.length; i++) {
    const sql = migrations[i];
    const tableName = sql.match(/CREATE TABLE IF NOT EXISTS (\w+)/)?.[1] || `migration_${i}`;
    try {
      await pool.execute(sql);
      console.log(`[Migrate] ✅ ${tableName}`);
    } catch (err) {
      console.error(`[Migrate] ❌ ${tableName}: ${err.message}`);
      throw err;
    }
  }

  console.log('[Migrate] ✅ All migrations completed');
  process.exit(0);
}

migrate().catch(err => {
  console.error('[Migrate] Fatal error:', err);
  process.exit(1);
});
