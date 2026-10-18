import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'hash.dart';

/// Anon Aadhaar TEST MODE — same derivation as `bridge/src/anon.ts`.
/// nid = SHA-256("swatantra-aa-v1|" || testQR). Never a real Aadhaar.
const anonTestSeed = 'swatantra-aa-v1';
const bundledTestQr =
    '99999999999999999999999999999999999999999999999999999999999999999999'
    '000018MHTESTMODEONLYSYNTHETIC00000000000000000000000000000000000000';

String testNullifier(String? qrData) {
  final qr = (qrData ?? '').trim().isEmpty ? bundledTestQr : qrData!.trim();
  if (qr.length < 32) {
    throw ArgumentError('test QR too short — use Anon Aadhaar TEST QR or the bundled identity');
  }
  final material = utf8.encode('$anonTestSeed|$qr');
  return hexOf(sha256.convert(material).bytes);
}
