/**
 * 绘本生成队列（Bull + Redis）
 * 
 * 支持高并发异步生成，限流防止 API 超额
 */

const Bull = require('bull');
const { generatePictureBook } = require('../services/picturebook');

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const CONCURRENCY = parseInt(process.env.PICTUREBOOK_QUEUE_CONCURRENCY || '3');
const MAX_RETRIES = parseInt(process.env.PICTUREBOOK_QUEUE_MAX_RETRIES || '3');

// 创建队列实例
const pictureBookQueue = new Bull('picturebook', REDIS_URL, {
  defaultJobOptions: {
    attempts: MAX_RETRIES,
    backoff: {
      type: 'exponential',
      delay: 2000, // 首次重试延迟 2s，指数增长
    },
    removeOnComplete: 100, // 保留最近 100 条已完成任务
    removeOnFail: 50,
  },
});

// Worker：处理生成任务
pictureBookQueue.process(CONCURRENCY, async (job) => {
  const { wordId, word, explanation, userId, seed, jobId } = job.data;

  console.log(`[Queue] Processing picturebook job: ${job.id}, word=${word}`);

  try {
    const result = await generatePictureBook({ wordId, word, explanation, userId, seed });
    console.log(`[Queue] Job ${job.id} completed: bookId=${result.bookId}`);
    return result;
  } catch (err) {
    console.error(`[Queue] Job ${job.id} failed:`, err.message);
    throw err; // Bull 会自动重试
  }
});

// 事件监听
pictureBookQueue.on('completed', (job, result) => {
  console.log(`[Queue] ✅ Job ${job.id} completed`);
});

pictureBookQueue.on('failed', (job, err) => {
  console.error(`[Queue] ❌ Job ${job.id} failed after ${job.attemptsMade} attempts:`, err.message);
});

pictureBookQueue.on('stalled', (job) => {
  console.warn(`[Queue] ⚠️ Job ${job.id} stalled`);
});

/**
 * 添加绘本生成任务到队列
 * @returns {Promise<Bull.Job>}
 */
async function enqueueGeneration(params) {
  return pictureBookQueue.add(params, {
    priority: params.isPriority ? 1 : 5, // 付费用户可设高优先级
  });
}

/**
 * 获取任务状态
 */
async function getJobStatus(jobId) {
  const job = await pictureBookQueue.getJob(jobId);
  if (!job) return null;

  const state = await job.getState();
  return {
    jobId: job.id,
    state, // waiting | active | completed | failed | delayed
    progress: job.progress(),
    result: state === 'completed' ? job.returnvalue : null,
    error: state === 'failed' ? job.failedReason : null,
    createdAt: new Date(job.timestamp).toISOString(),
  };
}

module.exports = { pictureBookQueue, enqueueGeneration, getJobStatus };
