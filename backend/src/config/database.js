const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306'),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'words_dictation_v2',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
});

async function query(sql, params) {
  const [results] = await pool.execute(sql, params);
  return results;
}

async function getConnection() {
  return await pool.getConnection();
}

async function closePool() {
  await pool.end();
}

module.exports = {
  query,
  getConnection,
  closePool,
  pool
};
