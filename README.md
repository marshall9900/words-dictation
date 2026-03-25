# Words Dictation v2

> 小学生单词听写工具 —— Phase 1：AI 动态绘本（图片+配音）

## 架构概览

```
words-dictation-v2/
├── backend/          # Node.js + Express 后端
│   └── src/
│       ├── ai/       # AI Provider 抽象层
│       │   ├── base.js       # 抽象基类（AIProvider）
│       │   ├── minimax.js    # MiniMax 实现（图片+TTS）
│       │   ├── azure.js      # Azure TTS（单词朗读，Phase 2）
│       │   ├── mock.js       # Mock（开发测试）
│       │   └── index.js      # Provider 注册表（工厂模式）
│       ├── storage/  # Cloud Storage 抽象层
│       │   ├── base.js       # 抽象基类（CloudStorage）
│       │   ├── cos.js        # 腾讯云 COS 实现
│       │   ├── local.js      # 本地存储（开发）
│       │   └── index.js      # Storage 注册表
│       ├── services/
│       │   └── picturebook.js  # 动态绘本生成核心逻辑
│       ├── queue/
│       │   ├── picturebook.js  # Bull 队列（异步生成）
│       │   └── worker.js       # 队列 Worker
│       ├── routes/
│       │   ├── picturebook.js  # 绘本 API 路由
│       │   ├── user.js
│       │   ├── dictation.js
│       │   ├── evaluation.js
│       │   ├── wrongword.js
│       │   └── achievement.js
│       ├── middleware/
│       │   └── auth.js         # JWT 认证
│       ├── config/
│       │   └── redis.js        # Redis 客户端
│       ├── db/
│       │   ├── index.js        # MySQL 连接池
│       │   └── migrate.js      # 数据库迁移
│       └── index.js            # 服务入口
├── app/              # Flutter 前端
│   └── lib/
│       ├── models/
│       │   └── models.dart           # 数据模型
│       ├── services/
│       │   ├── api_service.dart      # API 封装
│       │   └── picturebook_controller.dart  # GetX 控制器
│       ├── pages/
│       │   └── picture_book_page.dart  # 绘本播放页面
│       └── main.dart
└── docker-compose.yml
```

## 核心设计

### AI Provider 抽象层

```javascript
// 可插拔接口
class AIProvider {
  async generateImage(prompt, options)      // 图片生成
  async textToSpeech(text, options)         // TTS 配音
  async speechToText(audio, options)        // ASR 识别
  async evaluatePronunciation(text, audio)  // 发音评测
  async ocrExtractWords(image)              // OCR 识别
}

// 实现：MiniMax（Phase 1 图片+TTS）
// 实现：Azure（Phase 2 单词朗读）
// 实现：Mock（开发测试，无需 API Key）
```

### Cloud Storage 抽象层

```javascript
class CloudStorage {
  async upload(data, path, options)      // 上传
  async download(url)                    // 下载
  async getSignedUrl(path, expires)      // 签名 URL
  async delete(path)                     // 删除
  async uploadBatch(files)               // 批量并行上传
}

// 实现：TencentCloudCOS（生产）
// 实现：LocalStorage（开发，自动 fallback）
```

### 动态绘本生成流程

```
拆分讲解文字（N段）
       ↓
并行生成 N 张图片（MiniMax Image）
并行生成 N 段配音（MiniMax TTS）
       ↓
组装时间轴 JSON
       ↓
上传 COS（或本地）
       ↓
写数据库 → 返回 CDN URL + 时间轴
```

### 产品分层

| 功能 | 免费 | 付费 |
|------|------|------|
| 图片+配音绘本 | ✅ 无限次 | ✅ |
| 视频生成 | ❌ | ✅（Phase 2） |

## 快速启动

### 1. 配置环境变量

```bash
cd backend
cp .env.example .env
# 编辑 .env，至少配置：
# MINIMAX_API_KEY=xxx
# MINIMAX_GROUP_ID=xxx
# （不配置则自动使用 Mock 模式）
```

### 2. Docker 启动

```bash
# 在 words-dictation-v2/ 目录
docker-compose up -d

# 等待数据库就绪后执行迁移
docker-compose exec backend node src/db/migrate.js
```

### 3. 本地开发启动

```bash
cd backend
npm install
npm run migrate   # 先确保 MySQL 和 Redis 已启动
npm run dev       # 启动 API 服务（端口 3001）
npm run worker    # 启动队列 Worker（另开终端）
```

### 4. Flutter 前端

```bash
cd app
flutter pub get
flutter run
```

## API 文档

### 生成动态绘本

```http
POST /api/v1/picturebook/generate
Authorization: Bearer <token>

{
  "wordId": "uuid",
  "word": "apple",
  "explanation": "An apple is a round red fruit...",
  "async": true
}
```

**响应（异步模式）：**
```json
{
  "success": true,
  "jobId": "xxx",
  "statusUrl": "/api/v1/picturebook/job/xxx"
}
```

### 查询任务状态

```http
GET /api/v1/picturebook/job/:jobId
```

### 获取绘本详情

```http
GET /api/v1/picturebook/:id
```

**响应：**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "word": "apple",
    "timeline": {
      "frames": [
        {
          "index": 0,
          "text": "This is an apple...",
          "image": "https://cdn.xxx/frame_01.jpg",
          "audio": "https://cdn.xxx/voice_01.mp3",
          "durationMs": 4200
        }
      ],
      "totalDurationMs": 12600
    }
  }
}
```

## 环境变量说明

| 变量 | 说明 | 必须 |
|------|------|------|
| `MINIMAX_API_KEY` | MiniMax API Key | Phase 1 核心 |
| `MINIMAX_GROUP_ID` | MiniMax Group ID | Phase 1 核心 |
| `TENCENT_SECRET_ID` | 腾讯云 SecretId | 生产环境 |
| `COS_BUCKET` | COS Bucket 名 | 生产环境 |
| `CDN_BASE_URL` | CDN 域名 | 生产环境 |

> 💡 不配置 MINIMAX_API_KEY，系统自动使用 **MockProvider**（返回占位图和静音音频），开发流程完整可运行。
> 不配置 COS，系统自动使用 **LocalStorage**（保存到 ./uploads/），通过 Express static 提供访问。
