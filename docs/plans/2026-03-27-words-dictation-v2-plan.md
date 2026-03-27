# Words Dictation v2 — 实施计划
**docs/superpowers/plans/2026-03-27-words-dictation-v2-plan.md**
*基于设计文档 | 2026-03-27*

---

## 📋 计划概要

| 阶段 | 任务数 | 核心目标 |
|------|--------|---------|
| **A. 项目骨架** | 3 | Flutter v2 项目结构重建、对齐 v2 后端 API |
| **B. 语音系统** | 4 | WakeWord 检测器、NLUC Intent 路由、VoiceAssistant 全局服务 |
| **C. 听写流程** | 5 | 状态机重构、语音操控听写全流程、TTS 调优 |
| **D. 错词本 & 艾宾浩斯** | 3 | SM-2 真算法、错词积累 bug 修复、复习提醒 |
| **E. 已知 Bug Fix** | 3 | 音效文件缺失、错误计数器、离线兜底逻辑 |
| **F. 验证 & 上线** | 2 | 真机测试检查清单、合并 PR |

---

## 阶段 A：项目骨架重建

### A1. Flutter v2 项目结构初始化
**目录：** `src/words-dictation-v2/app/`
**依赖：** `speech_to_text`, `flutter_tts`, `get`, `dio`, `sqflite`, `audioplayers`, `shared_preferences`

```
app/lib/
├── main.dart                      # 入口（保持现有）
├── core/
│   ├── voice/
│   │   ├── wake_word_detector.dart   # 唤醒词检测（porcupine 或 stt 兜底）
│   │   ├── nluc_engine.dart          # MiniMax T2R 语音→Intent
│   │   ├── voice_assistant.dart      # 全局语音助手（状态机）
│   │   └── intent_handlers/          # 各指令 Handler
│   ├── constants.dart
│   └── theme.dart
├── pages/
│   ├── home_page.dart
│   ├── dictation_page.dart
│   ├── wrong_words_page.dart
│   └── profile_page.dart
├── services/
│   ├── api_service.dart           # 对齐 v2 后端 API
│   ├── audio_service.dart         # TTS 调优（语速 0.4）
│   └── local_db_service.dart      # sqflite + 艾宾浩斯
├── models/
│   └── models.dart
└── utils/
    ├── spelling_evaluator.dart
    └── sm2_scheduler.dart         # 艾宾浩斯 SM-2
```

**A1 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 `VoiceAssistant` 状态机初始状态为 `idle`
- [ ] **GREEN**：创建空 `VoiceAssistant` 类和状态枚举
- [ ] **REFACTOR**：抽离 `WakeWordDetector` 接口

---

### A2. API Service 对齐 v2 后端
**文件：** `services/api_service.dart`
**变更：**
- baseURL 改为 `http://localhost:3001/api/v1`（或环境变量）
- 对齐 v2 后端路由：
  - `POST /api/v1/dictation/tasks` — 创建听写任务
  - `POST /api/v1/evaluation` — 评测
  - `GET /api/v1/wrongword` — 错词列表
  - `POST /api/v1/wrongword` — 添加错词
  - `PATCH /api/v1/wrongword/:id` — 更新复习时间
- 离线兜底：`catch` 不能吞异常，需回退到本地 `SpellingEvaluator`

**A2 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 API 离线时 `evaluateSpelling` 抛出异常被正确捕获并回退
- [ ] **GREEN**：实现带离线兜底的 `ApiService`
- [ ] **REFACTOR**：抽离 `EvaluationResult` 模型

---

### A3. Local DB Service 艾宾浩斯数据模型
**文件：** `services/local_db_service.dart`
**变更：**
- `WrongWord` 表新增字段：`repetitions` (int), `easeFactor` (double)
- 初始化 SQL 迁移脚本（v1 → v2 兼容）

**A3 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证新字段存在且默认值正确
- [ ] **GREEN**：添加字段，更新 `WrongWord` 模型
- [ ] **REFACTOR**：编写 `addWrongWord()` 和 `updateWrongWord()` 事务

---

## 阶段 B：语音系统

### B1. WakeWordDetector — 唤醒词检测
**文件：** `core/voice/wake_word_detector.dart`
**实现：**
- 优先尝试 `pv_porcupine`（端侧唤醒词检测，Flutter 绑定：`pinecorn` 或 `porcupine_flutter`）
- Fallback：纯 `speech_to_text` 持续监听 + 关键词匹配（"小Wo同学"）
- 对外接口：
  ```dart
  abstract class WakeWordDetector {
    Stream<bool> get wakeWordStream; // true = 检测到唤醒词
    Future<void> start();
    Future<void> stop();
    void dispose();
  }
  ```

**B1 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写 mock 测试验证 `wakeWordStream` 接收到 true 后触发监听
- [ ] **GREEN**：实现 `SttWakeWordDetector`（speech_to_text fallback）
- [ ] **REFACTOR**：预留 `PvPorcupineDetector` 接口，porcupine SDK 就绪时可替换

---

### B2. NLUEngine — MiniMax T2R 语音→Intent
**文件：** `core/voice/nluc_engine.dart`
**实现：**
- 调用 MiniMax T2R API（`POST /v1/text/to_text`）将语音转为文字指令
- 本地关键词兜底：解析文字指令匹配预定义 Intent（离线可用）
- Intent 列表：`start_dictation`, `next_word`, `repeat_word`, `open_wrong_words`, `go_back`, `restart`, `submit`

```dart
enum VoiceIntent {
  unknown,
  startDictation,
  nextWord,
  repeatWord,
  openWrongWords,
  goBack,
  restart,
  submit,
}
```

**B2 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 "开始听写" 解析为 `startDictation`
- [ ] **GREEN**：实现带离线兜底的 `NLUEngine`
- [ ] **REFACTOR**：分离 `RemoteNLU` 和 `LocalNLU`

---

### B3. VoiceAssistant — 全局语音状态机
**文件：** `core/voice/voice_assistant.dart`
**实现：**（状态机见设计文档 Section 3.2）
- 4 个状态：`idle`, `listening`, `executing`, `dictation_mode`
- 对外接口：
  ```dart
  VoiceAssistant.startListening();   // 开始监听指令
  VoiceAssistant.executeIntent(VoiceIntent intent);  // 执行指令
  VoiceAssistant.get state;          // 当前状态
  ```
- 广播状态变更：`Rx<VoiceAssistantState>`

**B3 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 idle → listening → executing → idle 状态转换
- [ ] **GREEN**：实现 `VoiceAssistant` 状态机
- [ ] **REFACTOR**：各状态 UI 响应逻辑抽离为 `VoiceAssistantBuilder`

---

### B4. IntentHandlers — 语音指令处理器
**文件：** `core/voice/intent_handlers/`
**每个 Handler：**
- `StartDictationHandler` — 跳转听写页，开始第一个词，TTS 反馈
- `NextWordHandler` — 调用 `DictationController.nextWord()`
- `RepeatWordHandler` — 调用 TTS 复读
- `OpenWrongWordsHandler` — 跳转错词本
- `GoBackHandler` — 调用 `Get.back()`
- `RestartHandler` — 重置当前题

**B4 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 `StartDictationHandler` 调用后跳转到 DictationPage
- [ ] **GREEN**：实现各 Handler
- [ ] **REFACTOR**：抽取 `IntentHandler` 接口规范

---

## 阶段 C：听写流程重构

### C1. DictationController — 语音驱动状态机
**文件：** `pages/dictation_page.dart`（重构）
**变更：**
- 新增状态：`DictationState.listening`（等待语音指令）
- 集成 `VoiceAssistant`，听写全程可响应语音指令
- `submitSpelling`：语音识别完成后自动提交，无需手动触发
- `nextWord`：结果页语音指令"下一题"直接调用

**C1 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证"复读"指令在任意听写状态下可触发 TTS
- [ ] **GREEN**：重构 `DictationController` + `VoiceAssistant` 集成
- [ ] **REFACTOR**：把 UI 构建部分抽离为纯展示组件

---

### C2. 听写全流程语音操控（端到端）
**覆盖场景：**
1. 首页说"小Wo同学，开始听写" → 跳转听写页 → TTS 朗读第一个词
2. 录音中说"下一题" → 停止录音 → 提交 → 下一题
3. 结果页说"复读" → TTS 重读当前单词
4. 任意页说"打开错词本" → 跳转错词本
5. 任意页说"返回" → 返回上一页

**C2 任务（端到端人工测试）：**
- [ ] 测试用例 1-5 全部通过

---

### C3. TTS 调优（8岁儿童）
**文件：** `services/audio_service.dart`
**变更：**
- `setSpeechRate(0.4)` — 原 0.5，改为更慢
- `setPitch(1.0)` — 保持正常音调
- 新增 `speakEncouragement(String message)` — 播放鼓励语（"太棒了宝贝！"）
- 新增 `speakWrongFeedback(String word)` — 错误后 TTS 温柔纠正

**C3 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 TTS 语速为 0.4
- [ ] **GREEN**：更新 `AudioService` 配置
- [ ] **REFACTOR**：提取 `KidTts` 子类，封装儿童友好 TTS

---

### C4. DictationPage UI — 语音激活状态展示
**文件：** `pages/dictation_page.dart` UI 部分
**变更：**
- 底部常驻**呼吸灯麦克风图标**（表示语音助手在线）
- 状态为 `listening` 时：呼吸灯高亮 + "我在听..." 提示
- 识别到指令后：短暂闪烁确认动画
- 移除所有不必要的点按提示（语音模式下不需要）

**C4 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证麦克风图标在语音激活时高亮
- [ ] **GREEN**：实现呼吸灯动画组件
- [ ] **REFACTOR**：抽离为 `VoiceIndicator` 组件

---

### C5. 结果页鼓励语言（8岁儿童）
**文件：** `pages/dictation_page.dart` `_buildResultView`
**变更：**
- 答对：TTS "太棒了宝贝！" + 🎉 + 分数
- 答错：TTS "没关系，下次一定行！" + 正确答案 + 发音示范
- 整体报告：TTS 读出正确率

**C5 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证错词反馈 TTS 包含正确答案
- [ ] **GREEN**：实现儿童友好反馈文案
- [ ] **REFACTOR**：文案抽离到 `EncouragementStrings` 常量类

---

## 阶段 D：错词本 & 艾宾浩斯

### D1. SM-2 艾宾浩斯调度器
**文件：** `utils/sm2_scheduler.dart`
**实现：**（见设计文档 Section 4）
```dart
class SM2Result {
  final DateTime nextReviewDate;
  final int repetitions;
  final double easeFactor;
}

SM2Result calculateSM2({
  required int quality,       // 0-5 评测质量
  required int repetitions,    // 当前连续正确次数
  required double easeFactor,   // 当前 EF
}) {
  // SM-2 标准算法
}
```

**D1 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证：quality=5 连续3次 → 下次复习约21天后
- [ ] **GREEN**：实现 `SM2Scheduler`
- [ ] **REFACTOR**：与 SQLite 数据存储解耦

---

### D2. 错词本页面 & 复习提醒
**文件：** `pages/wrong_words_page.dart`
**变更：**
- 按「今日待复习」和「未来复习」分组
- 点击单词 → 播放发音 + 显示释义
- 「复习」按钮 → 发起一轮听写（只包含待复习词）
- 复习完成 → 更新 `nextReviewAt`（调用 SM-2）

**D2 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证今日待复习词列表正确筛选
- [ ] **GREEN**：实现复习分组和提醒 UI
- [ ] **REFACTOR**：错词数据查询抽离为 `WrongWordRepository`

---

### D3. 错词计数器 Bug 修复
**文件：** `pages/dictation_page.dart` — `submitSpelling`
**Bug：** `WrongWord(wrongCount: 1)` 永远从 1 开始
**修复：** 查询已存在错词，累加而非重置

**D3 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证同一词第二次答错 → wrongCount = 2
- [ ] **GREEN**：修复累加逻辑
- [ ] **REFACTOR**：抽离 `WrongWordService.addOrUpdateWrongWord()`

---

## 阶段 E：已知 Bug 修复

### E1. 音效文件补全
**文件：** `services/audio_service.dart` — `playSuccess()` / `playError()`
**Bug：** `assets/sounds/success.mp3` 和 `error.mp3` 不存在
**修复：**
- 方案A：添加简单系统音效（Android/iOS 系统提示音）
- 方案B：添加免费授权音效文件（如 Mixkit 免费音效）

**E1 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 `playSuccess()` 不抛异常
- [ ] **GREEN**：添加音效文件或系统兜底
- [ ] **REFACTOR**：抽离 `SfxPlayer` 服务

---

### E2. API 离线异常处理
**文件：** `services/api_service.dart`
**Bug：** `catch (_) { ... }` 吞掉所有异常，离线时静默失败
**修复：** 分类异常（网络超时 vs 服务器错误 vs 解析错误），离线回退到本地 evaluator

**E2 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试模拟网络超时 → 验证返回本地评测结果
- [ ] **GREEN**：完善异常分类和回退逻辑
- [ ] **REFACTOR**：添加 `ApiException` 自定义异常类

---

### E3. TTS 和 STT 麦克风冲突
**Bug：** TTS 播放时 STT 可能无法录音
**修复：** TTS 播放前检查 `speechAvailable`，播放完成后再启动录音；使用 `audioService.isSpeaking` RxBool

**E3 任务（RED→GREEN→REFACTOR）：**
- [ ] **RED**：写测试验证 TTS 播放期间不响应录音指令
- [ ] **GREEN**：实现 `AudioService.isSpeaking` 守卫
- [ ] **REFACTOR**：抽离 `MicrophoneLock` 互斥锁服务

---

## 阶段 F：验证 & 上线

### F1. 真机测试检查清单
**测试设备：** Android + iOS 各一台

| # | 检查项 | 预期 |
|---|--------|------|
| 1 | 唤醒词 "小Wo同学" 识别率 | 3次中至少2次 |
| 2 | 安静环境下语音指令识别率 | 5次指令至少4次正确 |
| 3 | 听写流程（全程语音）完整体验 | 无需触碰屏幕 |
| 4 | 错词本艾宾浩斯复习日期 | 与 SM-2 计算一致 |
| 5 | 离线模式下听写可用 | TTS 朗读 + 本地评测 |
| 6 | 电量消耗（30分钟持续唤醒） | < 5% 电量 |

**F1 输出：** `project-docs/test-reports/2026-03-27-voice-dictation-test-report.md`

---

### F2. Git 分支 & PR
**分支：** `refactor/voice-first`（从 `main` 或 `master`）
**PR 内容：**
- Phase 1 全部完成
- 通过全部 TDD 测试
- 真机测试通过

**F2 任务：**
- [ ] 创建 `refactor/voice-first` 分支
- [ ] 提交全部变更
- [ ] 发起 PR → main
- [ ] 通知 Marshal 评审

---

## 📊 任务汇总

| 阶段 | 任务 | TDD 循环 |
|------|------|---------|
| A1 | Flutter v2 骨架 | RED→GREEN→REFACTOR |
| A2 | API Service 对齐 | RED→GREEN→REFACTOR |
| A3 | DB 艾宾浩斯字段 | RED→GREEN→REFACTOR |
| B1 | WakeWordDetector | RED→GREEN→REFACTOR |
| B2 | NLU Engine | RED→GREEN→REFACTOR |
| B3 | VoiceAssistant | RED→GREEN→REFACTOR |
| B4 | Intent Handlers | RED→GREEN→REFACTOR |
| C1 | DictationController 重构 | RED→GREEN→REFACTOR |
| C2 | 端到端语音操控 | 人工测试 |
| C3 | TTS 调优（0.4语速） | RED→GREEN→REFACTOR |
| C4 | 呼吸灯 UI | RED→GREEN→REFACTOR |
| C5 | 儿童鼓励语言 | RED→GREEN→REFACTOR |
| D1 | SM-2 调度器 | RED→GREEN→REFACTOR |
| D2 | 错词本复习 | RED→GREEN→REFACTOR |
| D3 | 错词计数器 | RED→GREEN→REFACTOR |
| E1 | 音效补全 | RED→GREEN→REFACTOR |
| E2 | API 离线异常 | RED→GREEN→REFACTOR |
| E3 | TTS/STT 互斥 | RED→GREEN→REFACTOR |
| F1 | 真机测试 | 人工测试 |
| F2 | Git PR | — |

**合计：16 个 TDD 任务 + 2 个端到端人工测试 + 1 个 PR**

---
*本文档由 Superpowers writing-plans 生成 | 2026-03-27*
