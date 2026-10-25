import 'package:connectrpc/connect.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:sprout/data/rpc/rpc_http.dart';

/// The Connect transport to the Sprout API, on the same base URL as REST.
///
/// It sends the same Authorization and X-Utc-Offset-Minutes headers as
/// [ApiClient], so the server signs the caller in the same way for both.
Transport createRpcTransport({
  required String baseUrl,
  required Future<String?> Function() token,
  HttpClient? httpClient,
}) {
  return protocol.Transport(
    baseUrl: baseUrl,
    // JSON keeps calls readable in DevTools. ProtoCodec() is smaller on the
    // wire, and the server accepts both.
    codec: const JsonCodec(),
    httpClient: httpClient ?? createRpcHttpClient(),
    interceptors: [_sproutHeaders(token)],
  );
}

Interceptor _sproutHeaders(Future<String?> Function() token) {
  return <I extends Object, O extends Object>(next) {
    return (request) async {
      final access = await token();
      request.headers['authorization'] = 'Bearer ${access ?? ''}';
      request.headers['x-utc-offset-minutes'] =
          DateTime.now().timeZoneOffset.inMinutes.toString();
      return next(request);
    };
  };
}
