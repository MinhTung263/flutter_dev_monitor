import 'package:dio/dio.dart';
import 'package:flutter_dev_monitor/flutter_dev_monitor.dart';

final dio = Dio(
  BaseOptions(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    headers: {
      'Authorization': 'Bearer fake-token-for-testing',
      'X-App-Version': '1.1.1',
      'Accept': 'application/json',
    },
  ),
)..interceptors.add(DevMonitor.interceptor);
