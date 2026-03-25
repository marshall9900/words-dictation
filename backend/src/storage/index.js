/**
 * Storage Registry
 * 
 * 根据配置返回合适的存储实现
 */

const { TencentCloudCOS } = require('./cos');
const { LocalStorage } = require('./local');

let _cosInstance = null;
let _localInstance = null;

/**
 * 获取默认存储实例
 * 生产: COS, 开发: Local
 */
function getStorage() {
  if (process.env.TENCENT_SECRET_ID && process.env.COS_BUCKET) {
    if (!_cosInstance) _cosInstance = new TencentCloudCOS();
    return _cosInstance;
  }

  console.warn('[Storage] COS not configured, using LocalStorage');
  if (!_localInstance) _localInstance = new LocalStorage();
  return _localInstance;
}

/**
 * 获取 COS 实例（强制）
 */
function getCOSStorage() {
  if (!_cosInstance) _cosInstance = new TencentCloudCOS();
  return _cosInstance;
}

/**
 * 获取本地存储实例
 */
function getLocalStorage() {
  if (!_localInstance) _localInstance = new LocalStorage();
  return _localInstance;
}

module.exports = { getStorage, getCOSStorage, getLocalStorage };
