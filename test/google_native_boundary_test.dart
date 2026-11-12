import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// The platform interface is installed transitively by google_sign_in.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class FakeGooglePlatform extends GoogleSignInPlatform {
  int initializations = 0;
  int authentications = 0;
  int signouts = 0;
  bool failInitialization = true;
  String? idToken = 'google-id-token';

  @override
  Future<void> init(InitParameters params) async {
    initializations++;
    if (failInitialization) throw StateError('initialization failed');
  }

  @override
  Future<AuthenticationResults> authenticate(
      AuthenticateParameters params) async {
    authentications++;
    return AuthenticationResults(
      user: const GoogleSignInUserData(email: 'user@example.test', id: 'id'),
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );
  }

  @override
  Future<void> signOut(SignOutParams params) async => signouts++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'native initialization retries, authenticates and passes Google ID token',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final oldPlatform = GoogleSignInPlatform.instance;
    final fake = FakeGooglePlatform();
    GoogleSignInPlatform.instance = fake;
    addTearDown(() => GoogleSignInPlatform.instance = oldPlatform);

    await expectLater(googleFirebaseToken(() => true), throwsStateError);
    expect(fake.authentications, 0);
    fake.failInitialization = false;
    String? observedGoogleToken;
    Future<String?> exchange(String token) async {
      observedGoogleToken = token;
      return 'firebase-id-token';
    }

    expect(
        await googleFirebaseToken(() => true, firebaseTokenForGoogle: exchange),
        'firebase-id-token');
    expect(observedGoogleToken, 'google-id-token');
    expect(fake.initializations, 2);
    expect(fake.authentications, 1);
    expect(fake.signouts, 1);

    fake.idToken = null;
    await expectLater(
        googleFirebaseToken(() => true, firebaseTokenForGoogle: exchange),
        throwsA(isA<ApiException>()));
    expect(fake.initializations, 2);
    expect(fake.signouts, 2);
  });
}
