import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'arkiv/js.dart';
import 'arkiv/rpc.dart';

class WalletStore {
  static const _k = 'swatantra.burner.pk';
  static const _addrK = 'swatantra.wallet.addr';
  static const _srcK = 'swatantra.wallet.src';
  static const _journalistK = 'swatantra.journalist.key';
  static const _aaNullifierK = 'swatantra.aa.nullifier';
  static const _aaGroth16K = 'swatantra.aa.groth16';
  static SharedPreferences? _prefs;
  static String? privateKey;
  static String? address;
  static String? journalistKey;
  static String? aaNullifier;
  static bool aaGroth16 = false;
  static bool injected = false;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    privateKey = _prefs!.getString(_k);
    journalistKey = _prefs!.getString(_journalistK);
    aaNullifier = _prefs!.getString(_aaNullifierK);
    aaGroth16 = _prefs!.getBool(_aaGroth16K) ?? false;
    injected = _prefs!.getString(_srcK) == 'injected';
    if (privateKey != null) {
      await unlock(privateKey!);
    } else if (injected) {
      address = _prefs!.getString(_addrK);
    }
    await FollowStore.load();
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
    injected = false;
    if (arkivJsAvailable) {
      try {
        final r = await arkivJs('createBurner');
        privateKey = r['privateKey'] as String?;
        address = r['address'] as String?;
        if (privateKey != null) {
          await _prefs?.setString(_k, privateKey!);
        }
        if (address != null) await _prefs?.setString(_addrK, address!);
        await _prefs?.setString(_srcK, 'burner');
        return;
      } catch (_) {}
    }
    final key = EthPrivateKey.createRandom(Random.secure());
    privateKey = bytesToHex(key.privateKey, include0x: true);
    address = key.address.hexEip55;
    await _prefs?.setString(_k, privateKey!);
    await _prefs?.setString(_addrK, address!);
    await _prefs?.setString(_srcK, 'burner');
  }

  static Future<void> connectInjected() async {
    if (!arkivJsAvailable) {
      throw Exception('NO_INJECTED: injected wallets are on web (MetaMask extension). Create wallet on this phone.');
    }
    final r = await arkivJs('connectInjected');
    address = r['address'] as String?;
    if (address == null || address!.isEmpty) {
      throw Exception('NO_INJECTED');
    }
    injected = true;
    privateKey = null;
    await _prefs?.remove(_k);
    await _prefs?.setString(_addrK, address!);
    await _prefs?.setString(_srcK, 'injected');
  }

  static Future<void> connectWalletConnect(String projectId) async {
    if (!arkivJsAvailable) {
      throw Exception('WalletConnect is available on web.');
    }
    final r = await arkivJs('connectWalletConnect', {'projectId': projectId});
    address = r['address'] as String?;
    if (address == null || address!.isEmpty) {
      throw Exception('WalletConnect returned no account');
    }
    injected = true;
    privateKey = null;
    await _prefs?.remove(_k);
    await _prefs?.setString(_addrK, address!);
    await _prefs?.setString(_srcK, 'walletconnect');
  }

  static Future<void> importKey(String pk) async {
    injected = false;
    await unlock(pk);
    if (address != null) await _prefs?.setString(_addrK, address!);
    await _prefs?.setString(_srcK, 'burner');
  }

  static Future<void> saveJournalist(String key) async {
    journalistKey = key;
    await _prefs?.setString(_journalistK, key);
  }

  static Future<void> saveAnonProof({required String nullifier, required bool groth16}) async {
    aaNullifier = nullifier;
    aaGroth16 = groth16;
    await _prefs?.setString(_aaNullifierK, nullifier);
    await _prefs?.setBool(_aaGroth16K, groth16);
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
    injected = false;
    await _prefs?.remove(_k);
    await _prefs?.remove(_addrK);
    await _prefs?.remove(_srcK);
    await _prefs?.remove(_journalistK);
  }
}

/// Local-only follows. Never written to Arkiv.
class FollowStore {
  static const _k = 'swatantra.follows';
  static final ids = <String>{};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    ids
      ..clear()
      ..addAll((p.getStringList(_k) ?? []).map((e) => e.toLowerCase()));
  }

  static bool of(String creator) => ids.contains(creator.toLowerCase());

  static Future<bool> toggle(String creator) async {
    final id = creator.toLowerCase();
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_k, ids.toList());
    return ids.contains(id);
  }
}
