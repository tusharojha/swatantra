import 'package:flutter/material.dart';
import 'wallet.dart';
import 'widgets/sheets.dart';

/// Gate a write. Browsing never calls this. Returns true if a wallet exists
/// after the sheet (existing session, or the user just signed in).
Future<bool> ensureSignedIn(
  BuildContext context, {
  required String action,
}) async {
  if (WalletStore.address != null) return true;
  if (!context.mounted) return false;
  final ok = await showAppSheet<bool>(context, SignInSheet(action: action));
  return ok == true && WalletStore.address != null;
}
