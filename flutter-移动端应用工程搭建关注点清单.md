# Flutter 移动端应用工程搭建关注点清单

> 目标：把工程底座设计到“可扩展、可维护、可发布”，降低后续返工与线上风险。

## 一、分层架构 + 模块化（可扩展）

重点在于：加新功能成本低

- **纵向分层（职责解耦）**：
  - **UI 层**：Widget（Stateless/Stateful），路由（Navigator 2.0 / GoRouter / auto_route）。UI 只负责渲染与交互，状态通过状态管理流入，不直接发网络或操作存储。
  - **业务逻辑层**：状态管理（推荐统一选型：Riverpod/BLoC/Provider 之一）+ UseCase。状态容器负责聚合界面状态与事件，UseCase 封装业务流程与并发/重试策略。
  - **数据层**：Repository 聚合数据来源：Remote（dio/http + 拦截器）与 Local（hive/drift/shared_preferences/secure_storage），向上暴露稳定模型与 Stream/Future。
  - **基础设施层**：网络（dio 拦截器/重试）、序列化（json_serializable/freezed/isar）、依赖注入（get_it/Riverpod）、日志（logger）、任务调度（Workmanager/android_alarm_manager）、i18n（flutter_localizations）。
  - **总结**：通过隔离变化，让某一层在改变演进时，其他层能零成本复用。
    - UI层与业务层解耦，同一业务逻辑可以适配不同UI展现
    - 数据层与业务层解耦，同一业务可以适配不用的数据来源（网络/本地缓存）
    - 基础设施层屏蔽，基础设施的升级/替换，完全不影响上层业务（比如图片库、网络库）
- **横向模块化（业务隔离）**：
  - **业务模块**：按业务域拆分为 Dart 包（`feature_login/feature_mine/feature_home/feature_pay`），通过 **契约接口**（抽象类）或 **路由** 通信，禁止 `featureA -> featureB_impl` 的实现依赖。
  - **基础组件**：`core_network/core_router/core_ui_components/core_logger` 等通用能力独立为包，被各业务复用；依赖方向保持 `feature -> core`。
  - **总结**：通过模块化，本质是把系统拆成一组 边界清晰、依赖单向、可插拔 的业务单元，让“新增/替换/组合”都变成 局部改动 而不是“全局牵一发而动全身”。
    - 加新业务，不需要去改一堆旧模块内部代码
    - 基础能力下沉复用，不用每个模块重复造轮子，替换实现也不影响上层业务
    - 模块边界明确后，并行开发不互相阻塞
- **架构模式统一**：
  - 全工程统一采用“分层 + Repository + 统一状态管理”（建议 Riverpod 或 BLoC 选其一并全局执行）。
  - 统一路由与导航范式（GoRouter/auto_route 二选一）；路由守卫与参数传递规则一致。
  - 统一错误/加载态处理：在状态层聚合，UI 订阅展示；避免各模块重复造 Loading/Error。
  - **总结**：通过统一架构与范式，新增功能走固定模板（UI/State/UseCase/Repo），扩展路径稳定、协作成本低。
- **终极目标**：避免代码全部堆砌在“巨石应用”中，确保在新增业务或替换底层技术（如换网络库）时，只需局部改动，保障工程边界与依赖方向长期稳定。

## 二、统一基础框架 + 规范（可维护）

重点在于：改现有东西低成本、低风险

- **基础能力收口（防重复造轮子）**：
  - **网络体系**（dio）：统一请求/响应模型；拦截器链（Header 注入、鉴权、日志、重试/退避、超时）；错误码标准化（网络错误/业务错误映射）；**Token 自动刷新**用鉴权拦截器实现，401 触发单飞刷新、更新 Token 后重放请求，刷新失败统一退出登录。
  - **路由体系**（GoRouter/auto_route）：中心化路由注册；支持复杂参数序列化；路由守卫（登录态/权限校验）；**防重连点**（节流/单次跳转/去重）；**跨端深链**（uni_links + Android App Links + iOS Universal Links + 兜底 H5）。
  - **存储体系**：结构化数据用 drift/isar；高频 KV 用 hive/shared_preferences；敏感数据（Token/密钥）用 flutter_secure_storage + 加密；统一封装读写与版本迁移。
  - **媒体与资源**：图片统一用 CachedNetworkImage/extended_image；全局占位/失败图；内存/磁盘缓存策略；常用变换（裁剪/圆角/模糊）；资源命名与分发规范。
  - **总结**：把网络、路由、存储、图片等通用能力统一封装收口为基础组件，业务只面向统一接口复用，从而减少重复造轮子并提升一致性、稳定性与可维护性
- **规范与约束（防代码腐化）**：
  - **代码风格门禁**：flutter_lints/analyzer 规则；Dart format 强制；import 顺序与文件命名规范；Pre-commit 校验。
  - **异常兜底机制**：FlutterError.onError + runZonedGuarded；禁止空 `try-catch` 吞错；记录到 Crashlytics/Sentry 并上报关键上下文（接口名、用户态、网络态）。
  - **设计系统（Design System）**：Theme/ColorScheme/Typography/Spacing 统一；基础组件（Button/Toast/Dialog/Skeleton）下沉；暗色模式与多尺寸适配策略落地。
  - **总结**：通过统一的代码风格门禁、异常处理规范与设计系统组件约束，把质量规则前置并制度化，持续抑制代码腐化，保证长期一致性与可维护性。
- **外部依赖治理**：
  - **SDK 统一初始化**：推送/统计/支付/分享等插件集中管理初始化时机与开关（Debug/Prod/灰度/渠道）；按启动阶段分级初始化（冷启动只开必要，其他异步）。
  - **合规与权限**：统一权限组件（permission_handler 封装文案/引导/埋点）；用户同意隐私前不初始化会采集的 SDK；支持渠道/地区的依赖剥离与替换（flavors/条件编译）。
  - **总结**：通过集中化管理第三方 SDK 的接入与初始化，并统一权限与合规处理策略，实现依赖可控、启动可优化、渠道可裁剪，从而降低合规与性能风险。
- **测试与可测性设计**：接口 Mock、单元测试结构、调试工具面板（切换环境/查看请求/清空缓存）、抓包开关
  - **测试**：单元测试（package:test + mocktail）；Widget 测试；集成测试（integration_test）；Golden 截图测试；依赖注入可替换（测试用 Fake Repository/Service）。
  - **可测性**：统一 Mock 接口/数据开关；Debug 工具面板（环境切换/请求查看/缓存清空/埋点查看）；抓包与日志等级切换。
- **协作契约**：明确项目文档（环境搭建、打包指南），规范 Git 分支模型（如 GitFlow）、Commit 格式验证以及 Code Review 流程。

## 三、监控 + 安全 + 构建（可上线/可观测）

重点在于：保证线上稳定、风险可控、交付高效

- **全方位可观测性（线上“天眼”）**：
  - **稳定性监控**：Crashlytics/Sentry 等崩溃平台；Crash/OOM 自动上报；符号表/混淆映射上传；异常归因到模块。
  - **性能指标追踪**：冷/热启动耗时、首帧时间、帧率/Jank（Performance Overlay/DevTools）、接口成功率与耗时分布。
  - **业务行为洞察**：统一埋点封装（Firebase Analytics/Amplitude/神策）；页面曝光/点击/事件规范化；埋点校验工具。
- **多维安全防御（守住红线）**：
  - **通信与数据安全**：强制 HTTPS；证书钉扎（平台层或 dio 自定义验证）；敏感参数加密；本地敏感数据加密存储（secure_storage）。
  - **端侧防护**：混淆与树摇（`flutter build --obfuscate --split-debug-info`）；签名校验；Root/Jailbreak 检测（按需）。
- **工程化构建与 CI/CD（解放生产力）**：
  - **多环境敏捷切换**：Flavor 管理 Dev/Test/Pre/Prod；环境常量与依赖注入切换域名/埋点/调试开关；打包脚本区分渠道。
  - **自动化流水线**：GitHub Actions/Codemagic/Jenkins 触发 Lint/测试；Android App Bundle/APK 与 iOS IPA 构建与签名；产物上传与分发；构建结果与下载链接自动通知企微/飞书。
  - **构建性能调优**：缓存与增量编译；依赖瘦身；资源裁剪；monorepo 管理（melos）；避免过度反射。

## 四、工程目录结构（示例）

> 目标：让依赖方向天然正确，业务可插拔，基础能力可复用。

```text
repo-root/
  app/                          # 主应用：入口、全局组装（依赖注入/路由注册）、多环境配置
  packages/
    core_network/               # 网络封装：dio、拦截器、统一错误模型、序列化
    core_router/                # 路由/DeepLink：页面注册、导航、守卫、参数编解码
    core_ui_components/         # 设计系统组件：Button/Dialog/Toast/Skeleton 等
    core_logger/                # 日志与埋点基础能力
    domain_user/                # 领域层（用户）：Entity、UseCase、Repository 接口
    domain_auth/                # 领域层（鉴权）：SessionStore、AuthRepository 接口
    data_user/                  # 数据实现层（用户）：RepositoryImpl、Remote/Local
    data_auth/                  # 数据实现层（鉴权）：Token 刷新与存储
    feature_login/              # 业务模块（登录）
    feature_home/               # 业务模块（首页）
    feature_mine/               # 业务模块（我的）
    feature_pay/                # 业务模块（支付）
  tools/                        # 脚本与工具：CI、签名、打包、代码扫描（不放密钥）
  docs/                         # 项目文档（可选，按需）
```

### 依赖方向（推荐约束）

```text
packages/feature_*  ->  packages/domain_*  <-  packages/data_*
packages/feature_*  ->  packages/core_* 
app                  ->  feature_* + data_* + core_*   # 只在 app 做“组装”，避免业务互相依赖
```

### 单个模块内部（常见 package 组织）

```text
packages/feature_home/lib/
  presentation/                 # 页面与组件（Widgets），状态订阅与渲染
  state/                        # 状态容器（Riverpod/BLoC）
  navigation/                   # 路由入口、页面声明（对外暴露最小入口）
  di/                           # 仅本模块的依赖注入声明
  model/                        # UI Model（展示模型，避免直接使用 domain/entity）
```

## 一句话总结（Leader 视角）

- 分层架构 + 模块化（可扩展）
- 统一基础框架 + 规范（可维护）
- 监控 + 安全 + 构建（可上线）
