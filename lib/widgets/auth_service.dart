import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  AuthService() {
    // Keep UI in sync with Firebase auth state
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  User? get user => _auth.currentUser;

  /// Optionally call this early in your app with your client IDs
  /// (clientId and serverClientId are optional depending on platform/config).
  Future<void> initializeGoogleSignIn({
    String? clientId,
    String? serverClientId,
  }) async {
    try {
      await _googleSignIn.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
      );

      // React to Google sign-in events and update UI state
      _googleSignIn.authenticationEvents.listen(
        (_) {
          notifyListeners();
        },
        onError: (_) {
          // ignore or log
        },
      );

      // Try a lightweight sign-in attempt (non-blocking)
      unawaited(_googleSignIn.attemptLightweightAuthentication());
    } catch (e) {
      // initialization errors can be surfaced or logged
      throw Exception('GoogleSignIn initialize failed: $e');
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? e.toString());
    }
  }

  Future<void> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseException catch (e) {
      throw Exception(e.message ?? e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;
      GoogleSignInAccount? googleUser;

      googleUser = await signIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        // accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception('Error signing in with Google: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    notifyListeners();
  }
}
