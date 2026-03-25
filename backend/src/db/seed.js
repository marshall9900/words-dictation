/**
 * 种子数据 - 开发测试用
 */

require('dotenv').config();
const { v4: uuidv4 } = require('uuid');
const { query } = require('./index');

const words = [
  { word: 'apple', phonetic: '/ˈæp.əl/', translation: '苹果', explanation: 'An apple is a round red or green fruit that grows on trees. It is sweet and healthy.', grade: 1, difficulty: 1 },
  { word: 'banana', phonetic: '/bəˈnɑː.nə/', translation: '香蕉', explanation: 'A banana is a long yellow fruit. Monkeys love bananas! The word has three syllables.', grade: 1, difficulty: 1 },
  { word: 'elephant', phonetic: '/ˈel.ɪ.fənt/', translation: '大象', explanation: 'An elephant is a very large grey animal with a long nose called a trunk and big ears.', grade: 2, difficulty: 2 },
  { word: 'butterfly', phonetic: '/ˈbʌt.ə.flaɪ/', translation: '蝴蝶', explanation: 'A butterfly is a beautiful insect with large wings. It starts life as a caterpillar.', grade: 3, difficulty: 3 },
  { word: 'garden', phonetic: '/ˈɡɑːr.dən/', translation: '花园', explanation: 'A garden is a place outside where plants, flowers and vegetables are grown.', grade: 2, difficulty: 2 },
  { word: 'rainbow', phonetic: '/ˈreɪn.boʊ/', translation: '彩虹', explanation: 'A rainbow appears in the sky after rain. It has seven colors: red, orange, yellow, green, blue, indigo and violet.', grade: 2, difficulty: 2 },
];

async function seed() {
  console.log('[Seed] Inserting test words...');
  for (const w of words) {
    const id = uuidv4();
    try {
      await query(
        `INSERT IGNORE INTO words (id, word, phonetic, translation, explanation, grade, difficulty, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
        [id, w.word, w.phonetic, w.translation, w.explanation, w.grade, w.difficulty]
      );
      console.log(`[Seed] ✅ ${w.word}`);
    } catch (err) {
      console.log(`[Seed] ⚠️ ${w.word}: ${err.message}`);
    }
  }
  console.log('[Seed] Done');
  process.exit(0);
}

seed();
