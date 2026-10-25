// Android and other native builds send Connect calls through dart:io. Web
// builds use the browser's fetch, which dart:io is not available for.
export 'rpc_http_io.dart' if (dart.library.js_interop) 'rpc_http_web.dart';
