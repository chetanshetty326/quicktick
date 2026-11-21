import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  final String idToken;
  final String? accessToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? uid;

  const GoogleAuthResult({
    required this.idToken,
    this.accessToken,
    this.email,
    this.displayName,
    this.photoUrl,
    this.uid,
  });
}

abstract class IGoogleAuthService {
  Future<GoogleAuthResult?> signIn();
  Future<void> signOut();
  bool get isSignedIn;
}

class GoogleAuthService implements IGoogleAuthService {
  final FirebaseAuth? _customFirebaseAuth;
  final GoogleSignIn _googleSignIn;

  GoogleAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _customFirebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
            );

  FirebaseAuth? get _firebaseAuth {
    if (_customFirebaseAuth != null) return _customFirebaseAuth;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  @override
  bool get isSignedIn {
    try {
      return _firebaseAuth?.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GoogleAuthResult?> signIn() async {
    try {
      // 1. Trigger the interactive Google Sign-In prompt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User dismissed the account selection dialog
        return null;
      }

      // 2. Obtain authentication credentials (idToken and accessToken)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Failed to obtain Google ID Token.');
      }

      // 3. Link with Firebase Auth if available
      User? firebaseUser;
      final auth = _firebaseAuth;
      if (auth != null) {
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: idToken,
        );
        final UserCredential userCredential = await auth.signInWithCredential(credential);
        firebaseUser = userCredential.user;
      }

      // 4. Return unified result
      return GoogleAuthResult(
        idToken: idToken,
        accessToken: googleAuth.accessToken,
        email: firebaseUser?.email ?? googleUser.email,
        displayName: firebaseUser?.displayName ?? googleUser.displayName,
        photoUrl: firebaseUser?.photoURL ?? googleUser.photoUrl,
        uid: firebaseUser?.uid,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [GoogleAuthService] Sign-in error: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      final futures = <Future<dynamic>>[_googleSignIn.signOut()];
      final auth = _firebaseAuth;
      if (auth != null) {
        futures.add(auth.signOut());
      }
      await Future.wait(futures);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [GoogleAuthService] Sign-out error: $e');
      }
    }
  }
}

