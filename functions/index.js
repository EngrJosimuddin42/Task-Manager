// 🔥 index.js (Fully Lint-Ready & Deploy-Ready)
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// ✅ Nodemailer setup (Gmail App Password দরকার)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "your_email@gmail.com", // 👉 তোমার Gmail
    pass: "your_app_password", // 👉 Gmail App Password
  },
});

// ✅ OTP expiration time in minutes
const OTP_EXPIRATION_MINUTES = 5;

/**
 * Generate a random 6-digit OTP
 * @return {string}
 */
function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Check if OTP expired
 * @param {admin.firestore.Timestamp} timestamp
 * @return {boolean}
 */
function isOtpExpired(timestamp) {
  if (!timestamp) return true;
  const now = new Date();
  const diffInMinutes = (now - timestamp.toDate()) / 60000;
  return diffInMinutes > OTP_EXPIRATION_MINUTES;
}

/**
 * Cloud Function: Send OTP to Email
 */
exports.sendOtp = functions.https.onCall(async (data, context) => {
  const email = data.email;

  if (!email) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email is required",
    );
  }

  const otp = generateOtp();

  try {
    // ✅ Save OTP in Firestore
    await admin.firestore().collection("emailOtps").doc(email).set({
      otp,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ✅ Send OTP via Email
    await transporter.sendMail({
      from: `"Task Manager App" <your_email@gmail.com>`,
      to: email,
      subject: "Your OTP Code (Task Manager)",
      html: `
        <div style="font-family:sans-serif; padding:20px; border-radius:10px;
          border:1px solid #ddd;">
          <h2>🔐 Email Verification</h2>
          <p>Hello 👋,</p>
          <p>Your OTP code is:</p>
          <h1 style="color:#4B6BFB;">${otp}</h1>
          <p>
            This OTP will expire in ${OTP_EXPIRATION_MINUTES} minutes.
          </p>
          <p>If you didn’t request this, please ignore this email.</p>
          <br/>
          <p>— Task Manager App</p>
        </div>
      `,
    });

    console.log(`✅ OTP sent successfully to ${email}`);
    return {message: "OTP sent successfully!"};
  } catch (error) {
    console.error("❌ Error sending OTP:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to send OTP",
    );
  }
});

/**
 * Cloud Function: Verify OTP
 */
exports.verifyOtp = functions.https.onCall(async (data, context) => {
  const {email, otp} = data;

  if (!email || !otp) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email and OTP required",
    );
  }

  try {
    const doc = await admin
        .firestore()
        .collection("emailOtps")
        .doc(email)
        .get();

    if (!doc.exists) {
      throw new functions.https.HttpsError(
          "not-found",
          "No OTP found for this email",
      );
    }

    const {otp: savedOtp, createdAt} = doc.data();

    if (isOtpExpired(createdAt)) {
      throw new functions.https.HttpsError(
          "deadline-exceeded",
          "OTP expired, please request again",
      );
    }

    if (otp !== savedOtp) {
      throw new functions.https.HttpsError(
          "permission-denied",
          "Invalid OTP",
      );
    }

    // ✅ OTP matched → delete OTP record
    await admin.firestore().collection("emailOtps").doc(email).delete();

    console.log(`✅ OTP verified for ${email}`);
    return {
      verified: true,
      message: "OTP verified successfully!",
    };
  } catch (error) {
    console.error("❌ Error verifying OTP:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});
