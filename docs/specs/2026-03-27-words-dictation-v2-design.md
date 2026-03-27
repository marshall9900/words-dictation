# Words Dictation v2 — 全程语音驱动听写 App
**设计文档 | docs/superpowers/specs/2026-03-27-words-dictation-v2-design.md**

---

## 1. Concept & Vision

一款**全程无需触碰屏幕**的小学生英语单词听写工具。孩子通过语音与 App 交互：喊一声「小Wo同学」唤醒助手，然后说「开始听写」「下一题」「复读」等指令即可完成全部学习流程。

产品感觉是**一个贴心的AI学习伙伴**，不是冷冰冰的工具。语音反馈自然、鼓励积极、错误时温柔纠正。

---

## 2. Design Language

### 2.1 Aesthetic Direction
**风格：** 温暖童趣 + AI 科技感融合
- 主视觉：柔和渐变 + 圆润卡片，参考 Duolingo 的游戏化元素但更温和
- 圆角：20-24px（大面积圆角）
- 阴影：轻柔投影（blur 20-30, opacity 0.08-0.12）

### 2.2 Color Palette
```
Primary:     #6C63FF (活力紫)
Secondary:   #FF6584 (珊瑚粉)
Success:     #43D787 (薄荷绿)
Warning:     #FFB347 (暖橙)
Error:       #FF6B6B (柔红)
Background:  #F8F9FF (浅底)
Surface:     #FFFFFF (卡片白)
Text Dark:   #1A1A2E
Text Light:  #8E8E9A
```

### 2.3 Typography
- **标题/单词：** Google Fonts — Nunito（圆润童趣）
- **正文/UI：** System default (San Francisco / Roboto)
- **音标：** Noto Sans Mono

### 2.4 Motion Philosophy
- **状态切换：** 300ms ease-in-out（不唐突）
- **成功反馈：** 弹性动画 + 粒子效果（Lottie）
- **语音激活：** 呼吸灯效果（持续到指令执行）
- **错误提示：** 轻微抖动 + 颜色闪烁

---

## 3. Architecture

### 3.1 全局语音架构

```
┌─────────────────────────────────────────────────────┐
│                   VoiceAssistant                     │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ WakeWord │→ │ NLUC Engine  │→ │ IntentRouter │  │
│  │ Detector │  │ (MiniMax T2R)│  │              │  │
│  └──────────┘  └──────────────┘  └──────────────┘  │
│       ↑                                    │        │
│   唤醒词检测                         分发到各Handler │
└─────────────────────────────────────────────────────┘
       │                    │               │
   "小Wo同学"         MiniMax API      页面指令/操作
```

**唤醒词：** "小Wo同学"（可配置，暂不支持自定义，待 Phase 2）
**NLUC：** 语音 → text → MiniMax API → 结构化 Intent
**指令集：**
| 指令 | Intent | Action |
|------|--------|--------|
| "开始听写" / "听写" | `start_dictation` | 跳转听写页，启动第一个词 |
| "下一题" / "下一个" | `next_word` | 提交当前答案，进入下一题 |
| "复读" / "再说一遍" | `repeat_word` | TTS 重新朗读当前单词 |
| "打开错词本" | `open_wrong_words` | 跳转错词本页面 |
| "返回" / "上一页" | `go_back` | 返回上一级 |
| "再来一次" | `restart` | 重新开始当前听写 |
| "我答完了" / "提交" | `submit` | 提交当前输入 |

### 3.2 语音状态机

```
                    ┌──────────────────────────────────┐
                    │                                  │
                    ▼                                  │
           ┌──────────────────┐                         │
    ┌──────│   IDLE (待机)     │◄──────────┐          │
    │      └──────────────────┘           │          │
    │           ▲    │                    │          │
    │ WakeWord   │    │                   │          │
    │ (后台持续   │    │ Error/Timeout     │          │
    │  监听)     │    │                   │          │
    │           │    │                    │          │
    │  ┌────────┴────┴───┐                │          │
    │  │                  │                │          │
    │  │   LISTENING     │────────────────┘          │
    │  │  (等待指令)       │  (识别失败/超时30s)      │
    │  └──────────────────┘                          │
    │        │                                        │
    │   Intent OK                                     │
    │        │                                        │
    │        ▼                                        │
    │  ┌──────────────────┐                          │
    │  │  EXECUTING       │                          │
    │  │  (执行语音指令)   │──────────────────────────┘
    │  └──────────────────┘  (完成后回到 IDLE)
    │
    │  (听写进行中，始终保持唤醒状态，语音指令随时可触发)
```

### 3.3 App 页面结构

```
MainNavPage (底部 Tab，语音模式下也可语音切换)
├── HomePage (首页)
│   ├── 今日学习状态卡片
│   ├── 快速开始听写按钮
│   └── 近期错词提醒
├── DictationPage (听写页 - 核心页面)
│   ├── 单词朗读阶段 (TTS)
│   ├── 等待录音阶段 (麦克风)
│   ├── 评测结果阶段
│   └── 听写完成报告
├── WrongWordsPage (错词本)
│   ├── 艾宾浩斯复习列表
│   └── 错词详情
└── ProfilePage (个人页)
    ├── 学习统计
    └── 设置（音量/语音灵敏度/唤醒词开关）
```

### 3.4 技术栈

| Layer | Technology |
|-------|-----------|
| **Flutter App** | Flutter 3.x + GetX（状态管理/路由/依赖注入）|
| **Wake Word** | `speech_to_text` + 唤醒词模型（porcupine 或类似）|
| **NLUC** | MiniMax T2R API（语音→文字→Intent）|
| **TTS** | 现有 flutter_tts（本地）或 Azure TTS（Phase 2）|
| **Speech Recognition** | `speech_to_text` 本地兜底 + MiniMax API（Phase 2）|
| **Backend** | 现有 v2 后端（Node.js + Redis + MiniMax）|
| **Local DB** | sqflite（错词本/学习记录）|

### 3.5 后端 API 变更（需对齐 v2 后端）

现有 v2 后端已有以下路由，直接复用：
- `POST /api/v1/dictation/tasks` — 创建听写任务
- `POST /api/v1/evaluation` — 评测单词
- `GET /api/v1/wrongword` — 获取错词列表
- `POST /api/v1/achievement` — 成就系统

Flutter 侧需更新 `api_service.dart` 对齐 v2 接口。

---

## 4. 艾宾浩斯复习算法（真实现）

现有实现是假的（永远 +1 day），需要修正为标准 SM-2 算法：

```dart
/// 艾宾浩斯 SM-2 算法
/// quality: 0-5 (0=完全遗忘, 5=完美记住)
/// 返回: 下次复习日期
DateTime nextReviewDate(int quality, int repetitions, double easeFactor) {
  if (quality < 3) {
    // 失败：重新开始
    return DateTime.now().add(Duration(days: 1));
  }
  
  if (repetitions == 0) {
    return DateTime.now().add(Duration(days: 1));
  } else if (repetitions == 1) {
    return DateTime.now().add(Duration(days: 6));
  } else {
    return DateTime.now().add(Duration(days: (repetitions * easeFactor).round()));
  }
}
```

**关键：** 必须记录 `repetitions` 和 `easeFactor`，每次答题后更新。

---

## 5. 语音指令详细设计

### 5.1 唤醒词检测

**方案：** 使用 `speech_to_text` 的持续监听模式 + porcupine 唤醒词引擎
- porcupine 是在设备端运行的轻量唤醒词模型（隐私友好，延迟低）
- 唤醒成功 → 进入 LISTENING 状态
- 30s 无指令 → 自动退回 IDLE

**备选：** 如果 porcupine Flutter 绑定不稳定，使用纯 `speech_to_text` 的 `startListening` 持续监听，手动判断是否包含唤醒词。

### 5.2 指令解析流程

```
1. 用户说 "小Wo同学，我要听写"
2. 唤醒词检测触发（porcupine 或 stt）
3. 切换到 LISTENING 状态，呼吸灯动画
4. 发送语音到 MiniMax T2R API → "start_dictation"
5. IntentRouter 匹配到 start_dictation
6. 执行对应 Action（跳转 DictationPage，开始听写）
7. TTS 反馈："好的，开始听写，第一个词是..."
8. 回到 IDLE
```

### 5.3 听写流程中的语音操控

听写进行中，以下指令全程可用（无需唤醒词）：

| 指令 | 时机 | Action |
|------|------|--------|
| "下一题" | 等待录音/结果 | 跳转下一题 |
| "复读" / "再说一遍" | 任意 | TTS 复读当前单词 |
| "我答完了" | 录音中 | 提交当前录音 |
| "等等" / "等一下" | 任意 | 停止当前录音，等待 |
| "返回" | 任意 | 退出听写，返回首页 |
| "重新开始" | 结果阶段 | 重置当前题 |

---

## 6. 性能问题排查清单

### 6.1 待检测项（需真机测试）
- [ ] `speech_to_text` 在 iOS/Android 的首次初始化延迟
- [ ] 持续监听模式的电量消耗
- [ ] TTS 和 STT 同时运行时是否抢麦克风
- [ ] sqflite 在 Web 端的兼容问题（已知，try-catch 兜底）

### 6.2 已发现代码问题
1. **错误重置错词 count 逻辑**：`playError()` 里 `wrongCount: 1` 永远从 1 开始，未累加
2. **错误音效未添加**：`playSuccess()`/`playError()` 引用的 `assets/sounds/` 文件不存在
3. **缺少错误处理兜底**：`submitSpelling` 离线模式下调用本地 evaluator，但 `api_service.dart` 离线时抛异常直接被 catch 吞掉

---

## 7. Phase 规划

### Phase 1（本次重构）
- ✅ Flutter App 重建（对齐 v2 后端）
- ✅ 语音指令系统（唤醒词 + NLUC）
- ✅ 全程语音操控听写流程
- ✅ 艾宾浩斯 SM-2 真实现
- ✅ 错词本 + 复习提醒

### Phase 2（后续）
- Azure TTS 替换本地 TTS（更自然的儿童发音）
- 自定义唤醒词
- 学习数据可视化统计
- 成就/徽章系统

---

## 8. 目标用户专项

- **用户年龄：8岁（小学2-3年级）**
- TTS 语速：**0.4**（比标准 0.5 更慢，适合低龄儿童）
- UI 按钮和字体偏大（最小点击区域 48dp）
- 词库难度：对应小学课标词汇
- 反馈语言更鼓励性（「太棒了宝贝！」「加油，下次一定！」）

## 9. 新分支命名

建议：`refactor/voice-first` 或 `feature/voice-driven-dictation`

---
*本文档由 Superpowers brainstorming 生成 | 2026-03-27*
