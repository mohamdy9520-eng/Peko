import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final usernameRef = _firestore.collection('usernames').doc(username);

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
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });

    await user.updateDisplayName(name);
  }

}