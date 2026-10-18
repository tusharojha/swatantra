import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models.dart';

/// Capture chain (district-bound):
///
/// ```
/// h_0     = 32 zero bytes
/// place   = SHA-256( utf8(district) || 0x00 || utf8(geo_cell) )
/// frame_i = SHA-256(frame bytes)
/// h_i     = SHA-256( h_{i-1} || frame_i || uint64be(ts_ms) || place )
/// root    = h_n
/// ```
///
/// Precise GPS is never in the chain — only the coarse district name and 0.1° cell.
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

Uint8List placeHash(String district, String geoCell) {
  final a = utf8.encode(district);
  final b = utf8.encode(geoCell);
  final cat = Uint8List(a.length + 1 + b.length);
  cat.setAll(0, a);
  cat[a.length] = 0;
  cat.setAll(a.length + 1, b);
  return sha256Bytes(cat);
}

CaptureChain hashChain(
  List<({Uint8List bytes, int timestampMs})> frames, {
  int fps = 1,
  String district = '',
  String geoCell = '',
}) {
  if (frames.isEmpty) {
    throw ArgumentError('need at least one frame');
  }
  final place = placeHash(district, geoCell);
  var h = Uint8List(32);
  final hashes = <String>[];
  for (final f in frames) {
    final fh = sha256Bytes(f.bytes);
    hashes.add(hexOf(fh));
    final cat = Uint8List(104);
    cat.setAll(0, h);
    cat.setAll(32, fh);
    cat.setAll(64, u64be(f.timestampMs));
    cat.setAll(72, place);
    h = sha256Bytes(cat);
  }
  return CaptureChain(
    root: hexOf(h),
    frameCount: frames.length,
    fps: fps,
    startMs: frames.first.timestampMs,
    endMs: frames.last.timestampMs,
    frameHashes: hashes,
    district: district,
    geoCell: geoCell,
  );
}
