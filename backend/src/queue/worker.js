/**
 * Queue Worker - 独立进程启动
 * 
 * 运行方式: node src/queue/worker.js
 * 或: npm run worker
 */

require('dotenv').config();
const { pictureBookQueue } = require('./picturebook');

console.log('[Worker] 🚀 PictureBook queue worker started');
console.log(`[Worker] Concurrency: ${process.env.PICTUREBOOK_QUEUE_CONCURRENCY || 3}`);
console.log(`[Worker] Redis: ${process.env.REDIS_URL || 'redis://localhost:6379'}`);

// 优雅退出
process.on('SIGTERM', async () => {
  console.log('[Worker] SIGTERM received, closing queue...');
  await pictureBookQueue.close();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('[Worker] SIGINT received, closing queue...');
  await pictureBookQueue.close();
  process.exit(0);
});
