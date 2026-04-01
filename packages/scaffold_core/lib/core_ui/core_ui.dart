/// core_ui
///
/// 一个面向 Flutter 视图层的通用 UI 能力模块。
///
/// 当前提供：
/// - 通用分页列表封装（下拉刷新、上拉加载更多、空态、错误态、底部状态）
///
/// 设计目标：
/// - 让业务页面复用统一的列表交互模式
/// - 将“分页状态管理”和“分页列表渲染”解耦
/// - 通过统一导出减少上层对目录结构的感知
library;

export 'list/core_paged_list.dart';
export 'image/core_image.dart';
