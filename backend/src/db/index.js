/**
 * 数据库连接（MySQL2 连接池）
 */

const mysql = require('mysql2/promise');

let _pool = null;

function getPool() {
  if (!_pool) {
    _pool = mysql.createPool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '3306'),
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'words_dictation_v2',
      waitForConnections: true,
      connectionLimit: 20,
      queueLimit: 0,
      charset: 'utf8mb4',
    });
  }
  return _pool;
}

async function query(sql, params = []) {
  const pool = getPool();
  const [rows] = await pool.execute(sql, params);
  return rows;
}

async function queryOne(sql, params = []) {
  const rows = await query(sql, params);
  return rows.length > 0 ? rows[0] : null;
}

module.exports = { getPool, query, queryOne };
