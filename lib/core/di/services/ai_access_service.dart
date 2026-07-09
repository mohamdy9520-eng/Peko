import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'revenuecat_service.dart';

enum AiTier { premium, free, blocked }

enum AiBlockReason { none, freeLimitReached, notAuthenticated }

class AiAccessResult {
  final AiTier tier;
  final int remainingFreeUses;
  final AiBlockReason reason;

  const AiAccessResult(
      this.tier,
      this.remainingFreeUses, {
        this.reason = AiBlockReason.none,
      });

  bool get isBlocked => tier == AiTier.blocked;
}

class AIAccessService {
  static const int freeTrialLimit = 3;

  static const int maxBonusUses = 5;

  static int _effectiveLimit(int bonusUses) =>
      freeTrialLimit + bonusUses.clamp(0, maxBonusUses);

  static Future<AiAccessResult> reserveUse() async {
    final isPremium = await RevenueCatService.isPremium();
    if (isPremium) return const AiAccessResult(AiTier.premium, 0);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AiAccessResult(
        AiTier.blocked,
        0,
        reason: AiBlockReason.notAuthenticated,
      );
    }

    final ref =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    return FirebaseFirestore.instance.runTransaction<AiAccessResult>((tx) async {
      final snap = await tx.get(ref);
      final used = (snap.data()?['aiFreeUsesUsed'] ?? 0) as int;
      final bonus = (snap.data()?['bonusAiUses'] ?? 0) as int;
      final limit = _effectiveLimit(bonus);

      if (used >= limit) {
        return const AiAccessResult(
          AiTier.blocked,
          0,
          reason: AiBlockReason.freeLimitReached,
        );
      }

      tx.set(ref, {
        'aiFreeUsesUsed': used + 1,
        'lastAiUseAt': Timestamp.now(),
      }, SetOptions(merge: true));

      return AiAccessResult(AiTier.free, limit - (used + 1));
    });
  }

  static Future<void> refundUse() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final used = (snap.data()?['aiFreeUsesUsed'] ?? 0) as int;
      if (used <= 0) return;
      tx.update(ref, {'aiFreeUsesUsed': used - 1});
    });
  }

  static Future<AiAccessResult> peekAccess() async {
    final isPremium = await RevenueCatService.isPremium();
    if (isPremium) return const AiAccessResult(AiTier.premium, 0);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AiAccessResult(
        AiTier.blocked,
        0,
        reason: AiBlockReason.notAuthenticated,
      );
    }

    final doc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final used = (doc.data()?['aiFreeUsesUsed'] ?? 0) as int;
    final bonus = (doc.data()?['bonusAiUses'] ?? 0) as int;
    final limit = _effectiveLimit(bonus);
    final remaining = (limit - used).clamp(0, limit);

    return AiAccessResult(
      remaining > 0 ? AiTier.free : AiTier.blocked,
      remaining,
      reason: remaining > 0 ? AiBlockReason.none : AiBlockReason.freeLimitReached,
    );
  }


  static Future<bool> grantInviteReward({required String userId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final ref =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final bonus = (snap.data()?['bonusAiUses'] ?? 0) as int;

      if (bonus >= maxBonusUses) return false;

      tx.set(ref, {
        'bonusAiUses': bonus + 1,
      }, SetOptions(merge: true));

      return true;
    });
  }
}
