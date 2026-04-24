# 📱 时间规划 App

一个简洁的时间规划应用，支持日历视图、语音识别添加任务。

## 功能

- 📅 日历界面 — 按日期查看和管理任务
- 🎤 语音识别 — 说出任务自动添加（如"明天下午3点开会"）
- ✅ 任务管理 — 添加、完成、删除任务
- 💾 本地存储 — 数据持久化，不丢失
- 🌙 深色模式 — 跟随系统主题

## 技术栈

- Flutter 3.27.4
- Dart 3.6.2
- table_calendar / speech_to_text / shared_preferences

## 在 Windows 上开发

```bash
# 环境变量已配置，新终端直接用
cd D:\TaskPlanner
flutter pub get
flutter analyze
```

## 编译 iOS（无 Mac）

### 使用 GitHub Actions（推荐）

1. 在 GitHub 上创建一个新仓库（私有或公开都行）
2. 将此项目推送到 GitHub：
   ```bash
   cd D:\TaskPlanner
   git init
   git add .
   git commit -m "初始提交"
   git remote add origin https://github.com/你的用户名/仓库名.git
   git branch -M main
   git push -u origin main
   ```
3. 打开 GitHub 仓库页面 → **Actions** 标签 → 选择 **Build iOS App** → 点击 **Run workflow**
4. 等待约 10-15 分钟编译完成
5. 在编译结果页面下载 `ios-app` 压缩包，解压得到 `Payload/Runner.app`

> 💡 **提示**：编译出的 .app 文件未签名，无法直接安装到 iPhone。如需安装到真机，需要：
> - Apple Developer 账号（$99/年）
> - 或使用 AltStore / Sideloadly 等工具侧载
> - 或上传到 TestFlight 测试

## 免费额度说明

- GitHub Free 账户每月 200 分钟 macOS 编译时间
- 每次编译约 10-15 分钟，每月可编译约 13-20 次
- **公开仓库完全免费，无限制**

## 安装到 iPhone 的方法

1. **官方渠道**：注册 Apple Developer（$99/年）→ 通过 Xcode/Codemagic 签名 → TestFlight 或 App Store 分发
2. **侧载方式**（7天有效）：使用 AltStore 或 Sideloadly 安装未签名的 .ipa
3. **TestFlight 测试**（推荐）：通过 Apple Developer 邀请测试用户


---
编译触发测试
