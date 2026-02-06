# 第一阶段（MVP）实现进度

本仓库的 `README.md` 定义了 pixia-bills 的产品与 MVP 功能。为了在 **最低 iOS 15** 上快速闭环，我在本仓库新增了一套 **SwiftUI + 本地 JSON 存储** 的工程骨架，覆盖 MVP 核心页面与数据模型。

> 说明：由于当前环境没有 Xcode/Swift toolchain，本仓库提供的是可直接在 Xcode 中创建 iOS App 后导入的源码结构（不含 `.xcodeproj`）。

## 已落地功能（对应 README 的“必须有”）

- 快速记账：中间 “+” 弹出 Bottom Sheet，分类九宫格 → 输入金额 → 保存
- 明细列表：按天分组，展示当天支出小计 + 流水列表
- 月度概览：收入 / 支出 / 结余
- 统计页：月趋势（简易折线）+ 分类占比 Top N + 最大 3 笔交易
- 日历页：月视图 + 每日支出汇总 + 点一天看流水
- 数据导出：生成 CSV 并通过系统分享面板导出
- 分类管理：支出/收入分类的增删改与排序

## 目录结构

- `PixiaBills/App`: `@main` 入口与主 Tab
- `PixiaBills/Domain`: 领域模型（Transaction/Category/Account）
- `PixiaBills/Data`: JSON 持久化与默认数据
- `PixiaBills/Presentation`: Home/Stats/Add/Calendar/Settings 页面与通用组件
- `PixiaBills/Resources`: 颜色资源（Assets.xcassets）

## 在 Xcode 中使用

1. Xcode 新建 iOS App（SwiftUI，Minimum iOS 15）
2. 把本仓库的 `PixiaBills/` 目录拖进项目（Copy items if needed）
3. 删除模板生成的 `App`/`ContentView`，并把入口改为 `PixiaBills/App/PixiaBillsApp.swift`
4. 运行

## 第二阶段建议

- 预算/多账户/转账/周期记账
- iCloud 同步、FaceID 锁、小组件

> 更新：已在源码里补了一个“第二阶段最小可用”的实现（预算 / 账户与转账 / 周期记账），入口在「我的」页。

> 更新：已补 iPad 分栏适配（Home 支持主从 split view）与暗黑模式基础适配（核心卡片与图标对比度）。
