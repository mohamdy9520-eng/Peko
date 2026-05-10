import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../user_model/user_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get uid => _auth.currentUser?.uid;

  // 📥 get user
  Stream<UserModel> getUser() {
    final userId = uid;

    if (userId == null) {
      throw Exception("User not logged in");
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (data == null) {
        throw Exception("User data not found");
      }
      return UserModel.fromMap(data);
    });
  }

  // 💾 update user
  Future<void> updateUser(UserModel user) async {
    final userId = uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update(user.toMap());
  }

  // 🖼️ upload image
  Future<String> uploadImage(File file) async {
    final userId = uid;
    if (userId == null) throw Exception("User not logged in");

    final ref = _storage.ref().child('users/$userId/profile.jpg');

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }

  final ImagePicker picker = ImagePicker();

  Future<File?> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    return File(picked.path);
  }

  // 👥 get friends
  Stream<QuerySnapshot> getFriends() {
    final userId = uid;
    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots();
  }

  // ➕ add friend
  Future<void> addFriend(Map<String, dynamic> friendData) async {
    final userId = uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .add(friendData);
  }

  // 🖼️ update profile image
  Future<void> updateUserImage(String imageUrl) async {
    final userId = uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update({
      "image": imageUrl,
    });
  }
}