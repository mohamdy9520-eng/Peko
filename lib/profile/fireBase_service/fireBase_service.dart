import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../user_model/user_model.dart';

// Custom Exceptions
class AuthException implements Exception {
  final String message;
  final String? code;
  AuthException(this.message, {this.code});
  @override
  String toString() => 'AuthException: $message (code: $code)';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => 'ValidationException: $message';
}

class FirebaseService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  // ✅ مستخدمين دلوقتي
  UserModel? _cachedUser;
  DateTime? _lastUserFetch;
  static const _cacheDuration = Duration(minutes: 2);

  FirebaseService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  String? get uid => _auth.currentUser?.uid;
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signOut() async {
    try {
      // ✅ امسح الـ cache لما تعمل sign out
      _cachedUser = null;
      _lastUserFetch = null;
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code), code: e.code);
    } catch (e) {
      throw AuthException('Failed to sign out: $e');
    }
  }

  Stream<UserModel> getUser() {
    final userId = uid;
    if (userId == null) {
      return Stream.error(AuthException('User not authenticated'));
    }

    // ✅ استخدم الـ cache لو لسه صالح (أقل من 2 دقيقة)
    final now = DateTime.now();
    if (_cachedUser != null &&
        _lastUserFetch != null &&
        now.difference(_lastUserFetch!) < _cacheDuration) {
      debugPrint('Returning cached user');
      return Stream.value(_cachedUser!);
    }

    return _firestore.collection('users').doc(userId).snapshots().handleError((error) {
      debugPrint('Firestore user stream error: $error');
      if (error is FirebaseException) {
        throw NetworkException('Failed to load user data: ${error.message}');
      }
      throw error;
    }).map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw AuthException('User profile not found');
      }
      final user = UserModel.fromMap(doc.data()!, documentId: doc.id);

      // ✅ حدّث الـ cache
      _cachedUser = user;
      _lastUserFetch = DateTime.now();

      return user;
    });
  }

  Future<void> updateUser(UserModel user) async {
    final userId = uid;
    if (userId == null) throw AuthException('User not authenticated');
    if (user.name.trim().isEmpty) throw ValidationException('Name cannot be empty');
    if (user.email.trim().isEmpty || !user.email.contains('@')) {
      throw ValidationException('Valid email is required');
    }

    try {
      final data = {
        'name': user.name.trim(),
        'email': user.email.trim(),
        'username': user.username.trim(),
        'phone': user.phone.trim(),
        'image': user.image ?? '',
        'bio': user.bio?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      data.removeWhere((key, value) => value == null);

      await _firestore.collection('users').doc(userId).set(data, SetOptions(merge: true));

      // ✅ حدّث الـ cache بعد الـ update
      _cachedUser = user;
      _lastUserFetch = DateTime.now();

    } on FirebaseException catch (e) {
      throw NetworkException('Failed to update profile: ${e.message}');
    }
  }

  Future<void> updateUserImage(String imageUrl) async {
    await updateUserFields({'image': imageUrl});
  }

  Future<void> updateUserFields(Map<String, dynamic> fields) async {
    final userId = uid;
    if (userId == null) throw AuthException('User not authenticated');
    try {
      fields['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(userId).update(fields);

      // ✅ امسح الـ cache عشان يتجيب تاني من Firestore
      _cachedUser = null;
      _lastUserFetch = null;

    } on FirebaseException catch (e) {
      throw NetworkException('Failed to update fields: ${e.message}');
    }
  }

  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final picked = await _picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1200, maxHeight: 1200,
      );
      if (picked == null) return null;
      final file = File(picked.path);
      final size = await file.length();
      const maxSize = 5 * 1024 * 1024;
      if (size > maxSize) throw ValidationException('Image must be less than 5MB');
      return file;
    } on ValidationException { rethrow; }
    catch (e) { throw NetworkException('Failed to pick image: $e'); }
  }

  Future<String> uploadImage(File file) async {
    final userId = uid;
    if (userId == null) throw Exception("User not logged in");

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('users/$userId/profile_$timestamp.jpg');

    try {
      final uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      await uploadTask;
      final url = await ref.getDownloadURL();

      await _deleteOldProfileImage(userId, timestamp);

      return url;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<void> _deleteOldProfileImage(String userId, int currentTimestamp) async {
    try {
      final listResult = await _storage.ref().child('users/$userId').listAll();
      for (final item in listResult.items) {
        if (item.name.startsWith('profile_') && !item.name.contains('$currentTimestamp')) {
          await item.delete();
        }
      }
    } catch (e) {
      debugPrint('No old images to delete or folder empty: $e');
    }
  }

  Stream<QuerySnapshot> getFriends() {
    final userId = uid;
    if (userId == null) return const Stream.empty();
    return _firestore.collection('users').doc(userId).collection('friends')
        .orderBy('addedAt', descending: true).snapshots();
  }

  Future<void> addFriend(Map<String, dynamic> friendData) async {
    final userId = uid;
    if (userId == null) throw AuthException('User not authenticated');
    final name = friendData['name']?.toString().trim() ?? '';
    final email = friendData['email']?.toString().trim() ?? '';
    if (name.isEmpty) throw ValidationException('Friend name is required');
    if (email.isNotEmpty && !email.contains('@')) throw ValidationException('Invalid email format');

    final existing = await _firestore.collection('users').doc(userId)
        .collection('friends').where('email', isEqualTo: email).limit(1).get();
    if (existing.docs.isNotEmpty) throw ValidationException('This friend is already in your list');

    friendData['addedAt'] = FieldValue.serverTimestamp();
    friendData['name'] = name;
    friendData['email'] = email;
    await _firestore.collection('users').doc(userId).collection('friends').add(friendData);
  }

  Future<void> removeFriend(String friendId) async {
    final userId = uid;
    if (userId == null) return;
    await _firestore.collection('users').doc(userId).collection('friends').doc(friendId).delete();
  }

  Stream<QuerySnapshot> getMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }


  Stream<int> getFriendsCount() {
    final userId = uid;
    if (userId == null) return Stream.value(0);
    return _firestore
        .collection('users').doc(userId).collection('friends')
        .where('friendRegistered', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> getMessagesCount() {
    final userId = uid;
    if (userId == null) return Stream.value(0);
    return _firestore
        .collection('users').doc(userId).collection('notifications')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> getRewardsCount() {
    final userId = uid;
    if (userId == null) return Stream.value(0);
    return _firestore
        .collection('users').doc(userId).collection('friends')
        .where('rewarded', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<bool> redeemInviteCode(String inviteCode) async {
    final newUserId = uid;
    if (newUserId == null) throw AuthException('User not authenticated');
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return false;

    final query = await _firestore
        .collectionGroup('friends')
        .where('inviteCode', isEqualTo: code)
        .where('friendRegistered', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    final friendDoc = query.docs.first;
    final inviterId = friendDoc.reference.parent.parent?.id;
    if (inviterId == null) return false;

    final batch = _firestore.batch();

    batch.update(friendDoc.reference, {
      'friendRegistered': true,
      'rewarded': true,
      'registeredUid': newUserId,
      'registeredAt': FieldValue.serverTimestamp(),
    });

    final notifRef = _firestore
        .collection('users').doc(inviterId)
        .collection('notifications').doc();
    batch.set(notifRef, {
      'title': 'صديق جديد انضم! 🎉',
      'body': 'صديقك سجّل في التطبيق بكود الدعوة بتاعك، ومبروك عليك المكافأة!',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return true;
  }

  Future<void> markMessageAsRead(String messageId) async {
    final userId = uid;
    if (userId == null) return;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(messageId);

      final doc = await docRef.get();
      if (!doc.exists) {
        debugPrint('Notification $messageId not found, skipping mark as read');
        return;
      }

      await docRef.update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('Failed to mark notification as read: ${e.message}');
    }
  }


  Future<void> markAllMessagesAsRead() async {
    final userId = uid;
    if (userId == null) return;

    try {
      final batch = _firestore.batch();

      final unreadQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadQuery.docs.isEmpty) return;

      for (final doc in unreadQuery.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('Marked ${unreadQuery.docs.length} notifications as read');
    } on FirebaseException catch (e) {
      debugPrint('Failed to mark all as read: ${e.message}');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final userId = uid;
    if (userId == null) return;

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(messageId);

      final doc = await docRef.get();
      if (!doc.exists) {
        debugPrint('Notification $messageId not found, skipping delete');
        return;
      }

      await docRef.delete();
    } on FirebaseException catch (e) {
      debugPrint('Failed to delete notification: ${e.message}');
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw AuthException('User not available');
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code), code: e.code);
    }
  }

  Future<void> changeEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not authenticated');
    try { await user.verifyBeforeUpdateEmail(newEmail); }
    on FirebaseAuthException catch (e) { throw AuthException(_getAuthErrorMessage(e.code), code: e.code); }
  }

  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not authenticated');
    if (newPassword.length < 8) throw ValidationException('Password must be at least 8 characters');
    if (!newPassword.contains(RegExp(r'[A-Z]'))) throw ValidationException('Password must contain uppercase');
    if (!newPassword.contains(RegExp(r'[0-9]'))) throw ValidationException('Password must contain a number');
    try { await user.updatePassword(newPassword); }
    on FirebaseAuthException catch (e) { throw AuthException(_getAuthErrorMessage(e.code), code: e.code); }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'No user found with this email';
      case 'wrong-password': return 'Incorrect password';
      case 'email-already-in-use': return 'This email is already in use';
      case 'invalid-email': return 'Invalid email address';
      case 'weak-password': return 'Password is too weak';
      case 'requires-recent-login': return 'Please log in again to perform this action';
      case 'network-request-failed': return 'Network error. Check your connection';
      default: return 'Authentication error: $code';
    }
  }
}