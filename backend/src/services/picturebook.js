/**
 * 动态绘本生成服务（Phase 1 核心）
 * 
 * 流程：
 *   1. 生成讲解文字脚本（N段）
 *   2. 并行生成 N 张卡通图片（MiniMax Image）
 *   3. 并行生成 N 段配音音频（MiniMax TTS）
 *   4. 组装时间轴 JSON
 *   5. 上传 COS/本地存储
 *   6. 写数据库，返回 CDN URL + 时间轴
 */

const { v4: uuidv4 } = require('uuid');
const { getImageProvider, getTTSProvider } = require('../ai');
const { getStorage } = require('../storage');
const db = require('../db');

/**
 * 标准卡通绘本提示词模板
 * @param {string} word - 单词
 * @param {string} scene - 场景描述（从讲解文字提取）
 * @param {number} frameIndex - 帧序号（保证角色一致性）
 * @returns {string}
 */
function buildImagePrompt(word, scene, frameIndex = 0) {
  const styleTag = `children's cartoon picture book illustration, child-friendly, vivid colors, high quality, consistent character design`;

  if (frameIndex === 0) {
    // 第一帧：展示单词和主角
    return `A ${styleTag}. A cute cartoon character introducing the English word "${word}". 
The word "${word.toUpperCase()}" displayed in bold colorful bubble letters at the bottom. 
Bright cheerful background with clouds and sunshine. ${scene}. No extra text.`;
  }

  return `A ${styleTag}. Continuing the story of the English word "${word}". 
Scene: ${scene}. Bright colorful educational illustration. No extra text.`;
}

/**
 * 生成讲解文字脚本
 * 
 * 简单规则拆分：将讲解文字按句号/问号/感叹号分段
 * Phase 2 可接入 LLM 生成更智能的脚本
 * 
 * @param {string} word - 单词
 * @param {string} explanation - 完整讲解文字
 * @returns {string[]} - 分段后的讲解文字列表
 */
function splitScript(word, explanation) {
  if (!explanation || explanation.trim() === '') {
    // 默认脚本
    const w = word;
    const W = word.toUpperCase();
    return [
      `Hi there! Today we're learning the word "${w}". Let's say it together: ${w}!`,
      `${W} — let's see what it means and how to use it in a sentence.`,
      `Now let's spell it together: ${w.split('').join(' — ')}. Great job!`,
    ];
  }

  // 按句子分割（每段 1-2 句）
  const sentences = explanation.match(/[^.!?]+[.!?]+/g) || [explanation];
  const chunks = [];
  let current = '';

  for (let i = 0; i < sentences.length; i++) {
    const s = sentences[i].trim();
    if (!s) continue;

    if (current === '') {
      current = s;
    } else if (current.split(' ').length + s.split(' ').length <= 35) {
      // 合并短句（不超过 35 词/段）
      current += ' ' + s;
    } else {
      chunks.push(current);
      current = s;
    }
  }
  if (current) chunks.push(current);

  // 最少 2 段，最多 5 段
  if (chunks.length === 1) {
    const mid = Math.floor(chunks[0].length / 2);
    const spaceIdx = chunks[0].indexOf(' ', mid);
    if (spaceIdx > -1) {
      return [chunks[0].substring(0, spaceIdx), chunks[0].substring(spaceIdx + 1)];
    }
  }

  return chunks.slice(0, 5); // 最多 5 帧
}

/**
 * 生成单词动态绘本
 * 
 * @param {object} params
 * @param {string} params.wordId - 单词记录 ID
 * @param {string} params.word - 单词
 * @param {string} [params.explanation] - 讲解文字（可选，会自动生成默认脚本）
 * @param {string} [params.userId] - 用户 ID（用于按用户缓存）
 * @param {number} [params.seed] - 固定 seed，保证图片角色一致性
 * @returns {Promise<PictureBookResult>}
 */
async function generatePictureBook({ wordId, word, explanation, userId, seed }) {
  const bookId = uuidv4();
  const fixedSeed = seed || Math.floor(Math.random() * 999999) + 1;
  const basePath = `picturebook/${wordId}/${bookId}`;

  console.log(`[PictureBook] Generating for word="${word}" bookId=${bookId}`);

  // Step 1: 拆分讲解文字为 N 段脚本
  const scripts = splitScript(word, explanation);
  console.log(`[PictureBook] Split into ${scripts.length} segments`);

  const imageProvider = getImageProvider();
  const ttsProvider = getTTSProvider();
  const storage = getStorage();

  // Step 2 & 3: 并行生成图片和配音
  const tasks = scripts.map((text, index) => {
    const prompt = buildImagePrompt(word, text, index);
    return {
      text,
      prompt,
      index,
    };
  });

  // 并行执行所有帧的生成（图片+音频同时进行）
  const frameResults = await Promise.all(
    tasks.map(async ({ text, prompt, index }) => {
      const frameNum = String(index + 1).padStart(2, '0');

      // 并行生成图片和音频
      const [imageResult, audioResult] = await Promise.all([
        imageProvider.generateImage(prompt, {
          width: 1024,
          height: 1024,
          seed: fixedSeed, // 同一本书用相同 seed 保证角色一致性
        }).catch(err => {
          console.error(`[PictureBook] Image generation failed for frame ${index}:`, err.message);
          return null;
        }),
        ttsProvider.textToSpeech(text, {
          speed: 0.9,
          language: 'en',
        }).catch(err => {
          console.error(`[PictureBook] TTS generation failed for frame ${index}:`, err.message);
          return null;
        }),
      ]);

      return { index, frameNum, text, imageResult, audioResult };
    })
  );

  // Step 4 & 5: 上传所有文件到存储
  const uploadTasks = [];
  const frameData = [];

  for (const { index, frameNum, text, imageResult, audioResult } of frameResults) {
    const frameInfo = {
      index,
      text,
      imageUrl: null,
      audioUrl: null,
      durationMs: 4000, // 默认 4 秒，无音频时用
    };

    if (imageResult && imageResult.data) {
      const imagePath = `${basePath}/frame_${frameNum}.jpg`;
      uploadTasks.push(
        storage.upload(imageResult.data, imagePath, { contentType: 'image/jpeg' })
          .then(url => { frameInfo.imageUrl = url; })
          .catch(err => console.error(`[PictureBook] Image upload failed:`, err.message))
      );
    }

    if (audioResult && audioResult.data) {
      const audioPath = `${basePath}/voice_${frameNum}.mp3`;
      frameInfo.durationMs = audioResult.durationMs;
      uploadTasks.push(
        storage.upload(audioResult.data, audioPath, { contentType: 'audio/mpeg' })
          .then(url => { frameInfo.audioUrl = url; })
          .catch(err => console.error(`[PictureBook] Audio upload failed:`, err.message))
      );
    }

    frameData.push(frameInfo);
  }

  // 等待所有上传完成
  await Promise.all(uploadTasks);

  // Step 4: 组装时间轴 JSON
  const timeline = {
    bookId,
    wordId,
    word,
    frames: frameData.map(f => ({
      index: f.index,
      text: f.text,
      image: f.imageUrl,
      audio: f.audioUrl,
      durationMs: f.durationMs,
    })),
    totalDurationMs: frameData.reduce((sum, f) => sum + f.durationMs, 0),
    generatedAt: new Date().toISOString(),
  };

  // 上传时间轴 JSON
  const timelinePath = `${basePath}/timeline.json`;
  const timelineUrl = await storage.upload(
    Buffer.from(JSON.stringify(timeline, null, 2)),
    timelinePath,
    { contentType: 'application/json' }
  ).catch(err => {
    console.error('[PictureBook] Timeline upload failed:', err.message);
    return null;
  });

  // Step 7: 写数据库
  try {
    await db.query(
      `INSERT INTO picturebooks 
       (id, word_id, word, user_id, timeline_url, timeline, status, frame_count, total_duration_ms, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, NOW())`,
      [bookId, wordId, word, userId || null, timelineUrl, JSON.stringify(timeline), frameData.length, timeline.totalDurationMs]
    );
  } catch (dbErr) {
    console.error('[PictureBook] DB write failed:', dbErr.message);
    // 不阻塞返回
  }

  console.log(`[PictureBook] Generated successfully: ${bookId}, ${frameData.length} frames`);

  return {
    bookId,
    wordId,
    word,
    timeline,
    timelineUrl,
    frameCount: frameData.length,
    totalDurationMs: timeline.totalDurationMs,
  };
}

/**
 * 从数据库获取绘本详情
 */
async function getPictureBookById(bookId) {
  const rows = await db.query(
    'SELECT * FROM picturebooks WHERE id = ? AND status = "active"',
    [bookId]
  );
  if (rows.length === 0) return null;

  const book = rows[0];

  // Fix: 优先使用内联 timeline 列，避免存储路径断裂
  if (book.timeline) {
    // timeline 已内联存储在 DB，直接使用（字符串需解析）
    if (typeof book.timeline === 'string') {
      try { book.timeline = JSON.parse(book.timeline); } catch (_) {}
    }
  } else if (book.timeline_url) {
    // 降级：从存储服务获取时间轴 JSON
    try {
      const storage = getStorage();
      const timelineData = await storage.download(book.timeline_url);
      book.timeline = JSON.parse(timelineData.toString());
    } catch (err) {
      console.error('[PictureBook] Failed to fetch timeline:', err.message);
    }
  }

  return book;
}

/**
 * 按单词 ID 获取最新绘本（用于缓存复用）
 */
async function getLatestPictureBookByWord(wordId) {
  const rows = await db.query(
    'SELECT * FROM picturebooks WHERE word_id = ? AND status = "active" ORDER BY created_at DESC LIMIT 1',
    [wordId]
  );
  return rows.length > 0 ? rows[0] : null;
}

module.exports = {
  generatePictureBook,
  getPictureBookById,
  getLatestPictureBookByWord,
  splitScript,
  buildImagePrompt,
};
