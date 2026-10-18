import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models.dart';

/// h_i = sha256(h_{i-1} || sha256(frame_i) || uint64be(timestamp_ms))
/// h_0 = 32 zero bytes. Same as bridge/src/hash.ts.
Uint8List sha256Bytes(List<int> data) => Uint8List.fromList(sha256.convert(data).bytes);

String hexOf(List<int> bytes) =>
    '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

Uint8List u64be(int n) {
  final out = Uint8List(8);
  var x = n;
  for (var i = 7; i >= 0; i--) {
    out[i] = x & 0xff;
    x >>= 8;
  }
  return out;
}

CaptureChain hashChain(List<({Uint8List bytes, int timestampMs})> frames, {int fps = 1}) {
  if (frames.isEmpty) {
    throw ArgumentError('need at least one frame');
  }
  var h = Uint8List(32);
  final hashes = <String>[];
  for (final f in frames) {
    final fh = sha256Bytes(f.bytes);
    hashes.add(hexOf(fh));
    final cat = Uint8List(72);
    cat.setAll(0, h);
    cat.setAll(32, fh);
    cat.setAll(64, u64be(f.timestampMs));
    h = sha256Bytes(cat);
  }
  return CaptureChain(
    root: hexOf(h),
    frameCount: frames.length,
    fps: fps,
    startMs: frames.first.timestampMs,
    endMs: frames.last.timestampMs,
    frameHashes: hashes,
  );
}
