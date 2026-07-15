const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.redeemInviteCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }

  const newUserId = context.auth.uid;
  const inviteCode = data.inviteCode?.toString().trim().toUpperCase();

  if (!inviteCode || inviteCode.length < 4) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid code');
  }

  const friendsSnapshot = await admin.firestore()
    .collectionGroup('friends')
    .where('inviteCode', '==', inviteCode)
    .where('friendRegistered', '==', false)
    .limit(1)
    .get();

  if (friendsSnapshot.empty) {
    throw new functions.https.HttpsError('not-found', 'Invalid or used code');
  }

  const friendDoc = friendsSnapshot.docs[0];
  const inviterId = friendDoc.ref.parent.parent.id;

  if (inviterId === newUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot invite yourself');
  }

  await admin.firestore().runTransaction(async (transaction) => {
    const freshDoc = await transaction.get(friendDoc.ref);

    if (!freshDoc.exists || freshDoc.data().friendRegistered === true) {
      throw new functions.https.HttpsError('already-exists', 'Code used');
    }

    transaction.update(friendDoc.ref, {
      friendRegistered: true,
      friendUserId: newUserId,
      friendName: data.userName || 'Friend',
      redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const reverseFriendRef = admin.firestore()
      .doc(`users/${newUserId}/friends/${inviterId}`);

    const inviterProfile = await admin.firestore()
      .doc(`users/${inviterId}`).get();

    transaction.set(reverseFriendRef, {
      name: inviterProfile.data()?.name || 'Friend',
      userId: inviterId,
      addedByInvite: true,
      inviteCode: inviteCode,
      addedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const notificationRef = admin.firestore()
      .collection('users')
      .doc(inviterId)
      .collection('notifications')
      .doc();

    transaction.set(notificationRef, {
      title: '🎉 Friend Joined!',
      body: `${data.userName || 'Someone'} joined using your invite code!`,
      type: 'friend_joined',
      read: false,
      data: { friendUserId: newUserId, screen: '/friends' },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true, message: 'Redeemed!', inviterId };
});