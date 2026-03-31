import 'dart:async';

import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/domain/auth/auth_session_service.dart';
import 'package:flutter_scaffold_demo/domain/auth/logout_use_case.dart';
import 'package:flutter_scaffold_demo/domain/order/order_query_service.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

/// Mine 模块的“状态控制器 + Provider”实现（统一状态管理示例）
///
/// 这个文件展示了在 Riverpod 体系下，如何把传统 ViewModel（ChangeNotifier）拆为：
/// - 多个“输入源 Provider”（StreamProvider）：负责把外部变化引入状态层
/// - 一个“聚合状态 Provider”（AutoDisposeNotifierProvider）：负责聚合状态与业务动作
///
/// 目标：
/// - UI 层只订阅 MineState 并渲染，不再自行维护 loading/error；
/// - 业务动作（refresh、logout）集中在控制器内，便于测试与复用；
/// - 跨模块通信通过事件总线（ModuleEventBus）“单向通知”，其他模块可订阅并做响应；
/// - 共享状态（登录态）通过 AuthSessionService 的 stream 统一分发，模块无需直接耦合其他模块实现。
///
/// 典型 UI 用法：
/// - 订阅：`final vm = ref.watch(mineControllerProvider);`
/// - 渲染：`vm.orderCount.when(loading/error/data)`
/// - 动作：`ref.read(mineControllerProvider.notifier).logout()`
final mineControllerProvider =
    AutoDisposeNotifierProvider<MineController, MineState>(MineController.new);

/// 登录会话的输入源（共享状态）
///
/// - `AuthSessionService` 是“会话事实来源”（single source of truth）
/// - 这里把它转换为 StreamProvider，供 MineController 监听并同步到自己的聚合状态里
/// - yield currentSession 的目的是：让订阅者立即拿到当前快照，而不用等第一条 stream 事件
final mineAuthSessionProvider = StreamProvider<UserSession?>((ref) async* {
  /// 通过 `authSessionServiceProvider` 获取“会话事实来源”
  ///
  /// - 这里用 `ref.read(...)` 而不是 `ref.watch(...)`：
  ///   - 该 provider 输出的是一个 Stream，本身会持续产出后续事件；
  ///   - AuthSessionService 本身是一个稳定的依赖（来自 AppScope 注入），通常不会在运行期被替换；
  ///   - 即使在测试/特定作用域 override 了 authSessionServiceProvider，这个 StreamProvider 也会重新构建，
  ///     从而拿到新的实现。
  ///
  /// 取到 service 后，下面会先 yield 当前快照，再 yield* 后续变化流。
  final AuthSessionService authSessionService = ref.read(
    authSessionServiceProvider,
  );
  yield authSessionService.currentSession;
  yield* authSessionService.sessionStream;
});

/// 模块事件的输入源（跨模块通信）
///
/// - 事件总线是广播型通道：各模块可 publish/subscribe
/// - MineController 监听事件：
///   - auth_changed：更新“最近认证事件”展示
///   - order 模块事件：触发订单数量刷新（演示模块间联动）
final mineModuleEventProvider = StreamProvider<ModuleEvent>((ref) {
  return ref.read(eventBusProvider).stream;
});

/// Mine 页面聚合状态（UI 只读）
///
/// 字段说明：
/// - session：当前登录会话快照（可能为 null）
/// - orderCount：订单总数（用 AsyncValue 统一表达 loading/data/error）
/// - lastAuthEvent：最近一次认证相关事件文案（来自事件总线）
///
/// 设计选择：
/// - 将“可失败/可加载”的字段定义为 AsyncValue&lt;T&gt;，而不是额外维护 bool loading + String? error
/// - 这样 UI 可以统一使用 `when(loading/error/data)`，避免各模块重复造 Loading/Error 逻辑
class MineState {
  const MineState({
    required this.session,
    required this.orderCount,
    required this.lastAuthEvent,
  });

  final UserSession? session;
  final AsyncValue<int> orderCount;
  final String lastAuthEvent;

  /// 不可变状态更新（copy-with 模式）
  ///
  /// Riverpod 的 Notifier 推荐使用不可变 state：
  /// - 更容易定位状态来源（每次变更都是一次明确的 state 替换）
  /// - 更适合与 AsyncValue/数据类组合
  MineState copyWith({
    UserSession? session,
    AsyncValue<int>? orderCount,
    String? lastAuthEvent,
  }) {
    return MineState(
      session: session ?? this.session,
      orderCount: orderCount ?? this.orderCount,
      lastAuthEvent: lastAuthEvent ?? this.lastAuthEvent,
    );
  }
}

/// Mine 模块的控制器（承担 ViewModel 职责）
///
/// 关键点：
/// - 继承 `AutoDisposeNotifier<MineState>`：
///   - state 为同步数据类 MineState（其中包含 AsyncValue 字段）
///   - 自动释放：当页面不再订阅时自动 dispose，避免泄漏
/// - 在 `build()` 中完成：
///   - 监听输入源（登录态、事件总线），将外部变化汇入 MineState
///   - 返回初始 state，并触发一次订单总数的“异步刷新”
/// - 业务动作方法：
///   - refreshOrderCount：拉取订单数并更新 state.orderCount（loading/data/error）
///   - logout：执行退出并广播 auth_changed 事件
class MineController extends AutoDisposeNotifier<MineState> {
  /// 初始化与订阅外部输入源
  ///
  /// 注意：
  /// - `ref.listen` 会在 Provider 存活期间持续监听，Provider dispose 时自动取消
  /// - 不建议在这里做重 IO 的同步阻塞逻辑；异步动作通过后续方法触发
  @override
  MineState build() {
    ref.listen(mineAuthSessionProvider, (_, next) {
      state = state.copyWith(session: next.valueOrNull);
    });
    ref.listen(mineModuleEventProvider, (_, next) {
      final event = next.valueOrNull;
      if (event == null) return;
      if (event.topic == 'auth_changed') {
        state = state.copyWith(lastAuthEvent: event.message);
      }
      if (event.sourceModule == 'order') {
        refreshOrderCount(forceRefresh: true);
      }
    });

    final initial = MineState(
      session: ref.read(authSessionServiceProvider).currentSession,
      orderCount: const AsyncValue.data(0),
      lastAuthEvent: '暂无',
    );

    /// 触发一次“初始化刷新”
    ///
    /// 这里用 Future(() => ...) 的写法，避免在 build 的同步阶段直接改 state，
    /// 让初始化流程更稳定（build 返回 initial 后，再异步进入 loading -> data/error）。
    Future<void>(() => refreshOrderCount(forceRefresh: false));
    return initial;
  }

  /// 刷新订单总数
  ///
  /// - `forceRefresh` 用于控制是否绕过缓存（由底层 OrderQueryService 决定）
  /// - 更新策略：
  ///   1) 先把 orderCount 置为 AsyncLoading，UI 进入 loading 展示
  ///   2) 用 AsyncValue.guard 统一捕获异常，得到 AsyncData/AsyncError
  ///   3) 写回 state.orderCount，UI 自动更新
  Future<void> refreshOrderCount({required bool forceRefresh}) async {
    state = state.copyWith(orderCount: const AsyncLoading());
    final OrderQueryService orderQueryService = ref.read(
      orderQueryServiceProvider,
    );
    final result = await AsyncValue.guard(
      () => orderQueryService.fetchOrderCount(forceRefresh: forceRefresh),
    );
    state = state.copyWith(orderCount: result);
  }

  /// 退出登录
  ///
  /// - 这里的退出动作是同步返回当前 session（由 LogoutUseCase 决定实现）
  /// - 退出后广播 `auth_changed`，让其他模块（如 Home/Mine 等）统一感知并刷新界面
  /// - 具体“导航跳转/Toast 提示”留给 UI 层处理，保持控制器职责聚焦
  void logout() {
    final LogoutUseCase logoutUseCase = ref.read(logoutUseCaseProvider);
    final ModuleEventBus eventBus = ref.read(eventBusProvider);
    final current = logoutUseCase.execute();
    if (current == null) {
      return;
    }
    eventBus.publish(
      ModuleEvent(
        sourceModule: 'mine',
        topic: 'auth_changed',
        message: '用户 ${current.userName} 已退出登录',
        timestamp: DateTime.now(),
      ),
    );
  }
}
