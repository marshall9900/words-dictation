/**
 * MiniMax AI Provider 实现
 * 
 * 负责：
 *   - 图片生成（MiniMax Image Generation）
 *   - TTS 配音（MiniMax TTS）
 * 
 * Phase 1 核心实现
 */

const axios = require('axios');
const FormData = require('form-data');
const { AIProvider } = require('./base');

class MiniMaxProvider extends AIProvider {
  constructor() {
    super('MiniMax');
    this.apiKey = process.env.MINIMAX_API_KEY;
    this.groupId = process.env.MINIMAX_GROUP_ID;
    this.baseUrl = process.env.MINIMAX_BASE_URL || 'https://api.minimax.chat/v1';
    this.imageModel = process.env.MINIMAX_IMAGE_MODEL || 'image-01';
    this.ttsModel = process.env.MINIMAX_TTS_MODEL || 'speech-02';
    this.ttsVoice = process.env.MINIMAX_TTS_VOICE || 'female-tianmei-jingpin';
    this.defaultSpeed = parseFloat(process.env.MINIMAX_TTS_SPEED || '0.9');
  }

  _checkCredentials() {
    if (!this.apiKey) {
      throw new Error('MINIMAX_API_KEY not configured');
    }
  }

  /**
   * 生成卡通绘本风格图片
   */
  async generateImage(prompt, options = {}) {
    this._checkCredentials();

    const {
      width = parseInt(process.env.MINIMAX_IMAGE_WIDTH || '1024'),
      height = parseInt(process.env.MINIMAX_IMAGE_HEIGHT || '1024'),
      seed,
    } = options;

    const payload = {
      model: this.imageModel,
      prompt,
      width,
      height,
      ...(seed !== undefined && { seed }),
      response_format: 'b64_json',
    };

    try {
      const res = await axios.post(
        `${this.baseUrl}/image_generation`,
        payload,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          timeout: 60000,
        }
      );

      const data = res.data;
      if (data.data && data.data.length > 0) {
        const imgData = data.data[0];
        const buffer = Buffer.from(imgData.b64_json || imgData.url, 'base64');
        return {
          data: buffer,
          mimeType: 'image/jpeg',
          width,
          height,
        };
      }

      // 如果返回的是 URL 而非 base64
      if (data.data && data.data[0] && data.data[0].url) {
        const imgRes = await axios.get(data.data[0].url, { responseType: 'arraybuffer', timeout: 30000 });
        return {
          data: Buffer.from(imgRes.data),
          mimeType: 'image/jpeg',
          width,
          height,
        };
      }

      throw new Error(`MiniMax image generation failed: ${JSON.stringify(data)}`);
    } catch (err) {
      if (err.response) {
        throw new Error(`MiniMax API error ${err.response.status}: ${JSON.stringify(err.response.data)}`);
      }
      throw err;
    }
  }

  /**
   * MiniMax TTS 文字转语音
   */
  async textToSpeech(text, options = {}) {
    this._checkCredentials();

    const {
      voice = this.ttsVoice,
      speed = this.defaultSpeed,
      language = 'en',
    } = options;

    const payload = {
      model: this.ttsModel,
      text,
      timber_weights: [{ voice_id: voice, weight: 1 }],
      voice_setting: {
        voice_id: voice,
        speed,
        vol: 1.0,
        pitch: 0,
      },
      audio_setting: {
        audio_sample_rate: 32000,
        bitrate: 128000,
        format: 'mp3',
        channel: 1,
      },
    };

    try {
      const res = await axios.post(
        `${this.baseUrl}/t2a_v2?GroupId=${this.groupId}`,
        payload,
        {
          headers: {
            'Authorization': `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          responseType: 'json',
          timeout: 30000,
        }
      );

      const data = res.data;

      // MiniMax TTS 返回 base64 编码的音频
      if (data.data && data.data.audio) {
        const buffer = Buffer.from(data.data.audio, 'hex');
        const durationMs = this._estimateAudioDuration(text, speed);
        return {
          data: buffer,
          mimeType: 'audio/mpeg',
          durationMs,
        };
      }

      throw new Error(`MiniMax TTS failed: ${JSON.stringify(data)}`);
    } catch (err) {
      if (err.response) {
        throw new Error(`MiniMax TTS error ${err.response.status}: ${JSON.stringify(err.response.data)}`);
      }
      throw err;
    }
  }

  /**
   * 预估音频时长（毫秒）
   * 基于字数和语速估算，实际时长以播放为准
   */
  _estimateAudioDuration(text, speed = 1.0) {
    const wordCount = text.split(/\s+/).length;
    // 英文平均语速：120-150 词/分钟，儿童友好语速约 120 词/分钟
    const wordsPerMinute = 120 * speed;
    return Math.round((wordCount / wordsPerMinute) * 60 * 1000) + 500; // 加 500ms 缓冲
  }

  /**
   * ASR - MiniMax 暂不主用，此方法保留接口
   */
  async speechToText(audio, options = {}) {
    throw new Error('MiniMax ASR not implemented. Use OpenAI Whisper.');
  }

  /**
   * 发音评测 - MiniMax 暂不主用
   */
  async evaluatePronunciation(text, audio) {
    throw new Error('MiniMax pronunciation evaluation not implemented. Use XFYun ISE.');
  }

  /**
   * OCR - MiniMax 暂不主用
   */
  async ocrExtractWords(image) {
    throw new Error('MiniMax OCR not implemented. Use Tencent Cloud OCR.');
  }
}

module.exports = { MiniMaxProvider };
