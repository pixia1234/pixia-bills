# pixia-bills

一个面向 iOS 的个人记账应用，主打「随手记一笔 + 可复盘 + 可同步」。

- 最低系统：`iOS 15`
- UI：`SwiftUI`
- 工程管理：`XcodeGen`（由 `project.yml` 生成 Xcode 工程）
- 数据存储：本地 `JSON` 文件 + 可选 `WebDAV` 加密同步

---

## 功能概览

### 记账与明细
- 快速记账：分类 → 金额 → 保存
- 支持收入/支出、备注、日期、账户
- 明细按天分组展示
- 支持删除与编辑流水（明细列表可滑动编辑）

### 统计与日历
- 月度收支汇总（收入 / 支出 / 结余）
- 趋势与分类占比
- 大额交易 Top 视图
- 日历视图按日回看流水

### 数据管理
- 分类管理
- 预算管理
- 账户管理与转账
- 周期记账
- CSV 导出与导入

### 同步与安全
- WebDAV 同步（支持加密）
- 同步状态、手动同步与日志查看
- FaceID / TouchID 解锁（应用切后台后可重新锁定）

### AI 导入
- 支持上传图片并调用 OpenAI 兼容 API 解析流水
- 可在设置中配置 `API Base / API Key / Model`

---

## 项目结构

```text
pixia-bills/
├── PixiaBills/
│   ├── App/                  # 应用入口、容器、设置与锁屏管理
│   ├── Presentation/         # UI 页面（Home/Stats/Add/Calendar/Settings）
│   ├── Domain/               # 领域模型与通用工具
│   ├── Data/                 # 数据存储、同步、导入导出
│   └── Resources/            # 资源文件
├── scripts/
│   └── build_unsigned_ipa.sh # 本地打未签名 IPA
├── .github/workflows/
│   └── ios-unsigned-ipa.yml  # CI 构建与 Release 发布
└── project.yml               # XcodeGen 工程定义
```

---

## 本地开发

### 环境要求
- macOS（建议最新稳定版）
- Xcode（建议 15+）
- Homebrew
- XcodeGen

安装 XcodeGen：

```bash
brew install xcodegen
```

### 运行项目

```bash
# 1) 生成 Xcode 工程
xcodegen generate

# 2) 打开工程
open PixiaBills.xcodeproj
```

在 Xcode 中选择 `PixiaBills` scheme，运行到模拟器或真机。

---

## 本地构建未签名 IPA

仓库提供了脚本：`scripts/build_unsigned_ipa.sh`

```bash
./scripts/build_unsigned_ipa.sh <version>
```

产物输出：

```text
build/pixia-bills-<version>.ipa
```

> 该脚本会自动执行：`xcodegen generate` → `xcodebuild archive` → 打包 `ipa`。

---

## 配置说明

### WebDAV 同步
在 App 的「我的」页面中可配置：
- 协议（`http/https`）
- 地址、端口、路径
- 用户名/密码
- 加密密钥

开启后可自动同步，也可手动触发拉取/推送。

### AI 图片导入
在「我的」页面配置：
- `LLM API Base`
- `LLM API Key`
- `Model`（例如 `gpt-4o-mini`）

配置后可在「从图片导入流水」中执行识别与导入。

---

## CI / Release

工作流文件：`.github/workflows/ios-unsigned-ipa.yml`

触发方式：
- `push` 到 `main`
- `push` 标签 `v*`
- `pull_request`
- 手动触发（`workflow_dispatch`）

CI 行为：
1. 在 `macos-14` 上安装依赖并构建未签名 IPA
2. 上传 Actions Artifact
3. 发布到 GitHub Release
   - 若是标签触发（如 `v0.1.0`），使用该标签发布
   - 若是 `main` 触发，自动计算下一个 patch 版本并发布

---

## 常见命令

```bash
# 查看当前状态
git status

# 生成工程
xcodegen generate

# 本地构建未签名 IPA
./scripts/build_unsigned_ipa.sh <version>
```

---

## License

本项目采用 `MIT` 协议，见 `LICENSE`。
