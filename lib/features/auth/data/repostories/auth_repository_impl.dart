import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repostories/auth_repostory.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl(this._auth, this._firestore);

  @override
  Future<void> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;

    final userDoc = _firestore
        .collection('users')
        .doc(user.uid);

    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'username': '',
        'totalBalance': 0.0,
        'totalIncome': 0.0,
        'totalExpense': 0.0,
        'createdAt': Timestamp.now(),
        'imageUrl': '',
      });
    }
  }

  @override
  Future<void> signUpWithUsername({
    required String name,
    required String email,
    required String password,
    required String username,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user!;

    final usernameRef =
    _firestore.collection('usernames').doc(username);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(usernameRef);

      if (snapshot.exists) {
        throw Exception('Username already taken');
      }

      transaction.set(usernameRef, {
        'uid': user.uid,
      });

      transaction.set(
        _firestore.collection('users').doc(user.uid),
        {
          'name': name,
          'email': email,
          'username': username,
          'totalBalance': 0.0,
          'totalIncome': 0.0,
          'totalExpense': 0.0,
          'createdAt': Timestamp.now(),
          'imageUrl': '',
        },
      );
    });

    await user.sendEmailVerification();
  }

  @override
  Future<void> signInWithGoogle() async {
    // TODO: Implement Google Sign In
  }

  @override
  Future<void> signInWithFacebook() async {
    // TODO: Implement Facebook Sign In
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }
}