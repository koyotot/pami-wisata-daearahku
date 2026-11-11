class AppConfig {
  AppConfig._();

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// The DEMO payment simulator is off unless a build opts in with
  /// `--dart-define=DEMO_PAYMENT_ENABLED=true`. It never replaces real payment methods.
  static const bool _demoPaymentRequested = bool.fromEnvironment(
    'DEMO_PAYMENT_ENABLED',
    defaultValue: false,
  );
  static bool get demoPaymentEnabled => _demoPaymentRequested && !isProduction;

  static bool get isDevelopment => appEnv == 'development' || appEnv == 'local';

  static bool get isProduction => appEnv == 'production';

  static void validate() {
    if (!{'local', 'development', 'production'}.contains(appEnv)) {
      throw StateError('APP_ENV tidak valid atau belum diatur.');
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError('API_BASE_URL tidak valid atau belum diatur.');
    }

    if (isProduction &&
        (uri.scheme != 'https' ||
            uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '[::1]' ||
            uri.host == 'your-production-api-domain')) {
      throw StateError(
          'API_BASE_URL production harus HTTPS dan bukan localhost/placeholder.');
    }
  }
}
