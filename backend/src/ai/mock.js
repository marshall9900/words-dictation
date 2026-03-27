/**
 * Mock AI Provider - 开发/测试用
 * 
 * 在未配置真实 API Key 时，返回模拟数据，保证开发流程可运行
 */

const { AIProvider } = require('./base');
const path = require('path');
const fs = require('fs');

class MockProvider extends AIProvider {
  constructor() {
    super('Mock');
  }

  async generateImage(prompt, options = {}) {
    console.log(`[MOCK] generateImage: "${prompt.substring(0, 50)}..."`);

    // 返回一个简单的 1x1 像素 JPEG（占位符）
    // 实际开发中可以返回测试图片文件
    const placeholderBuffer = Buffer.from(
      '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAwDAQACEQMRAD8AJQAB/9k=',
      'base64'
    );

    return {
      data: placeholderBuffer,
      mimeType: 'image/jpeg',
      width: options.width || 1024,
      height: options.height || 1024,
    };
  }

  async textToSpeech(text, options = {}) {
    console.log(`[MOCK] textToSpeech: "${text}"`);

    // 返回最小有效 MP3 文件（静音）
    const silentMp3 = Buffer.from(
      'SUQzBAAAAAAAI1RTU0UAAAAPAAADTGF2ZjU4LjI5LjEwMAAAAAAAAAAAAAAA//tQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWGluZwAAAA8AAAACAAADhgCenp6enp6enp6enp6enp6enp6enp6enp6enp6enp6enp6enp6e////////////////////////////////////////////////////////////////////////////////AAAAAExhdmM1OC41NC4xMDAAAAAAAAAAAAAAAAkAAAAAAAAAAAADhg==',
      'base64'
    );

    const wordCount = text.split(/\s+/).length;
    const durationMs = Math.round((wordCount / (120 * (options.speed || 0.9))) * 60 * 1000) + 500;

    return {
      data: silentMp3,
      mimeType: 'audio/mpeg',
      durationMs,
    };
  }

  async speechToText(audio, options = {}) {
    console.log(`[MOCK] speechToText`);
    return 'apple'; // 模拟识别结果
  }

  async evaluatePronunciation(text, audio) {
    console.log(`[MOCK] evaluatePronunciation: "${text}"`);
    const score = Math.floor(Math.random() * 30) + 70;
    return {
      score,
      integrity: Math.min(100, score + 5),
      fluency: Math.max(60, score - 5),
      accuracy: score,
      details: text.split('').map((ch) => ({
        phoneme: ch,
        score: Math.floor(Math.random() * 20) + 75,
      })),
      isMock: true,
    };
  }

  async ocrExtractWords(image) {
    console.log(`[MOCK] ocrExtractWords`);
    return ['apple', 'banana', 'cat', 'dog', 'elephant', 'flower', 'garden', 'house'];
  }
}

module.exports = { MockProvider };
