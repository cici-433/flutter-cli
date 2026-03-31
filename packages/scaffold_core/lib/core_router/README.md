# core_router

## 目标

core_router 提供一个与具体路由库无关的最小路由抽象，用于：

- 让业务层依赖稳定接口，而不是依赖某个路由库的 API
- 便于在不同工程中替换路由方案（Navigator 1.0 / go_router / auto_route 等）
- 便于测试（可注入一个内存实现或 mock 实现）

## 核心抽象

[CoreRouter](core_router.dart) 是唯一必须遵守的接口，设计为“最小可用集合”：

- `push(location, extra)`：入栈导航
- `replace(location, extra)`：替换当前页面
- `go(location, extra)`：跳转并清空栈（应用可根据路由库能力做等价实现）
- `pop([result]) / canPop()`：返回能力
- `popUntil(location)`：返回到指定页面
- `navigatorKey`：支持在无 BuildContext 的场景触发导航

其中：

- `location` 作为统一的路由标识，通常映射为路由路径（如 `/login`）
- `extra` 作为透传参数，适配到不同路由库的 arguments/extra

## 默认实现

[NavigatorCoreRouter](navigator_core_router.dart) 是默认实现，基于 Flutter 原生 Navigator 1.0：

- `push` -> `NavigatorState.pushNamed`
- `replace` -> `NavigatorState.pushReplacementNamed`
- `go` -> `NavigatorState.pushNamedAndRemoveUntil`（predicate 恒为 false，用于清空栈）
- `extra` -> `RouteSettings.arguments`

当 `navigatorKey.currentState` 为空（例如尚未挂载到 App）时，相关方法会返回一个已完成的 Future，避免抛异常。

## 如何适配其它路由库

在应用层创建一个适配器，实现 `CoreRouter`，把接口映射到你选择的路由库：

- go_router：可用 `GoRouter.push/go/pop` 等方法完成映射
- auto_route：可用 `StackRouter.push/replace` 等方法完成映射

建议：

- 由应用层负责“location 与具体路由库的 route name/path”的映射规则
- 在依赖注入容器（Scope）里注入 `CoreRouter`，业务只依赖 `CoreRouter`

