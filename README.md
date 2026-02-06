# pixia-bills


---

## 1) 产品定位与核心体验

**目标用户**

* 需要“随手记一笔”的个人用户（轻量、低学习成本）
* 有复盘需求（周/月统计、分类占比、日历回看）

**核心承诺（对标截图的三句）**

* **极简操作**：3 步完成记账（选分类 → 输入金额 → 保存）
* **智能统计**：周/月/年趋势 + 分类占比 + 大额交易提示
* **一目了然**：日历视图快速回看每天消费/收入

---

## 2) 信息架构（Tab + 关键页面）

建议采用 **5 Tab + 中间大“+”**（与截图一致）：

1. **明细（Home）**

   * 顶部：月份选择（2026 年 02 月）+ 搜索 + 日历入口
   * 概览：本月收入 / 支出 / 结余（可折叠）
   * 快捷入口（icon grid）：账单、预算、资产、更多（先做 2~3 个即可）
   * 明细列表：按“日期”分组，显示当天支出/收入小计

2. **图表（统计）**

   * 维度切换：周 / 月 / 年
   * 趋势图：支出折线（可点选显示 tooltip）
   * 分类分析：条形占比（分类 icon + % + 金额）
   * 大额交易：Top 3（截图里“最大3笔交易”的气泡）

3. **记账（中间 +）**

   * 弹出底部面板（Bottom Sheet）
   * 顶部：支出/收入切换
   * 内容：分类九宫格（图标 + 文案）
   * 下一步：金额键盘 + 备注/账户/时间（默认收起高级项）

4. **发现（可选 / 第二阶段）**

   * 你也可以先用“资产/预算”替代，避免空页面

5. **我的（设置）**

   * 数据：iCloud 同步开关、导出 CSV、备份/恢复
   * 外观：主题色（默认黄）、深色模式
   * 安全：FaceID/TouchID 解锁（可选）

---

## 3) 关键交互：3 秒快速记账（强建议按这个做）

**流程**

1. 点中间 **“+”**
2. 选择分类（支出/收入）
3. 输入金额 → 直接保存（默认当前时间、默认账户）

**提升速度的小细节**

* 分类选择后，金额键盘自动弹出并聚焦
* “保存”放在右下角（拇指区），支持回车提交
* 备注/账户/日期做成“可展开”的次要操作，不抢主流程
* 记账成功给轻反馈：haptic + 小 toast（不弹窗打断）

---

## 4) UI 设计规范（对齐截图视觉）

**色彩**

* 主色：亮黄（建议做成可配置主题色）
* 背景：浅灰/白（列表更清爽）
* 强文本：近黑；弱文本：灰
* 收入/支出建议用语义色（如绿/红），但饱和度要低，避免喧宾夺主

**组件复用**

* 顶部月份选择器（MonthPicker）
* 概览卡片（SummaryHeader：收入/支出/结余）
* 分类 Icon（统一圆角底 + 线性图标风格）
* 分组列表（按天 SectionHeader + 当天小计）
* Tooltip 气泡（图表点选）

---

## 5) 数据模型（推荐先做最小闭环）

### 核心实体（MVP 必需）

* **Transaction（流水）**

  * id, type（income/expense）
  * amount（Decimal）
  * date（Date）
  * categoryId
  * accountId（可先默认一个“现金”）
  * note（可选）
  * createdAt/updatedAt

* **Category（分类）**

  * id, type, name, iconName, sortOrder, isDefault

* **Account（账户）**（MVP 可以先 1 个默认账户）

  * id, name, type（cash/bank/credit）, balance（可选）

### 第二阶段（增强）

* Budget（预算：按月/按分类）
* Tag（标签）
* RecurringTransaction（周期记账）
* Transfer（转账：账户间）

---

## 6) 本地存储与同步策略（Swift 原生最佳实践）

**建议技术选型**

* UI：**SwiftUI**
* 架构：**MVVM + UseCase（可轻量）**
* 数据：**SwiftData**（iOS 17+）或 Core Data（更兼容）
* 图表：**Swift Charts**
* 同步（可选）：CloudKit / iCloud（后期开关）

**原则**

* 默认离线可用（所有功能本地可跑）
* 同步做成“可选能力”，避免一开始把复杂度拉满
* 导出 CSV/JSON 作为最低可用备份手段（很受用户欢迎）

---

## 7) 统计模块设计（截图里的“智能统计”怎么落地）

**统计维度**

* 周：按天汇总
* 月：按天汇总
* 年：按月汇总

**关键指标**

* 总支出、总收入、结余
* 分类占比（支出 Top N，其余合并为“其他”）
* 大额交易 Top 3（按金额排序）
* 可选：平均每日支出、最高支出日

**实现建议**

* 聚合查询尽量在数据层做（Repository 提供 `summary(range:)`）
* 图表点选：用 `chartOverlay` + 手势定位最近数据点，弹出 Tooltip

---

## 8) 记账页（分类 + 键盘）组件拆分

**Bottom Sheet 的两个状态**

* 状态 A：分类九宫格（支出/收入 tabs）
* 状态 B：金额输入（自定义数字键盘 + 保存按钮）

**金额输入区建议字段**

* 金额（必填）
* 备注（可选）
* 账户（默认：现金）
* 日期（默认：现在；支持改为昨天/自定义）
* 高级：标签/图片（第二阶段）

---

## 9) 工程结构建议（可直接照这个建目录）

* App
* Presentation

  * Home（明细）
  * Stats（统计）
  * Add（记账）
  * Calendar
  * Settings
  * Components（通用组件：Header、Icon、Keypad、Tooltip…）
* Domain

  * Models（Transaction/Category/Account…）
  * UseCases（AddTransaction、GetMonthlySummary…）
* Data

  * Persistence（SwiftData/CoreData）
  * Repositories
  * Mappers（如需要）
* Resources

  * Assets（颜色、图标、L10n）

---

## 10) MVP 功能清单（先做什么，保证可发布）

**必须有**

* 分类管理（内置一套默认分类：餐饮/购物/交通/居家/娱乐/通讯…）
* 快速记账（支出/收入）
* 明细列表（按天分组）
* 月度概览（收入/支出/结余）
* 统计页：月趋势 + 分类占比 Top N
* 日历页：月视图 + 每日汇总 + 点一天看流水
* 数据导出（CSV）

**可选但很加分（第二阶段）**

* 预算（按月总额 + 按分类）
* 周期记账
* 多账户 + 转账
* FaceID 锁
* iCloud 同步
* 小组件（今日支出 / 本月支出）

---

## 11) 交付物清单（你可以拿去对齐/评审）

1. 页面原型（Home / Stats / Add / Calendar / Settings）
2. 设计规范（颜色、字体、间距、组件库）
3. 数据模型与迁移策略（版本化）
4. API/Repository 接口（即使先不联网也要抽象）

---

最低支持ios版本 ios15

---

## CI：GitHub Actions 产出未签名 IPA

仓库内置了 GitHub Actions 工作流：`.github/workflows/ios-unsigned-ipa.yml`。

- 触发：`push(main)` / `pull_request` / 手动触发
- 触发：`push(main)` / `pull_request` / `push tag(v*)` / 手动触发
- 平台：`macos-14`
- 产物：`build/pixia-bills-<版本号>.ipa`

版本号来源（优先级）：

1. 手动触发输入的 `version`
2. Git tag（如 `v0.1.0` 会解析为 `0.1.0`）
3. `project.yml` 中的 `MARKETING_VERSION`

本地命令（macOS + Xcode 环境）：

```bash
brew install xcodegen
./scripts/build_unsigned_ipa.sh 0.1.0
```

说明：当前产物为 **未签名 IPA**，用于 CI 验证与归档，不可直接安装到真机发布。
