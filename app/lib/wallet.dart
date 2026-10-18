import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'arkiv/js.dart';
import 'arkiv/rpc.dart';

class WalletStore {
  static const _k = 'swatantra.burner.pk';
  static const _journalistK = 'swatantra.journalist.key';
  static SharedPreferences? _prefs;
  static String? privateKey;
  static String? address;
  static String? journalistKey;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    privateKey = _prefs!.getString(_k);
    journalistKey = _prefs!.getString(_journalistK);
    if (privateKey != null) {
      await unlock(privateKey!);
    }
  }

  static Future<Map<String, String>> unlock(String pk) async {
    final hex = pk.startsWith('0x') ? pk : '0x$pk';
    if (arkivJsAvailable) {
      try {
        final r = await arkivJs('unlock', {'privateKey': hex});
        privateKey = hex;
        address = r['address'] as String?;
        await _prefs?.setString(_k, hex);
        return {'address': address ?? ''};
      } catch (_) {}
    }
    final key = EthPrivateKey.fromHex(hex);
    privateKey = hex;
    address = key.address.hexEip55;
    await _prefs?.setString(_k, hex);
    return {'address': address!};
  }

  static Future<void> generate() async {
    if (arkivJsAvailable) {
      try {
        final r = await arkivJs('createBurner');
        privateKey = r['privateKey'] as String?;
        address = r['address'] as String?;
        if (privateKey != null) {
          await _prefs?.setString(_k, privateKey!);
        }
        return;
      } catch (_) {}
    }
    final key = EthPrivateKey.createRandom(Random.secure());
    privateKey = bytesToHex(key.privateKey, include0x: true);
    address = key.address.hexEip55;
    await _prefs?.setString(_k, privateKey!);
  }

  static Future<void> importKey(String pk) async {
    await unlock(pk);
  }

  static Future<void> saveJournalist(String key) async {
    journalistKey = key;
    await _prefs?.setString(_journalistK, key);
  }

  static Future<String> balanceWei() async {
    if (address == null) return '0';
    if (arkivJsAvailable) {
      try {
        final b = await arkivJs('getBalance');
        return '${b['wei'] ?? '0'}';
      } catch (_) {}
    }
    return ArkivRpc().getBalance(address!);
  }

  static Future<void> clear() async {
    privateKey = null;
    address = null;
    journalistKey = null;
    await _prefs?.remove(_k);
    await _prefs?.remove(_journalistK);
  }
}
