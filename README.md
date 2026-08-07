# 纯白阅读 · 本地 TXT 阅读器（Flutter / Android）

一个**纯本地、零网络**的 Android TXT 阅读器：书架 → 阅读 → AI 离线听书。
全局纯白卡片风格，无书城、无广告、无多余干扰。

---

## 功能一览

- **书架主页**：标题“我的小说” + 右上角“+导入TXT”；书籍卡片显示书名、进度条、上次阅读时间。
- **导入**：调用系统文件管理器，仅显示 `.txt`，支持多选；自动识别 **UTF-8 / GBK** 编码。
- **阅读页**：大白卡黑字、舒适行距；**左右滑动仿真翻页**；点中部唤起控制栏；退出自动存档。
- **拖拽排序**：长按 1 秒放大进入拖拽，松手保存（持久化排序权重）。
- **删除**：卡片右上角 × 按钮，二次确认后删除。
- **AI 离线听书**：播放/暂停、上一段/下一段、后台 + 锁屏播放；倍速滑块 **1.0x~5.0x**（0.1x 步进，封顶 5.0x），**每本书独立记忆倍速**。
- **大文件**：整篇解码后按段落切分，阅读时只渲染邻近页（分段预加载）；智能分页不切字。

---

## 环境准备

1. 安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)（≥ 3.22，含 Dart 3）。
2. 安装 Android Studio + Android SDK（`minSdk` 需 ≥ 21，因后台音频服务要求）。
3. 配置好 `flutter doctor`（Android 工具链无报错）。

---

## 构建步骤

```bash
# 1) 进入项目目录
cd "阅读 app"

# 2) 生成 Android 平台脚手架（保留 lib/ 与 pubspec.yaml，不会删除你的代码）
flutter create .

# 3) 添加权限与 minSdk（见下方“Android 配置”）

# 4) 安装依赖
flutter pub get

# 5) 下载离线语音模型（生成 assets/tts-model/manifest.txt 与模型文件）
bash tools/download_tts_model.sh

# （无需手动改路径：tts_model_config.dart 会自动扫描模型目录，
#   下载任何中文 VITS 模型都能直接用。）

# 6) 运行 / 打包
flutter run                       # 连真机或模拟器
flutter build apk --split-per-abi # 产出 APK
```

---

## Android 配置（关键）

打开 `android/app/src/main/AndroidManifest.xml`：

1. 在 `<manifest>` 标签内（`<application>` 之外）添加权限：

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

2. 在 `android/app/build.gradle` 的 `defaultConfig` 中把最小 SDK 设为 21：

```groovy
defaultConfig {
    minSdk = 21
    // ...
}
```

（若 `flutter create .` 已生成该文件，按上面两处改即可。）

---

## 线上打包（GitHub Actions，本机零安装）

不想在本机装 Android Studio？仓库已内置 CI 工作流，让 GitHub 的云服务器帮你编译 APK：

1. 把代码推送到 GitHub（本仓库已配好 `origin`）。
2. 打开 **GitHub → 仓库 → Actions → Build APK**。
3. 点 **Run workflow**（或直接 push 到 main 就会自动触发）。
4. 跑完后，在 **Artifacts** 里下载 `txt-reader-apks`，里面是按架构拆分的 APK
   （`app-armeabi-v7a-release.apk` / `app-arm64-v8a-release.apk` / `app-x86_64-release.apk`）。
5. 把对应你手机架构的 APK（一般选 **arm64-v8a**）传到手机安装即可。

> CI 里会自动完成：生成 Android 脚手架 → 补权限/minSdk/锁屏音频服务
> （`tools/patch_android.py`）→ 下载离线 TTS 模型打包进 APK → `flutter build apk`。
> 即使模型下载失败，APK 仍会正常产出，只是听书功能暂时不可用。

---

## 目录结构

```
lib/
├── main.dart                  # 入口：初始化存储/TTS/音频，纯白主题
├── app_config.dart            # 全局音频处理器
├── core/{theme,constants}.dart
├── models/book.dart           # Book 模型 + 手写 Hive 适配器
├── data/book_store.dart       # 本地存储（增删改查 + 排序持久化）
├── services/
│   ├── txt_importer.dart      # 多选导入 + 编码识别
│   ├── txt_loader.dart        # 解码 + 段落切分
│   ├── paginator.dart         # 智能分页（不切字）
│   ├── wav_encoder.dart       # Float32 -> WAV
│   ├── tts_model_config.dart  # 自动识别模型文件（无需手改）
│   ├── tts_service.dart       # sherpa_onnx 离线合成
│   └── audio_player.dart      # audio_service + just_audio 后台/锁屏
├── providers/reader_provider.dart
├── widgets/
│   ├── book_card.dart
│   ├── reader_control_bar.dart
│   ├── tts_floating_card.dart
│   └── page_turn_reader.dart  # 仿真翻页
└── pages/{shelf_page,reader_page}.dart
```

---

## 可能需要的微调（编译期）

- **sherpa_onnx TTS API**：不同版本 `generate` 的参数形式可能不同。本项目用命名参数
  `tts.generate(text: text, sid: 0, speed: speed)`；若你安装的版本要求位置参数，
  改为 `tts.generate(text, 0, speed)`（见 `lib/services/tts_service.dart` 注释）。
  模型字段（model/tokens/lexicon/dataDir/dictDir）以官方
  `example/lib/model.dart` 为准，在 `tts_model_config.dart` 调整。
- **模型体积**：离线语音模型会让 APK 增大几十 MB，这是“集成离线语音包”的必然代价；
  可换更小的模型以缩减体积。

---

## 说明与边界

- 本工程**不含任何网络请求**，所有功能离线可用。
- 锁屏/通知栏控制依赖 Android MediaSession（audio_service），在 Android 锁屏生效。
- “长按弹删除”与“长按拖拽排序”手势冲突，已改为卡片右上角 × 按钮删除（更稳定）。
- 数据层使用 Hive（无需 `build_runner` 代码生成）。
