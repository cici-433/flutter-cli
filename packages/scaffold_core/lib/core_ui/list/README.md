# Core Paged List 设计说明

## 目标

`core_ui/list` 提供一套可复用的分页列表封装，用于统一业务页面中的以下交互：

- 下拉刷新
- 上拉加载更多
- 首屏加载态
- 空态
- 首屏错误态
- 底部加载更多错误态
- 无更多数据提示

该目录的设计目标不是替代所有列表实现，而是为绝大多数“分页接口 + 列表页”提供统一骨架，降低重复开发成本。

## 目录结构

```text
list/
├─ core_paged_list.dart
├─ core_paged_list_controller.dart
├─ core_paged_list_models.dart
└─ core_paged_list_view.dart
```

各文件职责如下：

- `core_paged_list_models.dart`
  - 定义分页请求参数
  - 定义分页返回结果
  - 定义分页状态枚举
  - 定义统一 fetcher 类型

- `core_paged_list_controller.dart`
  - 管理列表数据
  - 管理分页页码与 `hasMore`
  - 封装 `refresh` / `loadMore` / `retry` / `reset`
  - 向视图层暴露状态

- `core_paged_list_view.dart`
  - 负责将控制器状态映射到 UI
  - 处理 `RefreshIndicator`
  - 监听滚动并触发加载更多
  - 提供默认空态、错误态和底部态

- `core_paged_list.dart`
  - 作为统一导出入口，减少上层直接依赖具体文件

## 核心设计

### 1. 控制器与视图分离

分页数据逻辑放在 `CorePagedListController<T>` 中，列表渲染放在 `CorePagedListView<T>` 中。

这样拆分有几个好处：

- 状态与 UI 解耦，便于单独复用控制器
- 业务方可以只复用控制器，自定义自己的列表界面
- 分页规则集中收敛，避免每个页面都重复维护页码与加载状态

### 2. 用 query/result 抽象分页协议

控制器不直接依赖任何具体接口结构，而是通过下面两个模型与业务约定：

- `CorePagedListQuery`
  - `page`
  - `pageSize`
  - `isRefresh`

- `CorePagedListResult<T>`
  - `items`
  - `hasMore`

只要业务接口可以映射到这两个结构，就可以接入这一套分页能力。

### 3. 首屏状态与底部分离

列表通常存在两类错误：

- 首屏错误：页面没有任何数据，接口失败
- 加载更多错误：页面已有数据，下一页失败

这两类状态的处理体验不同，因此这里做了显式区分：

- 首屏错误由 `status == error && items.isEmpty` 表达
- 底部错误由 `loadMoreError != null` 表达

这样可以避免“已有内容时仍展示整页错误页”的体验问题。

### 4. 自动加载更多触发策略

`CorePagedListView` 内部监听滚动位置，当滚动到距离底部一定阈值时自动触发 `loadMore()`。

相关参数：

- `enableLoadMore`
- `loadMoreTriggerOffset`

默认阈值为 `200`，表示当滚动位置距离底部 200 像素以内时开始请求下一页。

### 5. 保证空页面可下拉刷新

在空态与错误态下，页面往往没有足够内容撑满屏幕。  
为了保证仍然可以触发下拉刷新，组件内部使用了 `AlwaysScrollableScrollPhysics` 包裹占位列表。

这使得：

- 空态可直接下拉刷新
- 首屏错误态可直接下拉刷新

## 状态流转

### 首次进入

当 `autoLoadOnInit = true` 时：

1. 视图挂载
2. 调用 `controller.ensureInitialized()`
3. 自动触发 `refresh()`
4. 根据结果进入以下状态之一：
   - `success`
   - `empty`
   - `error`

### 下拉刷新

1. 调用 `refresh()`
2. 从 `initialPage` 重新请求
3. 清空旧数据并替换为新数据
4. 重置分页信息和底部错误

### 上拉加载更多

1. 滚动接近底部
2. 调用 `loadMore()`
3. 以 `_nextPage` 发起请求
4. 将新数据追加到现有列表尾部
5. 更新 `_nextPage` 与 `hasMore`

## 使用示例

```dart
final controller = CorePagedListController<OrderModel>(
  fetcher: (query) async {
    final response = await repository.fetchOrders(
      page: query.page,
      pageSize: query.pageSize,
    );

    return CorePagedListResult<OrderModel>(
      items: response.records,
      hasMore: response.hasMore,
    );
  },
);
```

```dart
CorePagedListView<OrderModel>(
  controller: controller,
  itemBuilder: (context, item, index) {
    return ListTile(
      title: Text(item.title),
    );
  },
)
```

## 可扩展点

当前版本已经支持通过参数覆盖默认状态 UI：

- `initialLoadingBuilder`
- `emptyBuilder`
- `errorBuilder`
- `loadMoreLoadingBuilder`
- `loadMoreErrorBuilder`
- `noMoreBuilder`

后续如果需要扩展，也建议保持以下原则：

- 分页控制逻辑继续留在 controller
- 展示层能力继续留在 view
- 不在基础组件里直接耦合具体业务状态管理框架

## 适用边界

适合：

- 标准页码分页接口
- 瀑布流以外的普通纵向列表
- 绝大多数“列表页 + 详情页”场景

暂不直接覆盖：

- 多分组分页列表
- 吸顶分段列表
- 游标型分页且含复杂去重策略的场景
- Grid、瀑布流等非 ListView 布局

这类场景可以继续复用 `CorePagedListController<T>`，但视图层建议按业务单独封装。
