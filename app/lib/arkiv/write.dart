import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import '../config.dart';
import '../wallet.dart';
import 'hash.dart';

/// Direct `execute` writes for Android / anything without the JS SDK bridge.
/// Same precompile as `@arkiv-network/sdk`: `0x4400…0044`.
const arkivPrecompile = '0x4400000000000000000000000000000000000044';

const _typeBool = 1;
const _typeI32 = 2;
const _typeU64 = 3;
const _typeU256 = 4;
const _typeBytes32 = 6;
const _typeBytes = 7;
const _typeStr = 8;
const _typeAddr = 9;
const _typeKey = 10;

const _opCreate = 1;
const _opExtend = 3;

final _execute = ContractFunction('execute', [
  FunctionParameter(
    'ops',
    DynamicLengthArray(
      type: TupleType([
        UintType(length: 8),
        DynamicBytes(),
      ]),
    ),
  ),
]);

final _createPayload = TupleType([
  UintType(length: 128),
  UintType(length: 64),
  UintType(length: 64),
  UintType(length: 8),
  DynamicLengthArray(
    type: TupleType([
      FixedBytes(32),
      UintType(length: 8),
      DynamicBytes(),
    ]),
  ),
]);

final _extendPayload = TupleType([
  FixedBytes(32),
  UintType(length: 64),
  UintType(length: 64),
]);

Uint8List _ident32(String name) {
  final raw = utf8.encode(name);
  if (raw.length > 32) throw ArgumentError('attribute name too long: $name');
  final out = Uint8List(32);
  out.setAll(0, raw);
  return out;
}

Uint8List _word(BigInt v) {
  final sink = LengthTrackingByteSink();
  const UintType().encode(v, sink);
  return sink.asBytes();
}

class _Cell {
  _Cell(this.name, this.typeId, this.value);
  final String name;
  final int typeId;
  final Uint8List value;
}

Uint8List _encodeCreate({
  required List<_Cell> attrs,
  required int flags,
  required int minLifetimeBlocks,
}) {
  final sorted = [...attrs]..sort((a, b) {
      final na = _ident32(a.name);
      final nb = _ident32(b.name);
      for (var i = 0; i < 32; i++) {
        final d = na[i] - nb[i];
        if (d != 0) return d;
      }
      return 0;
    });
  final salt = BigInt.from(Random.secure().nextInt(1 << 30)) * BigInt.from(1 << 30) +
      BigInt.from(Random.secure().nextInt(1 << 30));
  final encodedAttrs = sorted
      .map((c) => <dynamic>[_ident32(c.name), BigInt.from(c.typeId), c.value])
      .toList();
  final sink = LengthTrackingByteSink();
  _createPayload.encode([
    salt,
    BigInt.zero,
    BigInt.from(minLifetimeBlocks),
    BigInt.from(flags),
    encodedAttrs,
  ], sink);
  return sink.asBytes();
}

Future<Map<String, String>> createEntity({
  required Map<String, dynamic> payload,
  required List<_Cell> attributes,
  required int days,
  bool readonly = true,
  bool permissionlessExtension = true,
}) async {
  final pk = WalletStore.privateKey;
  if (pk == null) throw StateError('no burner wallet');
  final body = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  final cells = [
    ...attributes,
    _Cell('\$payload', _typeBytes, body),
    _Cell('\$contentType', _typeStr, Uint8List.fromList(utf8.encode('application/json'))),
  ];
  var flags = 0;
  if (readonly) flags |= 1;
  if (permissionlessExtension) flags |= 2;
  final opData = _encodeCreate(
    attrs: cells,
    flags: flags,
    minLifetimeBlocks: days * 43200, // 86400s / 2s block
  );
  return _send([[BigInt.from(_opCreate), opData]]);
}

_Cell str(String name, String v) => _Cell(name, _typeStr, Uint8List.fromList(utf8.encode(v)));
_Cell u64(String name, int v) => _Cell(name, _typeU64, _word(BigInt.from(v)));
_Cell i32(String name, int v) => _Cell(name, _typeI32, _word(BigInt.from(v)));
_Cell u256(String name, BigInt v) => _Cell(name, _typeU256, _word(v));
_Cell b32(String name, String hex) => _Cell(name, _typeBytes32, _hex32(hex));
_Cell key(String name, String hex) => _Cell(name, _typeKey, _hex32(hex));
_Cell addr(String name, String a) {
  final h = a.startsWith('0x') ? a.substring(2) : a;
  final raw = hexToBytes(h);
  final word = Uint8List(32);
  word.setAll(32 - raw.length, raw);
  return _Cell(name, _typeAddr, word);
}

_Cell boolCell(String name, bool v) => _Cell(name, _typeBool, _word(v ? BigInt.one : BigInt.zero));

Uint8List _hex32(String hex) {
  final h = hex.startsWith('0x') ? hex.substring(2) : hex;
  final raw = hexToBytes(h);
  if (raw.length != 32) throw ArgumentError('need 32 bytes, got ${raw.length}');
  return Uint8List.fromList(raw);
}

Future<Map<String, String>> _send(List<List<dynamic>> ops) async {
  final pk = WalletStore.privateKey!;
  final cred = EthPrivateKey.fromHex(pk);
  final client = Web3Client(Config.rpc, Client());
  try {
    final data = _execute.encodeCall([ops]);
    final hash = await client.sendTransaction(
      cred,
      Transaction(
        to: EthereumAddress.fromHex(arkivPrecompile),
        data: data,
        maxGas: 2500000,
        gasPrice: await client.getGasPrice(),
      ),
      chainId: Config.chainId,
    );
    TransactionReceipt? receipt;
    for (var i = 0; i < 40; i++) {
      receipt = await client.getTransactionReceipt(hash);
      if (receipt != null) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    String? entityKey;
    final createdTopic = bytesToHex(
      keccakUtf8('EntityCreated(bytes32,address,uint64,uint8)'),
      include0x: true,
    );
    for (final log in receipt?.logs ?? const <FilterEvent>[]) {
      final topics = log.topics ?? const <String?>[];
      if (topics.isEmpty || topics.first == null) continue;
      if (topics.first!.toLowerCase() != createdTopic.toLowerCase()) continue;
      if (topics.length > 1) entityKey = topics[1];
    }
    return {'txHash': hash.startsWith('0x') ? hash : '0x$hash', 'entityKey': entityKey ?? ''};
  } finally {
    client.dispose();
  }
}

Future<Map<String, String>> createStoryDart({
  required String title,
  required String body,
  required String city,
  required String state,
  required String category,
  String mediaUrl = '',
  String mediaHash = '',
  String captureRoot = '',
  String? captureKey,
  String? journalistKey,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final attrs = <_Cell>[
    str('app', Config.appAttr),
    str('type', 'story'),
    str('city', city),
    str('state', state),
    str('category', category),
    u64('created_at_ms', now),
    if (captureKey != null && captureKey.isNotEmpty) key('capture_key', captureKey),
    if (journalistKey != null && journalistKey.isNotEmpty) key('journalist_key', journalistKey),
  ];
  return createEntity(
    payload: {
      'title': title,
      'body': body,
      'mediaUrl': mediaUrl,
      'mediaHash': mediaHash,
      'captureRoot': captureRoot,
      'synthetic': true,
    },
    attributes: attrs,
    days: 180,
  );
}

Future<Map<String, String>> createCaptureDart({
  required String root,
  required int frameCount,
  required int fps,
  required int startMs,
  required int endMs,
  required String city,
  String mediaUrl = '',
  String? storyKey,
}) {
  final attrs = <_Cell>[
    str('app', Config.appAttr),
    str('type', 'capture'),
    b32('chain_root', root),
    i32('frame_count', frameCount),
    i32('fps', fps),
    u64('start_ms', startMs),
    u64('end_ms', endMs),
    u64('created_at_ms', DateTime.now().millisecondsSinceEpoch),
    str('city', city),
    if (storyKey != null && storyKey.isNotEmpty) key('story_key', storyKey),
  ];
  return createEntity(
    payload: {
      'algo': 'h_i = sha256(h_{i-1} || sha256(frame_i) || uint64be(ts_ms)); h_0 = 32 zero bytes',
      'mediaUrl': mediaUrl,
      'whyOffArkiv': 'Media files stay off Arkiv because of size and cost (payload cap 128 KiB).',
    },
    attributes: attrs,
    days: 365,
  );
}

Future<Map<String, String>> createJournalistDart({
  required String nullifier,
  String? state,
  String displayName = '',
  String bio = '',
}) {
  final attrs = <_Cell>[
    str('app', Config.appAttr),
    str('type', 'journalist'),
    b32('nid', nullifier),
    boolCell('test_mode', true),
    u64('created_at_ms', DateTime.now().millisecondsSinceEpoch),
    if (state != null && state.isNotEmpty) str('state', state),
  ];
  return createEntity(
    payload: {'displayName': displayName, 'bio': bio, 'testMode': true},
    attributes: attrs,
    days: 365,
    readonly: true,
    permissionlessExtension: false,
  );
}

Future<Map<String, String>> createTipDart({
  required String storyKey,
  required String to,
  required String amountEth,
  String note = '',
}) async {
  final pk = WalletStore.privateKey;
  if (pk == null) throw StateError('no burner wallet');
  final cred = EthPrivateKey.fromHex(pk);
  final client = Web3Client(Config.rpc, Client());
  try {
    final wei = EtherAmount.fromBase10String(EtherUnit.ether, amountEth);
    final transferTx = await client.sendTransaction(
      cred,
      Transaction(
        to: EthereumAddress.fromHex(to),
        value: wei,
        maxGas: 21000,
        gasPrice: await client.getGasPrice(),
      ),
      chainId: Config.chainId,
    );
    final created = await createEntity(
      payload: {'note': note, 'testnet': true, 'token': 'GLM'},
      attributes: [
        str('app', Config.appAttr),
        str('type', 'tip'),
        key('story_key', storyKey),
        u256('amount_wei', wei.getInWei),
        u64('created_at_ms', DateTime.now().millisecondsSinceEpoch),
        addr('to_addr', to),
      ],
      days: 365,
      permissionlessExtension: false,
    );
    return {
      'transferTx': transferTx.startsWith('0x') ? transferTx : '0x$transferTx',
      'entityKey': created['entityKey'] ?? '',
      'entityTx': created['txHash'] ?? '',
    };
  } finally {
    client.dispose();
  }
}

Future<Map<String, String>> extendStoryDart(String entityKey) async {
  final pk = WalletStore.privateKey;
  if (pk == null) throw StateError('no burner wallet');
  final sink = LengthTrackingByteSink();
  _extendPayload.encode([
    _hex32(entityKey),
    BigInt.zero,
    BigInt.from(180 * 43200),
  ], sink);
  return _send([
    [BigInt.from(_opExtend), sink.asBytes()],
  ]);
}

/// Used by tests — Ident32 is left-aligned UTF-8.
String ident32Hex(String name) => hexOf(_ident32(name));
