import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import '../user_model/user_model.dart';

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
      _cachedUser = null;
      _lastUserFetch = null;
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code), code: e.code);
    } catch (e) {
      throw AuthException('Failed to sign out: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DELETE ACCOUNT (NEW)
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not authenticated');
    final userId = user.uid;

    try {
      // Delete user data from Firestore
      final batch = _firestore.batch();

      // Delete user profile
      final userRef = _firestore.collection('users').doc(userId);
      batch.delete(userRef);

      // Delete contacts subcollection
      final contactsSnapshot = await _firestore
          .collection('users').doc(userId).collection('contacts').get();
      for (final doc in contactsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete notifications subcollection
      final notificationsSnapshot = await _firestore
          .collection('users').doc(userId).collection('notifications').get();
      for (final doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Delete user files from Storage
      try {
        final storageRef = _storage.ref().child('users/$userId');
        final listResult = await storageRef.listAll();
        for (final item in listResult.items) {
          await item.delete();
        }
      } catch (e) {
        debugPrint('Storage deletion warning: $e');
      }

      // Delete Firebase Auth account
      await user.delete();

      _cachedUser = null;
      _lastUserFetch = null;

    } on FirebaseAuthException catch (e) {
      throw AuthException(_getAuthErrorMessage(e.code), code: e.code);
    } on FirebaseException catch (e) {
      throw NetworkException('Failed to delete account: ${e.message}');
    } catch (e) {
      throw AuthException('Failed to delete account: $e');
    }
  }

  Stream<UserModel> getUser() {
    final userId = uid;
    if (userId == null) {
      return Stream.error(AuthException('User not authenticated'));
    }

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw AuthException('User profile not found');
      }

      final data = doc.data()!;

      final authUser = _auth.currentUser;
      final isEmailVerified = authUser?.emailVerified ?? false;

      final mergedData = {
        ...data,
        'isEmailVerified': isEmailVerified,
        'uid': userId,
      };

      final user = UserModel.fromMap(mergedData, documentId: doc.id);
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

      final taskSnapshot = await uploadTask.whenComplete(() => null);

      if (taskSnapshot.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        debugPrint('Upload successful: $url');
        return url;
      } else {
        throw Exception('Upload failed with state: ${taskSnapshot.state}');
      }
    } on FirebaseException catch (e) {
      throw Exception('Firebase upload failed: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GET FRIENDS (contacts)
  // ═══════════════════════════════════════════════════════════
  Stream<QuerySnapshot> getFriends() {
    final userId = uid;
    if (userId == null) return const Stream.empty();
    return _firestore
        .collection('users').doc(userId).collection('contacts')
        .orderBy('addedAt', descending: true).snapshots();
  }

  // ═══════════════════════════════════════════════════════════
  // ADD FRIEND (contacts)
  // ═══════════════════════════════════════════════════════════
  Future<void> addFriend(Map<String, dynamic> friendData) async {
    final userId = uid;
    if (userId == null) throw AuthException('User not authenticated');
    final name = friendData['name']?.toString().trim() ?? '';
    final email = friendData['email']?.toString().trim() ?? '';
    if (name.isEmpty) throw ValidationException('Friend name is required');
    if (email.isNotEmpty && !email.contains('@')) throw ValidationException('Invalid email format');

    final existing = await _firestore.collection('users').doc(userId)
        .collection('contacts').where('email', isEqualTo: email).limit(1).get();
    if (existing.docs.isNotEmpty) throw ValidationException('This friend is already in your list');

    friendData['addedAt'] = FieldValue.serverTimestamp();
    friendData['name'] = name;
    friendData['email'] = email;

    await _firestore.collection('users').doc(userId).collection('contacts').add(friendData);
  }

  // ═══════════════════════════════════════════════════════════
  // REMOVE FRIEND (contacts)
  // ═══════════════════════════════════════════════════════════
  Future<void> removeFriend(String friendId) async {
    final userId = uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).collection('contacts').doc(friendId).delete();
  }

  // ═══════════════════════════════════════════════════════════
  // GET FRIENDS COUNT (contacts)
  // ═══════════════════════════════════════════════════════════
  Stream<int> getFriendsCount() {
    final userId = uid;
    if (userId == null) return Stream.value(0);
    return _firestore
        .collection('users').doc(userId).collection('contacts')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ═══════════════════════════════════════════════════════════
  // GET REWARDS COUNT (contacts)
  // ═══════════════════════════════════════════════════════════
  Stream<int> getRewardsCount() {
    final userId = uid;
    if (userId == null) return Stream.value(0);
    return _firestore
        .collection('users').doc(userId).collection('contacts')
        .snapshots()
        .map((snap) => snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['rewarded'] == true;
    }).length);
  }

  // ═══════════════════════════════════════════════════════════
  // REDEEM INVITE CODE (contacts)
  // ═══════════════════════════════════════════════════════════
  Future<bool> redeemInviteCode(String inviteCode) async {
    final newUserId = uid;
    if (newUserId == null) throw AuthException('User not authenticated');

    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return false;

    final query = await _firestore
        .collectionGroup('contacts')
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
      'title': 'New Friend Joined! 🎉',
      'body': 'Your friend joined using your invite code. You earned a reward!',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return true;
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

  Stream<int> getMessagesCount() {
    final userId = uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('users').doc(userId).collection('notifications')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> getUnreadMessagesCount() {
    final userId = uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('users').doc(userId).collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
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
