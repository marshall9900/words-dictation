/**
 * 腾讯云 COS 存储实现
 * 
 * 使用 cos-nodejs-sdk-v5
 */

const COS = require('cos-nodejs-sdk-v5');
const axios = require('axios');
const { CloudStorage } = require('./base');

class TencentCloudCOS extends CloudStorage {
  constructor() {
    super('TencentCloudCOS');
    this.bucket = process.env.COS_BUCKET;
    this.region = process.env.COS_REGION || 'ap-guangzhou';
    this.cdnBaseUrl = process.env.CDN_BASE_URL;

    if (process.env.TENCENT_SECRET_ID && process.env.TENCENT_SECRET_KEY) {
      this.cos = new COS({
        SecretId: process.env.TENCENT_SECRET_ID,
        SecretKey: process.env.TENCENT_SECRET_KEY,
        Timeout: 60000,
      });
    }
  }

  _checkConfig() {
    if (!this.cos) {
      throw new Error('Tencent COS credentials not configured (TENCENT_SECRET_ID, TENCENT_SECRET_KEY)');
    }
    if (!this.bucket) {
      throw new Error('COS_BUCKET not configured');
    }
  }

  /**
   * 上传文件到 COS
   * @returns {Promise<string>} CDN URL
   */
  async upload(data, remotePath, options = {}) {
    this._checkConfig();

    // 确保路径以 / 开头
    const key = remotePath.startsWith('/') ? remotePath.slice(1) : remotePath;

    return new Promise((resolve, reject) => {
      this.cos.putObject(
        {
          Bucket: this.bucket,
          Region: this.region,
          Key: key,
          Body: data,
          ContentType: options.contentType || 'application/octet-stream',
          ACL: options.public !== false ? 'public-read' : 'private',
        },
        (err, result) => {
          if (err) {
            reject(new Error(`COS upload failed: ${err.message}`));
            return;
          }
          // 返回 CDN URL
          const url = this.cdnBaseUrl
            ? `${this.cdnBaseUrl}/${key}`
            : `https://${this.bucket}.cos.${this.region}.myqcloud.com/${key}`;
          resolve(url);
        }
      );
    });
  }

  /**
   * 下载文件
   */
  async download(url) {
    const res = await axios.get(url, { responseType: 'arraybuffer', timeout: 30000 });
    return Buffer.from(res.data);
  }

  /**
   * 获取临时签名 URL（私有文件访问）
   */
  async getSignedUrl(remotePath, expireSeconds = 3600) {
    this._checkConfig();

    const key = remotePath.startsWith('/') ? remotePath.slice(1) : remotePath;

    return new Promise((resolve, reject) => {
      this.cos.getObjectUrl(
        {
          Bucket: this.bucket,
          Region: this.region,
          Key: key,
          Expires: expireSeconds,
          Sign: true,
        },
        (err, data) => {
          if (err) reject(err);
          else resolve(data.Url);
        }
      );
    });
  }

  /**
   * 删除文件
   */
  async delete(remotePath) {
    this._checkConfig();

    const key = remotePath.startsWith('/') ? remotePath.slice(1) : remotePath;

    return new Promise((resolve, reject) => {
      this.cos.deleteObject(
        {
          Bucket: this.bucket,
          Region: this.region,
          Key: key,
        },
        (err, result) => {
          if (err) reject(new Error(`COS delete failed: ${err.message}`));
          else resolve();
        }
      );
    });
  }

  /**
   * 批量并行上传（覆盖基类提高效率）
   * COS SDK 本身支持并发，这里直接并行
   */
  async uploadBatch(files) {
    return Promise.all(files.map(f => this.upload(f.data, f.path, f.options || {})));
  }
}

module.exports = { TencentCloudCOS };
