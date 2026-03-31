/// 分页请求函数签名。
///
/// 调用方只需实现“给定分页参数，返回一页数据”的逻辑，
/// 列表控制器会负责刷新、翻页、状态切换等流程控制。
typedef CorePagedListFetcher<T> = Future<CorePagedListResult<T>> Function(
  CorePagedListQuery query,
);

/// 分页列表当前的首屏状态。
///
/// 说明：
/// - `initial`：尚未开始加载
/// - `loading`：首屏加载中
/// - `success`：已有有效数据
/// - `empty`：首屏成功但数据为空
/// - `error`：首屏加载失败
enum CorePagedListStatus {
  initial,
  loading,
  success,
  empty,
  error,
}

/// 一次分页请求的参数。
///
/// - [page]：当前请求页码
/// - [pageSize]：每页数量
/// - [isRefresh]：是否由“刷新”触发；否则视为“加载更多”
class CorePagedListQuery {
  const CorePagedListQuery({
    required this.page,
    required this.pageSize,
    required this.isRefresh,
  });

  final int page;
  final int pageSize;
  final bool isRefresh;
}

/// 一次分页请求的返回结果。
///
/// - [items]：本页返回的数据列表
/// - [hasMore]：是否还有下一页
class CorePagedListResult<T> {
  const CorePagedListResult({
    required this.items,
    required this.hasMore,
  });

  final List<T> items;
  final bool hasMore;
}
