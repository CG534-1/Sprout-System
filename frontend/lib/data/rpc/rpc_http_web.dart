import 'package:connectrpc/connect.dart';
import 'package:connectrpc/web.dart' as connect_web;

HttpClient createRpcHttpClient() => connect_web.createHttpClient();
