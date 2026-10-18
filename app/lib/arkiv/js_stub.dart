Future<Map<String, dynamic>> arkivJs(String method, [Map<String, dynamic>? args]) async {
  throw UnsupportedError('Arkiv writes need the JS SDK bridge (Flutter web). Method: $method');
}

bool get arkivJsAvailable => false;
