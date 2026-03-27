/**
 * AI Provider Registry
 * 
 * 工厂模式，根据配置返回对应的 AI Provider 实例
 * 支持按功能选择不同 Provider（图片用 MiniMax，TTS 用 Azure 等）
 */

const { MiniMaxProvider } = require('./minimax');
const { AzureProvider } = require('./azure');
const { MockProvider } = require('./mock');

let _minimax = null;
let _azure = null;
let _mock = null;

/**
 * 获取图片生成 Provider
 * Phase 1: MiniMax
 */
function getImageProvider() {
  const key = process.env.MINIMAX_API_KEY;
  if (!key || key.startsWith('test') || key === 'your_minimax_api_key') {
    console.warn('[AI] MINIMAX_API_KEY not set or invalid, using MockProvider for image generation');
    return getMockProvider();
  }
  if (!_minimax) _minimax = new MiniMaxProvider();
  return _minimax;
}

/**
 * 获取 TTS Provider（动态绘本配音）
 * Phase 1: MiniMax TTS
 */
function getTTSProvider() {
  const key = process.env.MINIMAX_API_KEY;
  if (!key || key.startsWith('test') || key === 'your_minimax_api_key') {
    console.warn('[AI] MINIMAX_API_KEY not set or invalid, using MockProvider for TTS');
    return getMockProvider();
  }
  if (!_minimax) _minimax = new MiniMaxProvider();
  return _minimax;
}

/**
 * 获取单词朗读 TTS Provider
 * Phase 1 暂用 MiniMax，Phase 2 切换 Azure
 */
function getWordTTSProvider() {
  if (process.env.AZURE_TTS_KEY) {
    if (!_azure) _azure = new AzureProvider();
    return _azure;
  }
  // Fallback to MiniMax
  return getTTSProvider();
}

/**
 * 获取 Mock Provider（开发测试）
 */
function getMockProvider() {
  if (!_mock) _mock = new MockProvider();
  return _mock;
}

/**
 * 获取 MiniMax Provider（直接访问）
 */
function getMiniMaxProvider() {
  if (!_minimax) _minimax = new MiniMaxProvider();
  return _minimax;
}

module.exports = {
  getImageProvider,
  getTTSProvider,
  getWordTTSProvider,
  getMiniMaxProvider,
  getMockProvider,
};
