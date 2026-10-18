class Config {
  static const appName = 'Swatantra';
  static const tagline = 'Ground truth, unerasable.';
  static const appAttr = 'swatantra';
  static const faucet = 'https://hub.arkiv.network/faucet';
  static const pagesBase = 'https://tusharojha.github.io/swatantra';
  static const repo = 'https://github.com/tusharojha/swatantra';
  /// Reown / WalletConnect Cloud project id. Empty → skip WC, keep burner + injected.
  static const walletConnectProjectId =
      String.fromEnvironment('WALLETCONNECT_PROJECT_ID', defaultValue: '');

  /// Compile-time default. Override with `--dart-define=ARKIV_NETWORK=local`
  /// or (web) `?network=local`. Production / CI stay on Tiramisu.
  static String network = const String.fromEnvironment('ARKIV_NETWORK', defaultValue: 'tiramisu');

  static bool get isLocal => network == 'local' || network == 'localhost';

  static String get rpc => isLocal
      ? 'http://127.0.0.1:8545'
      : 'https://rpc.tiramisu.db-chain.testnet.arkiv.network';
  static String get ws => isLocal
      ? 'ws://127.0.0.1:8546'
      : 'wss://rpc.tiramisu.db-chain.testnet.arkiv.network';
  static String get explorer => isLocal ? 'http://127.0.0.1:8545' : 'https://tiramisu.explorer.arkiv.network';
  static int get chainId => isLocal ? 1337 : 7738577;
  static String get nativeToken => isLocal ? 'ETH' : 'GLM';

  static void applyLaunch() {
    try {
      final q = Uri.base.queryParameters['network'];
      if (q == 'local' || q == 'localhost' || q == 'dev') {
        network = 'local';
      }
    } catch (_) {}
  }
}
