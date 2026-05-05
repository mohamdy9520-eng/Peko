import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repostories/auth_repostory.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl(this._auth, this._firestore);

  @override
  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signUp(String name, String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // ✅ أنشئ الـ User Document فوراً مع القيم الابتدائية
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'name': name,
      'email': email,
      'totalBalance': 0.0,
      'totalIncome': 0.0,
      'totalExpense': 0.0,
      'createdAt': Timestamp.now(),
      'imageUrl': '',
    });

    // ✅ ابعت إيميل التحقق
    await userCredential.user?.sendEmailVerification();
  }

  @override
  Future<void> signInWithGoogle() async {
    // placeholder - نربطه لاحقًا مع Google SignIn
  }

  @override
  Future<void> signInWithFacebook() async {
    // placeholder
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }
}