import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/core/config/app_config.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

void main() {
  test('compile-time environment is validated and used by AuthSession', () {
    const valid = bool.fromEnvironment('CONFIG_TEST_VALID');
    if (const bool.hasEnvironment('CONFIG_TEST_VALID')) {
      expect(AppConfig.validate, valid ? returnsNormally : throwsStateError);
    } else if (AppConfig.appEnv.isEmpty) {
      expect(AppConfig.validate, throwsStateError);
    }
    expect(AuthSession().baseUrl, AppConfig.apiBaseUrl);
  });
}
