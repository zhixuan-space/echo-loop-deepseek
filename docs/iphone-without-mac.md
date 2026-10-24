# 没有 Mac：云端编译，再用 Windows 安装

个人版已上传到公开仓库 [zhixuan-space/echo-loop-deepseek](https://github.com/zhixuan-space/echo-loop-deepseek)。
首次成功的 [iPhone 云构建](https://github.com/zhixuan-space/echo-loop-deepseek/actions/runs/39932561903)
于 2026-10-23 完成，源码提交为 `11cd350d5aa41ea14e9888a210a8db2f13ef3baa`。
产物为 `Echo-Loop-DeepSeek-unsigned.ipa`，需要自行签名后安装。
已下载检查：62,372,459 字节，ZIP 完整性通过，iPhone ARM64，最低 iOS 15.0，
包含个人 DeepSeek 功能代码；SHA-256 为
`b4fb87463e9844d34988cf15d9ea0fae308007ccf7ee5ae80710cb345eb2bda8`。

## 下载与重新构建

在上述成功运行页面底部的 **Artifacts** 中，下载
**Echo-Loop-DeepSeek-unsigned-iPhone**，解压得到 `.ipa`。
下载需要登录 GitHub；本次云端产物于 2026-10-30 到期，已下载到电脑的文件不受此限制。

GitHub 标准 macOS 托管 runner 在公开仓库中免费使用；私有仓库使用账户额度，
超额可能计费。仓库公开范围应由你选择。

## 云端构建

1. 打开自己的仓库，保留 `.github/workflows/personal-ios.yml`。
2. 打开仓库的 Actions 页面，选择 **Personal iPhone build**。
3. 点击 **Run workflow**，选择包含修改代码的分支，运行。
4. 成功后，在该次运行的 Artifacts 中下载
   **Echo-Loop-DeepSeek-unsigned-iPhone**，解压得到 `.ipa`。

工作流在 macOS 15 上使用 Flutter 3.47.7 构建 `prod` flavor，关闭代码签名，
将真实 iPhone `.app` 包装为 IPA。已有代码生成产物保留在源码中。
流程只需要仓库读取权限，不要求 Apple 证书、Apple ID 或 DeepSeek Key。
IPA 构建产物保留 7 天。它不会上传 App Store Connect、TestFlight 或 GitHub Release。

## 在 Windows 上安装

1. 按 [AltStore Classic 的 Windows 官方说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)，
   安装 Apple 官网版 iTunes、iCloud，再安装 AltServer for Windows。
   已有 Microsoft Store 版 iCloud 时，先查看官方文档提供的兼容步骤。
2. 用数据线连接并解锁 iPhone，在手机上选择「信任此电脑」；在 iTunes 中启用 Wi-Fi 同步。
3. 从 Windows 右下角 AltServer 图标选择 **Install AltStore → 你的 iPhone**，
   在安装工具中输入自己的 Apple ID，按提示完成验证。
4. 在手机「设置 → 通用 → VPN 与设备管理」信任对应开发者。
   iOS 16 及以后还需在「设置 → 隐私与安全 → 开发者模式」开启并按提示重启。
5. 将 `.ipa` 通过你常用的文件传输方式放进 iPhone 的「文件」App。
   在 AltStore Classic 的 **My Apps** 页面点击 **+**，选择该 IPA，保持 AltServer 运行并完成安装。

IPA 未签名，不能在 iPhone 文件 App 中直接点开安装；签名由安装工具使用你的
Apple 账号完成。普通 Apple ID 通常需要每 7 天刷新，且存在同时安装数量限制。
没有实际在目标手机测试前，不能保证该 IPA 的全部插件和本地识别都正常。
Apple ID 密码只在安装工具的登录界面输入；DeepSeek Key 只在应用设置中输入。

## 首次使用

打开应用 → 设置 → 个人 AI · DeepSeek → 填写 API Key、模型名称 →
测试连接 → 开启并保存。模型名应以你账户可用的 ID 为准。
本地字幕在材料的「管理字幕 → 离线转录」中下载并选择 Whisper 模型。

## 当前验证范围

已检查 workflow YAML、Bash 语法、手动触发及只读权限。
GitHub macOS runner 已完成依赖安装、iPhone release 编译、IPA 打包和产物上传。
首次构建缺少 iOS engine 缓存，补充 `flutter precache --ios` 后重新运行成功。
已有客户端测试：289 项通过、2 项原有跳过；相关 Dart 文件静态分析通过。
尚未完成 Apple 签名、手机安装、真实 DeepSeek 请求或手机上的离线转录验收。

参考：

- [GitHub runner 与公开/私有仓库计费说明](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)
- [Flutter iOS 构建说明](https://docs.flutter.dev/deployment/ios)
- [AltStore Classic Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [AltStore 刷新与安装数量说明](https://faq.altstore.io/altstore-classic/your-altstore)
