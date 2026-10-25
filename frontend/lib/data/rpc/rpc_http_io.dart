import 'dart:io' as io;

import 'package:connectrpc/connect.dart';
import 'package:connectrpc/io.dart' as connect_io;

HttpClient createRpcHttpClient() => connect_io.createHttpClient(io.HttpClient());
