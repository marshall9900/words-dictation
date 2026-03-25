const { v4: uuidv4 } = require('uuid');
const { query, queryOne } = require('../db');

// ── 用户模型 ──────────────────────────────────────────────

async function createUser({ nickname = '小学生', grade = 1 } = {}) {
  const id = uuidv4();
  await query(
    `INSERT INTO users (id, nickname, grade, total_score, current_streak)
     VALUES (?, ?, ?, 0, 0)`,
    [id, nickname, grade]
  );
  return findUserById(id);
}

async function findUserById(id) {
  return queryOne('SELECT * FROM users WHERE id = ?', [id]);
}

async function updateUser(id, fields) {
  const allowed = ['nickname', 'grade', 'avatar_url', 'total_score', 'current_streak'];
  const updates = Object.entries(fields)
    .filter(([k]) => allowed.includes(k))
    .map(([k]) => `${k} = ?`);
  const values = Object.entries(fields)
    .filter(([k]) => allowed.includes(k))
    .map(([, v]) => v);

  if (updates.length === 0) return findUserById(id);
  await query(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, [...values, id]);
  return findUserById(id);
}

async function addScore(userId, delta) {
  await query(
    'UPDATE users SET total_score = total_score + ? WHERE id = ?',
    [delta, userId]
  );
}

// ── 词库模型 ──────────────────────────────────────────────

async function getWordsByGrade(grade, limit = 50) {
  return query(
    'SELECT * FROM words WHERE grade <= ? ORDER BY difficulty ASC LIMIT ?',
    [grade, limit]
  );
}

async function getWordsByIds(ids) {
  if (!ids.length) return [];
  const placeholders = ids.map(() => '?').join(',');
  return query(`SELECT * FROM words WHERE id IN (${placeholders})`, ids);
}

async function findWordByText(word) {
  return queryOne('SELECT * FROM words WHERE word = ?', [word.toLowerCase()]);
}

async function searchWords(wordList) {
  if (!wordList.length) return [];
  const placeholders = wordList.map(() => '?').join(',');
  return query(
    `SELECT * FROM words WHERE word IN (${placeholders})`,
    wordList.map(w => w.toLowerCase())
  );
}

// ── 听写任务模型 ──────────────────────────────────────────

async function createDictationTask({ userId, words, source = 'manual', sourceImageUrl = null }) {
  const taskId = uuidv4();
  await query(
    `INSERT INTO dictation_tasks (id, user_id, source, source_image_url, status, total_words)
     VALUES (?, ?, ?, ?, 'pending', ?)`,
    [taskId, userId, source, sourceImageUrl, words.length]
  );

  // 插入任务单词列表
  for (let i = 0; i < words.length; i++) {
    await query(
      `INSERT INTO task_words (id, task_id, word_id, order_index) VALUES (?, ?, ?, ?)`,
      [uuidv4(), taskId, words[i].id, i]
    );
  }

  return getTask(taskId);
}

async function getTask(taskId) {
  const task = await queryOne('SELECT * FROM dictation_tasks WHERE id = ?', [taskId]);
  if (!task) return null;

  const taskWords = await query(
    `SELECT tw.*, w.word, w.phonetic, w.meaning, w.audio_url, w.grade, w.difficulty
     FROM task_words tw
     JOIN words w ON tw.word_id = w.id
     WHERE tw.task_id = ?
     ORDER BY tw.order_index`,
    [taskId]
  );

  return { ...task, words: taskWords };
}

async function updateTaskStatus(taskId, status) {
  const fields = { status };
  if (status === 'in_progress') fields.started_at = new Date();
  if (status === 'completed') fields.completed_at = new Date();

  const updates = Object.keys(fields).map(k => `${k} = ?`).join(', ');
  const values = [...Object.values(fields), taskId];
  await query(`UPDATE dictation_tasks SET ${updates} WHERE id = ?`, values);
}

async function recordWordResult(taskWordId, { spellingInput, spellingScore, pronunciationScore, isCorrect }) {
  await query(
    `UPDATE task_words 
     SET spelling_input = ?, spelling_score = ?, pronunciation_score = ?, is_correct = ?, evaluated_at = NOW()
     WHERE id = ?`,
    [spellingInput, spellingScore, pronunciationScore, isCorrect, taskWordId]
  );
}

async function completeTask(taskId) {
  const taskWords = await query(
    'SELECT * FROM task_words WHERE task_id = ?',
    [taskId]
  );
  const correctCount = taskWords.filter(w => w.is_correct).length;
  const score = taskWords.reduce((sum, w) => sum + (w.is_correct ? 10 : 2), 0);

  await query(
    `UPDATE dictation_tasks 
     SET status = 'completed', correct_count = ?, score = ?, completed_at = NOW()
     WHERE id = ?`,
    [correctCount, score, taskId]
  );

  return getTask(taskId);
}

// ── 错词本模型 ────────────────────────────────────────────

async function upsertWrongWord(userId, wordId) {
  const existing = await queryOne(
    'SELECT * FROM wrong_words WHERE user_id = ? AND word_id = ?',
    [userId, wordId]
  );

  const nextReviewAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 明天

  if (existing) {
    await query(
      `UPDATE wrong_words 
       SET wrong_count = wrong_count + 1, last_wrong_at = NOW(), 
           next_review_at = ?, mastered = FALSE
       WHERE user_id = ? AND word_id = ?`,
      [nextReviewAt, userId, wordId]
    );
  } else {
    await query(
      `INSERT INTO wrong_words (id, user_id, word_id, wrong_count, last_wrong_at, mastered, next_review_at)
       VALUES (?, ?, ?, 1, NOW(), FALSE, ?)`,
      [uuidv4(), userId, wordId, nextReviewAt]
    );
  }
}

async function getWrongWords(userId, { status = 'all', page = 1, pageSize = 20 } = {}) {
  let where = 'ww.user_id = ? AND ww.mastered = FALSE';
  const params = [userId];

  if (status === 'due') {
    where += ' AND ww.next_review_at <= NOW()';
  }

  const offset = (page - 1) * pageSize;
  const items = await query(
    `SELECT ww.*, w.word, w.phonetic, w.meaning, w.audio_url
     FROM wrong_words ww
     JOIN words w ON ww.word_id = w.id
     WHERE ${where}
     ORDER BY ww.wrong_count DESC, ww.last_wrong_at DESC
     LIMIT ? OFFSET ?`,
    [...params, pageSize, offset]
  );

  const [{ total }] = await query(
    `SELECT COUNT(*) AS total FROM wrong_words ww WHERE ${where}`,
    params
  );

  return { items, total };
}

async function markWrongWordMastered(userId, wordId) {
  await query(
    'UPDATE wrong_words SET mastered = TRUE WHERE user_id = ? AND word_id = ?',
    [userId, wordId]
  );
}

async function deleteWrongWord(userId, wordId) {
  await query(
    'DELETE FROM wrong_words WHERE user_id = ? AND word_id = ?',
    [userId, wordId]
  );
}

// ── 学习记录模型 ──────────────────────────────────────────

async function addLearningRecord({ userId, wordId, taskId, actionType, spellingScore, pronunciationScore }) {
  await query(
    `INSERT INTO learning_records (id, user_id, word_id, task_id, action_type, spelling_score, pronunciation_score)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [uuidv4(), userId, wordId, taskId, actionType, spellingScore, pronunciationScore]
  );
}

// ── 成就模型 ──────────────────────────────────────────────

const ACHIEVEMENT_DEFS = [
  { key: 'first_dictation', name: '初学者', condition: '完成第一次听写', reward: 10 },
  { key: 'hundred_correct', name: '单词达人', condition: '累计答对100个词', reward: 50 },
  { key: 'streak_3', name: '连击新星', condition: '连续打卡3天', reward: 30 },
  { key: 'streak_7', name: '打卡达人', condition: '连续打卡7天', reward: 100 },
  { key: 'perfect_round', name: '满分王者', condition: '一轮听写全对', reward: 20 },
  { key: 'clear_10_wrong', name: '错词克星', condition: '消灭10个错词', reward: 30 },
];

async function getAchievements(userId) {
  const unlocked = await query(
    'SELECT * FROM achievements WHERE user_id = ? ORDER BY unlocked_at DESC',
    [userId]
  );
  const unlockedKeys = new Set(unlocked.map(a => a.achievement_key));
  const locked = ACHIEVEMENT_DEFS.filter(d => !unlockedKeys.has(d.key));
  return { unlocked, locked };
}

async function unlockAchievement(userId, key) {
  const def = ACHIEVEMENT_DEFS.find(d => d.key === key);
  if (!def) return;

  const existing = await queryOne(
    'SELECT id FROM achievements WHERE user_id = ? AND achievement_key = ?',
    [userId, key]
  );
  if (existing) return; // 已解锁

  await query(
    `INSERT INTO achievements (id, user_id, achievement_key, reward_score)
     VALUES (?, ?, ?, ?)`,
    [uuidv4(), userId, key, def.reward]
  );
  await addScore(userId, def.reward);
  return def;
}

module.exports = {
  // 用户
  createUser, findUserById, updateUser, addScore,
  // 词库
  getWordsByGrade, getWordsByIds, findWordByText, searchWords,
  // 任务
  createDictationTask, getTask, updateTaskStatus, recordWordResult, completeTask,
  // 错词本
  upsertWrongWord, getWrongWords, markWrongWordMastered, deleteWrongWord,
  // 学习记录
  addLearningRecord,
  // 成就
  getAchievements, unlockAchievement, ACHIEVEMENT_DEFS,
};
