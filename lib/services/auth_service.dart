import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'photo_storage_service.dart';

class AuthService {
  // Lazy getters — FirebaseAuth.instance throws if Firebase failed to
  // initialize (e.g. unconfigured platform), so never touch it at
  // construction time.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmail(
      String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final name = displayName.trim();
    if (name.isNotEmpty) {
      await cred.user?.updateDisplayName(name);
    }
    await _createUserProfile(cred.user!, name);
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final identityToken = appleCredential.identityToken;
    if (identityToken == null) {
      throw FirebaseAuthException(
        code: 'apple-sign-in-failed',
        message: 'Apple did not return an identity token.',
      );
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
    );

    final userCred = await _auth.signInWithCredential(oauthCredential);

    final profile = await _db.collection('users').doc(userCred.user!.uid).get();
    if (!profile.exists) {
      final name = [appleCredential.givenName, appleCredential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      await _createUserProfile(
          userCred.user!, name.isNotEmpty ? name : 'Inspector');
    }
    return userCred;
  }

  Future<void> _createUserProfile(User user, String displayName) async {
    await _db.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    // Deleting a Firestore doc does NOT delete its subcollections —
    // remove every job doc explicitly so no data is orphaned.
    try {
      final jobs =
          await _db.collection('users').doc(uid).collection('jobs').get();
      final batch = _db.batch();
      for (final doc in jobs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
    await PhotoStorageService.deleteAllForUser(uid);
    await _db.collection('users').doc(uid).delete();
    await user.delete();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String authErrorMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found for that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'requires-recent-login':
          return 'Please sign out and sign in again, then retry.';
        case 'apple-sign-in-failed':
          return 'Sign in with Apple was cancelled or failed.';
        default:
          return e.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
