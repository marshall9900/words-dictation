/**
 * Redis 客户端
 */

const { createClient } = require('redis');

let _client = null;

async function getClient() {
  if (!_client) {
    _client = createClient({ url: process.env.REDIS_URL || 'redis://localhost:6379' });
    _client.on('error', (err) => console.error('[Redis] Error:', err));
    await _client.connect();
    console.log('[Redis] Connected');
  }
  return _client;
}

// 便捷方法
const redis = {
  async get(key) {
    const client = await getClient();
    return client.get(key);
  },
  async set(key, value) {
    const client = await getClient();
    return client.set(key, value);
  },
  async setex(key, seconds, value) {
    const client = await getClient();
    return client.setEx(key, seconds, value);
  },
  async del(key) {
    const client = await getClient();
    return client.del(key);
  },
  async incr(key) {
    const client = await getClient();
    return client.incr(key);
  },
  async expire(key, seconds) {
    const client = await getClient();
    return client.expire(key, seconds);
  },
  getClient,
};

module.exports = redis;
