/**
 * Azure TTS Provider（Phase 2 - 单词朗读）
 * 
 * 用于听写时的单词朗读（非绘本配音）
 */

const axios = require('axios');
const { AIProvider } = require('./base');

class AzureProvider extends AIProvider {
  constructor() {
    super('Azure');
    this.key = process.env.AZURE_TTS_KEY;
    this.region = process.env.AZURE_TTS_REGION || 'eastus';
    this.endpoint = `https://${this.region}.tts.speech.microsoft.com/cognitiveservices/v1`;
  }

  async generateImage(prompt, options = {}) {
    throw new Error('Azure does not support image generation. Use MiniMax.');
  }

  async textToSpeech(text, options = {}) {
    if (!this.key) {
      throw new Error('AZURE_TTS_KEY not configured');
    }

    const {
      voice = 'en-US-JennyNeural',
      rate = '-10%',
    } = options;

    const ssml = `<speak version='1.0' xml:lang='en-US'>
      <voice xml:lang='en-US' name='${voice}'>
        <prosody rate='${rate}'>${text}</prosody>
      </voice>
    </speak>`;

    try {
      const res = await axios.post(this.endpoint, ssml, {
        headers: {
          'Ocp-Apim-Subscription-Key': this.key,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        },
        responseType: 'arraybuffer',
        timeout: 10000,
      });

      const buffer = Buffer.from(res.data);
      const wordCount = text.split(/\s+/).length;
      const durationMs = Math.round((wordCount / 120) * 60 * 1000) + 300;

      return {
        data: buffer,
        mimeType: 'audio/mpeg',
        durationMs,
      };
    } catch (err) {
      if (err.response) {
        throw new Error(`Azure TTS error ${err.response.status}`);
      }
      throw err;
    }
  }

  async speechToText(audio, options = {}) {
    throw new Error('Azure ASR not configured in this provider. Use OpenAI Whisper.');
  }

  async evaluatePronunciation(text, audio) {
    // Azure 语音服务也支持发音评测，可作为讯飞的备选
    throw new Error('Azure pronunciation evaluation: not implemented yet.');
  }

  async ocrExtractWords(image) {
    throw new Error('Azure OCR not configured. Use Tencent Cloud OCR.');
  }
}

module.exports = { AzureProvider };
