import 'dart:async';

import 'package:flutter/material.dart';

import 'core_paged_list_controller.dart';

/// 列表项构建器。
typedef CorePagedListItemBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

/// 首屏错误态构建器。
typedef CorePagedListErrorBuilder =
    Widget Function(BuildContext context, Object? error, Future<void> Function() onRetry);

/// 底部加载更多错误态构建器。
typedef CorePagedListFooterErrorBuilder =
    Widget Function(BuildContext context, Object? error, Future<void> Function() onRetry);

/// 通用分页列表视图。
///
/// 负责：
/// - 将 [CorePagedListController] 的状态映射为不同 UI
/// - 集成下拉刷新能力
/// - 监听滚动位置并自动触发加载更多
/// - 提供空态、错误态、底部 loading/错误/无更多等默认实现
///
/// 适用场景：
/// - 绝大多数“列表页 + 分页接口”的业务页面
/// - 希望复用统一下拉刷新、上拉加载更多交互的页面
class CorePagedListView<T> extends StatefulWidget {
  /// 创建分页列表视图。
  ///
  /// - [controller]：分页状态控制器
  /// - [itemBuilder]：普通列表项构建器
  /// - 可通过一组 builder 自定义各种状态 UI
  const CorePagedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.physics,
    this.scrollController,
    this.primary,
    this.shrinkWrap = false,
    this.enableRefresh = true,
    this.enableLoadMore = true,
    this.loadMoreTriggerOffset = 200,
    this.initialLoadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadMoreLoadingBuilder,
    this.loadMoreErrorBuilder,
    this.noMoreBuilder,
    this.showNoMoreFooter = false,
  });

  final CorePagedListController<T> controller;
  final CorePagedListItemBuilder<T> itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? scrollController;
  final bool? primary;
  final bool shrinkWrap;
  final bool enableRefresh;
  final bool enableLoadMore;
  final double loadMoreTriggerOffset;
  final WidgetBuilder? initialLoadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final CorePagedListErrorBuilder? errorBuilder;
  final WidgetBuilder? loadMoreLoadingBuilder;
  final CorePagedListFooterErrorBuilder? loadMoreErrorBuilder;
  final WidgetBuilder? noMoreBuilder;
  final bool showNoMoreFooter;

  @override
  State<CorePagedListView<T>> createState() => _CorePagedListViewState<T>();
}

class _CorePagedListViewState<T> extends State<CorePagedListView<T>> {
  late final ScrollController _internalScrollController;

  /// 获取最终生效的滚动控制器。
  ///
  /// 优先使用外部传入的 [scrollController]，否则使用组件内部创建的控制器。
  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController;

  @override
  void initState() {
    super.initState();
    _internalScrollController = ScrollController();
    _effectiveScrollController.addListener(_handleScroll);
    unawaited(widget.controller.ensureInitialized());
  }

  @override
  void didUpdateWidget(covariant CorePagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      (oldWidget.scrollController ?? _internalScrollController)
          .removeListener(_handleScroll);
      _effectiveScrollController.addListener(_handleScroll);
    }
    if (oldWidget.controller != widget.controller) {
      unawaited(widget.controller.ensureInitialized());
    }
  }

  @override
  void dispose() {
    _effectiveScrollController.removeListener(_handleScroll);
    _internalScrollController.dispose();
    super.dispose();
  }

  /// 监听滚动位置，在接近底部时触发加载更多。
  void _handleScroll() {
    if (!widget.enableLoadMore) return;
    if (!_effectiveScrollController.hasClients) return;

    final ScrollPosition position = _effectiveScrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final bool shouldLoadMore =
        position.pixels >= position.maxScrollExtent - widget.loadMoreTriggerOffset;
    if (shouldLoadMore) {
      unawaited(widget.controller.loadMore());
    }
  }

  /// 处理下拉刷新动作。
  Future<void> _handleRefresh() async {
    await widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final Widget body = _buildBody(context);
        if (!widget.enableRefresh) return body;
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: body,
        );
      },
    );
  }

  /// 根据控制器当前状态，决定渲染首屏加载、首屏错误、空态或正常列表。
  Widget _buildBody(BuildContext context) {
    final CorePagedListController<T> controller = widget.controller;

    if (controller.isInitialLoading) {
      return widget.initialLoadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }

    if (controller.hasInitialError) {
      return _buildPlaceholder(
        context,
        widget.errorBuilder?.call(
              context,
              controller.error,
              controller.retry,
            ) ??
            _DefaultErrorState(
              message: controller.error?.toString() ?? '加载失败',
              onRetry: controller.retry,
            ),
      );
    }

    if (controller.isEmpty) {
      return _buildPlaceholder(
        context,
        widget.emptyBuilder?.call(context) ??
            const _DefaultHintState(message: '暂无数据'),
      );
    }

    return _buildList(context, controller);
  }

  /// 构建可下拉刷新的占位视图。
  ///
  /// 该实现通过 `AlwaysScrollableScrollPhysics` 保证即使内容不足一屏，
  /// 依然可以触发 `RefreshIndicator`。
  Widget _buildPlaceholder(BuildContext context, Widget child) {
    final ScrollPhysics physics = AlwaysScrollableScrollPhysics(parent: widget.physics);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          controller: _effectiveScrollController,
          primary: widget.primary,
          physics: physics,
          padding: widget.padding,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ],
        );
      },
    );
  }

  /// 构建正常列表内容与底部状态区域。
  Widget _buildList(
    BuildContext context,
    CorePagedListController<T> controller,
  ) {
    final int dataCount = controller.items.length;
    final bool showFooter = widget.enableLoadMore &&
        (controller.isLoadingMore ||
            controller.loadMoreError != null ||
            (widget.showNoMoreFooter && !controller.hasMore));
    final int itemCount = dataCount + (showFooter ? 1 : 0);
    final ScrollPhysics physics = widget.enableRefresh
        ? AlwaysScrollableScrollPhysics(parent: widget.physics)
        : (widget.physics ?? const ClampingScrollPhysics());

    if (widget.separatorBuilder != null) {
      return ListView.separated(
        controller: _effectiveScrollController,
        primary: widget.primary,
        shrinkWrap: widget.shrinkWrap,
        padding: widget.padding,
        physics: physics,
        itemCount: itemCount,
        itemBuilder: (BuildContext context, int index) {
          if (showFooter && index == itemCount - 1) {
            return _buildFooter(context, controller);
          }
          return widget.itemBuilder(context, controller.items[index], index);
        },
        separatorBuilder: widget.separatorBuilder!,
      );
    }

    return ListView.builder(
      controller: _effectiveScrollController,
      primary: widget.primary,
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      physics: physics,
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        if (showFooter && index == itemCount - 1) {
          return _buildFooter(context, controller);
        }
        return widget.itemBuilder(context, controller.items[index], index);
      },
    );
  }

  /// 构建底部状态区域。
  ///
  /// 可能出现三类状态：
  /// - 正在加载更多
  /// - 加载更多失败
  /// - 没有更多数据
  Widget _buildFooter(
    BuildContext context,
    CorePagedListController<T> controller,
  ) {
    if (controller.isLoadingMore) {
      return widget.loadMoreLoadingBuilder?.call(context) ??
          const _DefaultLoadingMoreState();
    }

    if (controller.loadMoreError != null) {
      return widget.loadMoreErrorBuilder?.call(
            context,
            controller.loadMoreError,
            controller.loadMore,
          ) ??
          _DefaultFooterErrorState(
            message: controller.loadMoreError.toString(),
            onRetry: controller.loadMore,
          );
    }

    return widget.noMoreBuilder?.call(context) ??
        const _DefaultHintState(message: '没有更多了');
  }
}

/// 默认提示态组件。
class _DefaultHintState extends StatelessWidget {
  const _DefaultHintState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 默认底部加载中组件。
class _DefaultLoadingMoreState extends StatelessWidget {
  const _DefaultLoadingMoreState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// 默认首屏错误态组件。
class _DefaultErrorState extends StatelessWidget {
  const _DefaultErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            unawaited(onRetry());
          },
          child: const Text('重试'),
        ),
      ],
    );
  }
}

/// 默认底部错误态组件。
class _DefaultFooterErrorState extends StatelessWidget {
  const _DefaultFooterErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              unawaited(onRetry());
            },
            child: const Text('点击重试'),
          ),
        ],
      ),
    );
  }
}
