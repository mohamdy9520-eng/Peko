const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Generate 6-digit OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send OTP
exports.sendOTP = functions.https.onCall(async (data, context) => {
  const { email } = data;

  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email required');
  }

  const otp = generateOTP();
  const expiry = Date.now() + 10 * 60 * 1000; // 10 minutes

  // Save to Firestore
  await admin.firestore().collection('otps').doc(email).set({
    otp: otp,
    expiry: expiry,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Gmail Setup - غير ده بإيميلك
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: 'YOUR_EMAIL@gmail.com',        // ← غير ده
      pass: 'YOUR_APP_PASSWORD',           // ← غير ده (16 حرف)
    },
  });

  // Send Email
  await transporter.sendMail({
    from: 'AI Expense Tracker <YOUR_EMAIL@gmail.com>',
    to: email,
    subject: 'Your Password Reset Code',
    html: `
      <div style="font-family: Arial; text-align: center; padding: 40px;">
        <h2 style="color: #333;">Password Reset</h2>
        <p style="font-size: 16px; color: #666;">Your OTP code is:</p>
        <h1 style="color: #4CAF50; font-size: 48px; letter-spacing: 10px; margin: 20px 0;">${otp}</h1>
        <p style="font-size: 14px; color: #999;">Valid for 10 minutes</p>
      </div>
    `,
  });

  return { success: true };
});

// Verify OTP
exports.verifyOTP = functions.https.onCall(async (data, context) => {
  const { email, otp } = data;

  if (!email || !otp) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and OTP required');
  }

  const doc = await admin.firestore().collection('otps').doc(email).get();

  if (!doc.exists) {
    throw new functions.https.HttpsError('not-found', 'OTP not found or expired');
  }

  const otpData = doc.data();

  // Check expiry
  if (Date.now() > otpData.expiry) {
    await doc.ref.delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'OTP expired');
  }

  // Check OTP
  if (otpData.otp !== otp) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid OTP');
  }

  // Success - delete OTP
  await doc.ref.delete();

  return { verified: true };
});