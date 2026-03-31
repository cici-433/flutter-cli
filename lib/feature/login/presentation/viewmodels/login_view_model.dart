import 'package:scaffold_core/core_common/module_event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scaffold_demo/app/app_scope.dart';
import 'package:flutter_scaffold_demo/domain/auth/login_use_case.dart';
import 'package:flutter_scaffold_demo/domain/user/user_session.dart';

/// 登录模块的“状态控制器 + Provider”实现
///
/// 设计要点：
/// - 使用 Riverpod 的 Notifier 系列承担“ViewModel 职责”，统一管理 Loading/Data/Error；
/// - 对外通过 Provider 暴露，UI 只需 `ref.watch()` 订阅状态，`ref.read(... .notifier)` 触发动作；
/// - 状态类型采用 `AsyncValue<UserSession?>`，天然表达三态：
///   - `AsyncLoading()`：加载中/执行中
///   - `AsyncData(UserSession?)`：成功（空表示未登录）
///   - `AsyncError(error, stack)`：失败（UI 可直接根据 error 展示文案）
/// - 依赖的业务能力（LoginUseCase、ModuleEventBus）通过更细粒度的 provider 注入，
///   避免直接依赖“大而全”的 AppScope，提升可替换性与测试友好度。
///
/// 生命周期：
/// - 使用 `AutoDisposeNotifier`，当页面/监听离开作用域后自动释放，避免泄漏；
/// - `build()` 提供初始状态；具体执行（login）由 UI 触发。
///
/// 交互约定（供 UI 使用）：
/// - 订阅：`final state = ref.watch(loginControllerProvider);`
/// - 渲染：`state.when(loading: ..., error: ..., data: ...)`
/// - 动作：`ref.read(loginControllerProvider.notifier).login(account:..., password:...)`
///
/// 日志/事件：
/// - 登录成功后，通过 `ModuleEventBus` 发布 `auth_changed` 事件，供其他模块感知。
///   这是一种“单向通知 + 共享状态服务感知”的组合做法，减少模块耦合。
final loginControllerProvider =
    AutoDisposeNotifierProvider<LoginController, AsyncValue<UserSession?>>(
      LoginController.new,
    );

class LoginController extends AutoDisposeNotifier<AsyncValue<UserSession?>> {
  /// 初始化状态
  ///
  /// - 登录页初次展示时，认为“未登录且无加载”，使用 `AsyncData(null)` 表示。
  /// - 若需要支持“自动登录/会话恢复”，可在这里读取持久化快照后返回对应的 `AsyncData(session)`。
  @override
  AsyncValue<UserSession?> build() {
    return const AsyncData(null);
  }

  /// 执行登录
  ///
  /// 流程：
  /// 1. 置状态为 `AsyncLoading`，触发 UI Loading；
  /// 2. 调用 `LoginUseCase` 执行登录（包含远程/本地数据源逻辑），用 `AsyncValue.guard` 包裹：
  ///    - 成功：返回 `AsyncData(UserSession)`，UI 可感知到成功并自动收敛 Loading；
  ///    - 失败：返回 `AsyncError`，UI 通过 `when(error: ...)` 统一展示错误；
  /// 3. 成功后通过 `ModuleEventBus` 广播 `auth_changed` 事件，通知其他模块刷新。
  ///
  /// 说明：
  /// - 这里不直接处理跳转，由页面在监听到 `AsyncData(session != null)` 后执行路由返回；
  /// - 错误不在这里转文案，保持“状态层只做事实表达”，文案在 UI 层根据 error 类型统一处理。
  Future<void> login({
    required String account,
    required String password,
  }) async {
    final LoginUseCase loginUseCase = ref.read(loginUseCaseProvider);
    final ModuleEventBus eventBus = ref.read(eventBusProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final UserSession newSession = await loginUseCase.execute(
        account: account,
        password: password,
      );
      eventBus.publish(
        ModuleEvent(
          sourceModule: 'login',
          topic: 'auth_changed',
          message: '用户 ${newSession.userName} 已登录',
          timestamp: DateTime.now(),
        ),
      );
      return newSession;
    });
  }
}
