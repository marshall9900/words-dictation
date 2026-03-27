/**
 * AI Provider 抽象接口层
 * 
 * 所有 AI 服务必须实现此接口，支持可插拔替换
 */

/**
 * @typedef {Object} ImageResult
 * @property {Buffer} data - 图片二进制数据
 * @property {string} mimeType - 'image/jpeg' | 'image/png'
 * @property {number} width
 * @property {number} height
 */

/**
 * @typedef {Object} AudioResult
 * @property {Buffer} data - 音频二进制数据
 * @property {string} mimeType - 'audio/mpeg' | 'audio/wav'
 * @property {number} durationMs - 音频时长（毫秒）
 */

/**
 * @typedef {Object} EvaluationResult
 * @property {number} score - 综合评分 0-100
 * @property {number} integrity - 完整度
 * @property {number} fluency - 流利度
 * @property {number} accuracy - 准确度
 * @property {Array<{phoneme: string, score: number}>} details
 * @property {boolean} isMock
 */

/**
 * AI Provider 抽象基类
 * 所有实现必须继承此类并实现所有方法
 */
class AIProvider {
  constructor(name) {
    this.name = name;
  }

  /**
   * 生成图片
   * @param {string} prompt - 图片描述提示词
   * @param {object} options - 配置项
   * @param {number} [options.width=1024]
   * @param {number} [options.height=1024]
   * @param {number} [options.seed] - 固定 seed 保证一致性
   * @param {string} [options.style='cartoon'] - 风格
   * @returns {Promise<ImageResult>}
   */
  async generateImage(prompt, options = {}) {
    throw new Error(`${this.name}.generateImage() not implemented`);
  }

  /**
   * 文字转语音（TTS）
   * @param {string} text - 要合成的文本
   * @param {object} options - 配置项
   * @param {string} [options.voice] - 音色 ID
   * @param {number} [options.speed=1.0] - 语速 0.5-2.0
   * @param {string} [options.language='en'] - 语言
   * @returns {Promise<AudioResult>}
   */
  async textToSpeech(text, options = {}) {
    throw new Error(`${this.name}.textToSpeech() not implemented`);
  }

  /**
   * 语音转文字（ASR）
   * @param {Buffer} audio - 音频数据
   * @param {object} options - 配置项
   * @param {string} [options.language='en'] - 语言
   * @returns {Promise<string>}
   */
  async speechToText(audio, options = {}) {
    throw new Error(`${this.name}.speechToText() not implemented`);
  }

  /**
   * 发音评测
   * @param {string} text - 标准文本
   * @param {Buffer} audio - 用户录音
   * @returns {Promise<EvaluationResult>}
   */
  async evaluatePronunciation(text, audio) {
    throw new Error(`${this.name}.evaluatePronunciation() not implemented`);
  }

  /**
   * OCR 识别
   * @param {Buffer|string} image - 图片数据或 base64
   * @returns {Promise<string[]>} - 识别出的单词列表
   */
  async ocrExtractWords(image) {
    throw new Error(`${this.name}.ocrExtractWords() not implemented`);
  }
}

module.exports = { AIProvider };
