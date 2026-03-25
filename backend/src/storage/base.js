/**
 * Cloud Storage 抽象基类
 * 
 * 所有存储实现必须继承并实现这些方法
 */

class CloudStorage {
  constructor(name) {
    this.name = name;
  }

  /**
   * 上传文件
   * @param {Buffer} data - 文件内容
   * @param {string} remotePath - 存储路径（如 /picturebook/word_id/frame_01.jpg）
   * @param {object} options
   * @param {string} [options.contentType] - MIME 类型
   * @param {boolean} [options.public=true] - 是否公开访问
   * @returns {Promise<string>} CDN URL
   */
  async upload(data, remotePath, options = {}) {
    throw new Error(`${this.name}.upload() not implemented`);
  }

  /**
   * 下载文件
   * @param {string} url - 文件 URL 或路径
   * @returns {Promise<Buffer>}
   */
  async download(url) {
    throw new Error(`${this.name}.download() not implemented`);
  }

  /**
   * 获取临时签名 URL（用于私有文件）
   * @param {string} remotePath - 存储路径
   * @param {number} [expireSeconds=3600] - 有效期（秒）
   * @returns {Promise<string>} 签名 URL
   */
  async getSignedUrl(remotePath, expireSeconds = 3600) {
    throw new Error(`${this.name}.getSignedUrl() not implemented`);
  }

  /**
   * 删除文件
   * @param {string} remotePath
   * @returns {Promise<void>}
   */
  async delete(remotePath) {
    throw new Error(`${this.name}.delete() not implemented`);
  }

  /**
   * 批量上传（并行）
   * @param {Array<{data: Buffer, path: string, options?: object}>} files
   * @returns {Promise<string[]>} CDN URLs
   */
  async uploadBatch(files) {
    return Promise.all(files.map(f => this.upload(f.data, f.path, f.options || {})));
  }
}

module.exports = { CloudStorage };
