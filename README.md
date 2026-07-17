# Codex CLI Simplified Chinese

面向 Windows 原生 Codex CLI 的可审计简体中文显示层补丁。项目不修改命令名、快捷键、配置键、协议、账号、认证数据、模型输出或工具输出。

## 当前支持

- Codex CLI `0.144.3`
- 官方 tag `rust-v0.144.3`
- Windows x64
- 84 个严格匹配的显示文本
- `/` 命令说明、审批标题与选项、部分问答提示
- `/` 命令说明经过人工语序与终端长度审校，不采用逐词直译

隐藏调试文案、错误日志和动态输出保持英文，便于排错和对照官方资料。

## 下载与使用

1. 在仓库的 Actions 页面运行 `Build Windows`，或从成功的构建中下载 Artifact。
2. 解压 Artifact，核对 `SHA256SUMS.txt`。
3. 退出正在运行的目标 CLI。
4. 在 PowerShell 中运行 `./Install.ps1`。
5. 需要恢复官方 CLI 时运行 `./Uninstall.ps1`。

安装器只切换 `~/.codex-cli-bin/codex-cli.cmd`，不会修改其他 CLI 入口。原启动器会保存到 `~/.codex-cli-archive/codex-cli-chinese/<timestamp>/`，卸载前会核对哈希。

## 云端构建

`.github/workflows/build-windows.yml` 使用固定的官方 Codex commit、固定 Rust 工具链和 `windows-2022` Runner 构建。第三方 Action 均固定到完整提交 SHA。

构建流程会：

1. 读取精确版本适配器。
2. 拉取适配器声明的官方 commit。
3. 运行补丁器单元测试和上游源码集成测试。
4. 拒绝缺失、重复或发生漂移的文本锚点。
5. 仅允许把发布占位 workspace 版本从 `0.0.0` 刷新到目标版本，其他锁文件变化会失败。
6. 使用刷新后的锁文件执行 `--locked` release 编译并校验 `--version`。
7. 生成 SHA-256、构建清单和 GitHub Artifact Attestation。
8. 上传包含安装与卸载脚本的 Artifact。

构建不读取或上传本机 `CODEX_HOME`、登录令牌、聊天记录和账号配置，也不需要仓库 Secret。

## 版本更新

新 Codex 版本不会自动套用旧补丁。维护步骤是：

1. 新增 `resources/adapters/codex-<version>.json`。
2. 记录官方 tag、commit、Rust 版本和源码锚点数量。
3. 更新必要的中文目录项。
4. 运行真实上游源码集成测试。
5. 云端构建并人工检查 TUI。

任何锚点数量变化都会导致构建失败，避免把翻译误写到业务逻辑或测试无关位置。

## 语言扩展

补丁引擎可加载独立语言目录，但每种语言必须单独审校、构建和发布。当前先稳定
`zh-CN`；后续计划依次添加 `ja-JP` 和 `ko-KR`，不会把未经人工审校的机器翻译
直接打包。命令名、参数、占位符和协议名称在所有语言中保持不变。详细约束见
`docs/LOCALIZATION_GUIDE.md`。

## 本地开发

补丁器只需要 Node.js 20 或更高版本：

```powershell
npm test
node ./src/cli.mjs check --source C:\path\to\official-codex-source
```

本地原生编译会占用大量磁盘，仅用于调试；日常发布应使用 GitHub Actions。

## 上游与许可

本项目补丁器和脚本使用 MIT License。OpenAI Codex 上游源码仍受其 Apache-2.0 License 约束，详见 `THIRD_PARTY_NOTICES.md`。
