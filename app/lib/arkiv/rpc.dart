import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models.dart';

class QueryPage {
  final List<ArkivEntity> entities;
  final String? cursor;
  final String blockNumber;
  QueryPage(this.entities, this.cursor, this.blockNumber);
}

class ArkivRpc {
  int _id = 1;
  Uri get _uri => Uri.parse(Config.rpc);

  Future<dynamic> _call(String method, List<dynamic> params) async {
    final id = _id++;
    final res = await http.post(
      _uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}),
    );
    if (res.statusCode != 200) {
      throw Exception('RPC HTTP ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw Exception('RPC $method: ${body['error']}');
    }
    return body['result'];
  }

  Future<String> getBalance(String address) async {
    final r = await _call('eth_getBalance', [address, 'latest']);
    return BigInt.parse('$r'.replaceFirst('0x', ''), radix: 16).toString();
  }

  Future<ArkivEntity?> getEntity(String key) async {
    final r = await _call('arkiv_getEntity', [key]);
    if (r == null) return null;
    return _parseEntity(r as Map<String, dynamic>);
  }

  Future<QueryPage> query(String expression, {int limit = 50, String? cursor}) async {
    final opts = <String, dynamic>{
      'limit': '0x${limit.toRadixString(16)}',
      'select': {
        'key': true,
        'owner': true,
        'creator': true,
        'createdAt': true,
        'expiresAt': true,
        'payload': true,
        'attributes': true,
        'contentType': true,
        'creationFlags': true,
      },
    };
    if (cursor != null) opts['cursor'] = cursor;
    final r = await _call('arkiv_query', [expression, opts]) as Map<String, dynamic>;
    final data = (r['data'] as List? ?? []).cast<dynamic>();
    final entities = data.map((e) => _parseEntity(e as Map<String, dynamic>)).toList();
    return QueryPage(entities, r['cursor'] as String?, '${r['blockNumber'] ?? ''}');
  }

  Future<QueryPage> stories({
    String? state,
    String? city,
    String? category,
    String? createdBy,
    String? ownedBy,
    String? fromMs,
    String? toMs,
    String? cursor,
  }) async {
    final parts = <String>["app = str('swatantra')", "type = str('story')"];
    if (state != null && state.isNotEmpty) parts.add("state = str('${_esc(state)}')");
    if (city != null && city.isNotEmpty) parts.add("city = str('${_esc(city)}')");
    if (category != null && category.isNotEmpty) {
      parts.add("category = str('${_esc(category)}')");
    }
    if (fromMs != null && fromMs.isNotEmpty) parts.add('created_at_ms >= u64($fromMs)');
    if (toMs != null && toMs.isNotEmpty) parts.add('created_at_ms <= u64($toMs)');
    if (createdBy != null && createdBy.isNotEmpty) {
      parts.add('\$creator = addr($createdBy)');
    }
    if (ownedBy != null && ownedBy.isNotEmpty) {
      parts.add('\$owner = addr($ownedBy)');
    }
    final page = await query(parts.join(' AND '), limit: 100, cursor: cursor);
    page.entities.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return page;
  }

  String _esc(String s) => s.replaceAll("'", '');

  ArkivEntity _parseEntity(Map<String, dynamic> j) {
    final attrs = <String, Attr>{};
    final raw = j['attributes'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          attrs['${item['name']}'] =
              Attr('${item['type']}', _attrValue('${item['type']}', item['value']));
        }
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          attrs['$k'] = Attr('${v['type']}', _attrValue('${v['type']}', v['value']));
        }
      });
    }
    Map<String, dynamic> payload = {};
    final p = j['payload'];
    if (p is String && p.startsWith('0x')) {
      try {
        payload = jsonDecode(utf8.decode(_hexBytes(p))) as Map<String, dynamic>;
      } catch (_) {}
    } else if (p is Map) {
      payload = Map<String, dynamic>.from(p);
    }
    return ArkivEntity(
      key: '${j['key'] ?? ''}',
      owner: '${j['owner'] ?? ''}',
      creator: '${j['creator'] ?? ''}',
      createdAt: _qty('${j['createdAt'] ?? ''}'),
      expiresAt: _qty('${j['expiresAt'] ?? ''}'),
      payload: payload,
      attributes: attrs,
    );
  }

  dynamic _attrValue(String type, dynamic value) {
    if (type == 'u64' || type == 'u256') {
      final s = '$value';
      if (s.startsWith('0x')) {
        return BigInt.parse(s.substring(2), radix: 16).toString();
      }
      return s;
    }
    return value;
  }

  String _qty(String s) {
    if (s.startsWith('0x')) {
      return BigInt.parse(s.substring(2), radix: 16).toString();
    }
    return s;
  }

  Uint8List _hexBytes(String hex) {
    final h = hex.startsWith('0x') ? hex.substring(2) : hex;
    final out = Uint8List(h.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
