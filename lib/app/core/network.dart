import 'package:scaffold_core/core_network/network_client.dart';
import 'package:scaffold_core/core_network/types.dart';

class AppNetwork {
  final NetworkClient client = NetworkClient(
    options: const NetworkClientOptions(
      baseUrl: 'https://api.example.com', // 按需修改为正式环境地址
    ),
  );
}
