import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

bool get arkivJsAvailable => globalContext.has('SwatantraArkiv');

@JS('SwatantraArkiv.call')
external JSPromise<JSAny?> _call(JSString method, JSString args);

Future<Map<String, dynamic>> arkivJs(String method, [Map<String, dynamic>? args]) async {
  final promise = _call(method.toJS, jsonEncode(args ?? {}).toJS);
  final js = await promise.toDart;
  final raw = (js as JSString).toDart;
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {'_': decoded};
}
