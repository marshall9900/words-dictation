/**
 * 本地文件存储（开发/测试用）
 * 
 * 将文件保存到本地 uploads/ 目录，通过 Express static 提供访问
 */

const fs = require('fs').promises;
const path = require('path');
const { CloudStorage } = require('./base');
const axios = require('axios');

const UPLOAD_DIR = path.join(process.cwd(), 'uploads');
const LOCAL_BASE_URL = `http://localhost:${process.env.PORT || 3001}/uploads`;

class LocalStorage extends CloudStorage {
  constructor() {
    super('LocalStorage');
    this.baseDir = UPLOAD_DIR;
    this.baseUrl = process.env.LOCAL_STORAGE_URL || LOCAL_BASE_URL;
  }

  async _ensureDir(filePath) {
    const dir = path.dirname(filePath);
    await fs.mkdir(dir, { recursive: true });
  }

  async upload(data, remotePath, options = {}) {
    const key = remotePath.startsWith('/') ? remotePath.slice(1) : remotePath;
    const localPath = path.join(this.baseDir, key);
    await this._ensureDir(localPath);
    await fs.writeFile(localPath, data);
    return `${this.baseUrl}/${key}`;
  }

  async download(url) {
    if (url.startsWith('http')) {
      const res = await axios.get(url, { responseType: 'arraybuffer', timeout: 30000 });
      return Buffer.from(res.data);
    }
    // Local path
    return fs.readFile(url);
  }

  async getSignedUrl(remotePath, expireSeconds = 3600) {
    const key = remotePath.startsWith('/') ? remotePath.slice(1) : remotePath;
    return `${this.baseUrl}/${key}`;
  }

  async delete(remotePath) {
    const key = remotePath.startsWith('/') ? remotePath.slice(1) : remotePath;
    const localPath = path.join(this.baseDir, key);
    try {
      await fs.unlink(localPath);
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
    }
  }
}

module.exports = { LocalStorage };
