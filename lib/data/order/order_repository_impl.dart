import 'package:flutter_scaffold_demo/data/order/order_local_data_source.dart';
import 'package:flutter_scaffold_demo/data/order/order_remote_data_source.dart';
import 'package:flutter_scaffold_demo/domain/order/order_info.dart';
import 'package:flutter_scaffold_demo/domain/order/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl({
    required OrderRemoteDataSource remoteDataSource,
    required OrderLocalDataSource localDataSource,
    Duration cacheMaxAge = const Duration(seconds: 10),
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _cacheMaxAge = cacheMaxAge;

  final OrderRemoteDataSource _remoteDataSource;
  final OrderLocalDataSource _localDataSource;
  final Duration _cacheMaxAge;

  @override
  Future<List<OrderInfo>> fetchOrders({bool forceRefresh = false}) async {
    final cached = _localDataSource.readOrders();
    final lastSavedAt = _localDataSource.lastSavedAt;
    final cacheValid = cached.isNotEmpty &&
        lastSavedAt != null &&
        DateTime.now().difference(lastSavedAt) <= _cacheMaxAge;
    if (!forceRefresh && cacheValid) {
      return cached;
    }
    final fresh = await _remoteDataSource.fetchOrders();
    await _localDataSource.saveOrders(fresh);
    return fresh;
  }

  @override
  Future<OrderInfo> createOrder({
    required String title,
    required double amount,
  }) {
    return _remoteDataSource.createOrder(title: title, amount: amount);
  }

  @override
  Future<void> saveOrders(List<OrderInfo> orders) {
    return _localDataSource.saveOrders(orders);
  }

  @override
  List<OrderInfo> readCachedOrders() {
    return _localDataSource.readOrders();
  }
}
