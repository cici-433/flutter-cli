import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'core_paged_list_models.dart';

/// 通用分页列表控制器。
///
/// 职责：
/// - 维护列表数据、页码、是否还有更多等分页状态
/// - 统一封装刷新与加载更多流程
/// - 暴露首屏加载、空态、错误态、底部加载错误等视图状态
///
/// 说明：
/// - 控制器不关心具体 UI，只负责状态流转与数据拼装
/// - 视图层可通过 [CorePagedListView] 或自定义组件监听本控制器
class CorePagedListController<T> extends ChangeNotifier {
  /// 创建分页控制器。
  ///
  /// - [fetcher]：分页数据获取函数
  /// - [initialPage]：初始页码，默认从 1 开始
  /// - [pageSize]：每页条数
  /// - [autoLoadOnInit]：是否在视图首次挂载时自动触发首屏加载
  CorePagedListController({
    required this.fetcher,
    this.initialPage = 1,
    this.pageSize = 20,
    this.autoLoadOnInit = true,
  }) : _nextPage = initialPage;

  final CorePagedListFetcher<T> fetcher;
  final int initialPage;
  final int pageSize;
  final bool autoLoadOnInit;

  final List<T> _items = <T>[];

  int _nextPage;
  bool _initialized = false;
  bool _hasMore = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  CorePagedListStatus _status = CorePagedListStatus.initial;
  Object? _error;
  StackTrace? _errorStackTrace;
  Object? _loadMoreError;
  StackTrace? _loadMoreErrorStackTrace;

  /// 当前列表数据，只读暴露给外部。
  UnmodifiableListView<T> get items => UnmodifiableListView<T>(_items);

  /// 当前首屏状态。
  CorePagedListStatus get status => _status;

  /// 是否还有更多数据可继续加载。
  bool get hasMore => _hasMore;

  /// 是否正在执行下拉刷新或首屏刷新。
  bool get isRefreshing => _isRefreshing;

  /// 是否正在执行加载更多。
  bool get isLoadingMore => _isLoadingMore;

  /// 是否处于首屏加载中。
  bool get isInitialLoading =>
      _status == CorePagedListStatus.loading && _items.isEmpty;

  /// 是否处于首屏错误态。
  bool get hasInitialError =>
      _status == CorePagedListStatus.error && _items.isEmpty;

  /// 是否处于空态。
  bool get isEmpty => _status == CorePagedListStatus.empty && _items.isEmpty;

  /// 首屏错误对象。
  Object? get error => _error;

  /// 首屏错误堆栈。
  StackTrace? get errorStackTrace => _errorStackTrace;

  /// 加载更多错误对象。
  Object? get loadMoreError => _loadMoreError;

  /// 加载更多错误堆栈。
  StackTrace? get loadMoreErrorStackTrace => _loadMoreErrorStackTrace;

  /// 确保控制器已初始化。
  ///
  /// 当 [autoLoadOnInit] 为 `true` 时，仅首次调用会触发一次 [refresh]。
  Future<void> ensureInitialized() async {
    if (_initialized || !autoLoadOnInit) return;
    _initialized = true;
    await refresh();
  }

  /// 刷新列表。
  ///
  /// 行为：
  /// - 重新从 [initialPage] 开始请求
  /// - 覆盖旧数据
  /// - 重置分页状态与底部错误状态
  Future<void> refresh() async {
    if (_isRefreshing) return;

    final hadItems = _items.isNotEmpty;
    _isRefreshing = true;
    _loadMoreError = null;
    _loadMoreErrorStackTrace = null;
    _error = null;
    _errorStackTrace = null;

    if (!hadItems) {
      _status = CorePagedListStatus.loading;
    }
    notifyListeners();

    try {
      final CorePagedListResult<T> result = await fetcher(
        CorePagedListQuery(
          page: initialPage,
          pageSize: pageSize,
          isRefresh: true,
        ),
      );

      _items
        ..clear()
        ..addAll(result.items);
      _nextPage = initialPage + 1;
      _hasMore = result.hasMore;
      _status = _items.isEmpty
          ? CorePagedListStatus.empty
          : CorePagedListStatus.success;
    } catch (e, s) {
      _error = e;
      _errorStackTrace = s;
      if (!hadItems) {
        _status = CorePagedListStatus.error;
      }
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// 加载下一页数据。
  ///
  /// 会在以下场景直接返回：
  /// - 正在加载更多
  /// - 正在刷新
  /// - 已无更多数据
  /// - 首屏仍在加载
  /// - 首屏处于错误态
  Future<void> loadMore() async {
    if (_isLoadingMore ||
        _isRefreshing ||
        !_hasMore ||
        _status == CorePagedListStatus.loading ||
        _status == CorePagedListStatus.error) {
      return;
    }

    _isLoadingMore = true;
    _loadMoreError = null;
    _loadMoreErrorStackTrace = null;
    notifyListeners();

    try {
      final CorePagedListResult<T> result = await fetcher(
        CorePagedListQuery(
          page: _nextPage,
          pageSize: pageSize,
          isRefresh: false,
        ),
      );

      _items.addAll(result.items);
      _nextPage += 1;
      _hasMore = result.hasMore;
      _status = _items.isEmpty
          ? CorePagedListStatus.empty
          : CorePagedListStatus.success;
    } catch (e, s) {
      _loadMoreError = e;
      _loadMoreErrorStackTrace = s;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 根据当前列表状态选择重试策略。
  ///
  /// - 当前无数据时：按首屏失败处理，执行 [refresh]
  /// - 当前已有数据时：按加载更多失败处理，执行 [loadMore]
  Future<void> retry() async {
    if (_items.isEmpty) {
      await refresh();
      return;
    }
    await loadMore();
  }

  /// 重置控制器到初始状态。
  ///
  /// 适用于切换筛选条件、退出页面后重新进入、或外部主动清空列表。
  void reset() {
    _items.clear();
    _nextPage = initialPage;
    _hasMore = true;
    _isRefreshing = false;
    _isLoadingMore = false;
    _status = CorePagedListStatus.initial;
    _error = null;
    _errorStackTrace = null;
    _loadMoreError = null;
    _loadMoreErrorStackTrace = null;
    _initialized = false;
    notifyListeners();
  }
}
