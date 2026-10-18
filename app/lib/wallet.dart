import 'package:shared_preferences/shared_preferences.dart';
import 'arkiv/js.dart';

class WalletStore {
  static const _k = 'swatantra.burner.pk';
  static SharedPreferences? _prefs;
  static String? privateKey;
  static String? address;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    privateKey = _prefs!.getString(_k);
    if (privateKey != null && arkivJsAvailable) {
      try {
        final r = await arkivJs('unlock', {'privateKey': privateKey});
        address = r['address'] as String?;
      } catch (_) {}
    }
  }

  static Future<void> generate() async {
    final r = await arkivJs('createBurner');
    privateKey = r['privateKey'] as String?;
    address = r['address'] as String?;
    if (privateKey != null) {
      await _prefs?.setString(_k, privateKey!);
    }
  }

  static Future<void> importKey(String pk) async {
    final r = await arkivJs('unlock', {'privateKey': pk});
    privateKey = pk.startsWith('0x') ? pk : '0x$pk';
    address = r['address'] as String?;
    await _prefs?.setString(_k, privateKey!);
  }

  static Future<void> clear() async {
    privateKey = null;
    address = null;
    await _prefs?.remove(_k);
  }
}
