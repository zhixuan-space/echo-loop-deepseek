# 没有 Mac：云端编译，再用 Windows 安装

当前已经准备好手动云构建工作流 `.github/workflows/personal-ios.yml`。
它尚未上传到你的 GitHub 仓库，也没有运行。当前没有可安装的 IPA。

## 登录与仓库

在当前应用里安装 GitHub 插件，并按其提示在 GitHub 官方页面登录、授权。
不要把 GitHub 密码、Apple ID 密码或 DeepSeek Key 发送到聊天。
连接后再确定新仓库名称和公开范围，再上传代码。

GitHub 标准 macOS 托管 runner 在公开仓库中免费使用；私有仓库使用账户额度，
超额可能计费。仓库公开范围应由你选择。

## 云端构建

1. 将修改后的完整源码放入你自己的仓库，保留 `.github/workflows/personal-ios.yml`。
2. 打开仓库的 Actions 页面，选择 **Personal iPhone build**。
3. 点击 **Run workflow**，选择包含修改代码的分支，运行。
4. 成功后，在该次运行的 Artifacts 中下载
   **Echo-Loop-DeepSeek-unsigned-iPhone**，解压得到 `.ipa`。

工作流在 macOS 15 上使用 Flutter 3.47.7 构建 `prod` flavor，关闭代码签名，
将真实 iPhone `.app` 包装为 IPA。已有代码生成产物保留在源码中。
流程只需要仓库读取权限，不要求 Apple 证书、Apple ID 或 DeepSeek Key。
IPA 构建产物保留 7 天。它不会上传 App Store Connect、TestFlight 或 GitHub Release。

## 在 Windows 上安装

使用 **AltStore Classic / AltServer for Windows**，按照其官方文档准备
iTunes、iCloud 和驱动。连接 iPhone 并信任电脑，然后用自己的 Apple ID
完成安装工具要求的签名流程。在 AltStore Classic 中导入自己的 IPA。

IPA 未签名，不能在 iPhone 文件 App 中直接点开安装；签名由安装工具使用你的
Apple 账号完成。普通 Apple ID 通常需要每 7 天刷新，且存在同时安装数量限制。
iOS 16 及以后还可能需要在设备上启用开发者模式，按安装工具提示操作。
没有实际在目标手机测试前，不能保证该 IPA 的全部插件和本地识别都正常。

## 首次使用

打开应用 → 设置 → 个人 AI · DeepSeek → 填写 API Key、模型名称 →
测试连接 → 开启并保存。模型名应以你账户可用的 ID 为准。
本地字幕在材料的「管理字幕 → 离线转录」中下载并选择 Whisper 模型。

## 当前验证范围

已检查 workflow YAML、Bash 语法、手动触发及只读权限。
由于本机是 Windows，尚未执行 macOS / Xcode 构建、Apple 签名或手机安装。
已有客户端测试：289 项通过、2 项原有跳过；这不等于 iOS 原生构建已通过。

参考：

- [GitHub runner 与公开/私有仓库计费说明](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)
- [Flutter iOS 构建说明](https://docs.flutter.dev/deployment/ios)
- [AltStore Classic Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [AltStore 刷新与安装数量说明](https://faq.altstore.io/altstore-classic/your-altstore)
