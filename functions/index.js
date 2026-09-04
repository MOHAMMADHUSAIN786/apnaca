const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteUser = onCall(async (request) => {

  // Authentication check
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Login required."
    );
  }

  const callerEmail =
      (request.auth.token.email || "").toLowerCase();

  // Admin check
  if (callerEmail !== "admin@gmail.com") {
    throw new HttpsError(
      "permission-denied",
      "Only admin can delete users."
    );
  }

  const uid = request.data.uid;

  if (!uid) {
    throw new HttpsError(
      "invalid-argument",
      "uid is required."
    );
  }

  // Prevent self delete
  if (uid === request.auth.uid) {
    throw new HttpsError(
      "invalid-argument",
      "Admin cannot delete themselves."
    );
  }

  try {

    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    // ==========================================
    // Delete Firebase Auth User
    // ==========================================

    try {
      await admin.auth().deleteUser(uid);
      console.log(`Auth user deleted: ${uid}`);
    } catch (e) {
      console.log(`Auth delete skipped: ${e.message}`);
    }

    // ==========================================
    // Delete Firestore Main Docs
    // ==========================================

    await db.collection("users")
        .doc(uid)
        .delete()
        .catch(() => {});

    await db.collection("subscriptions")
        .doc(uid)
        .delete()
        .catch(() => {});

    // ==========================================
    // Delete contact_queries
    // ==========================================

    const contactSnap = await db
        .collection("contact_queries")
        .where("uid", "==", uid)
        .get();

    const cleanupBatch = db.batch();

 contactSnap.docs.forEach((doc) => {
   cleanupBatch.delete(doc.ref);
 });

    // ==========================================
    // Delete feedbacks
    // ==========================================

    const feedbackSnap = await db
        .collection("feedbacks")
        .where("uid", "==", uid)
        .get();

  feedbackSnap.docs.forEach((doc) => {
    cleanupBatch.delete(doc.ref);
  });

    // ==========================================
    // Delete ai_queries
    // ==========================================

    const aiQuerySnap = await db
        .collection("ai_queries")
        .where("uid", "==", uid)
        .get();

    aiQuerySnap.docs.forEach((doc) => {
      cleanupBatch.delete(doc.ref);
    });

    if (
      !contactSnap.empty ||
      !feedbackSnap.empty ||
      !aiQuerySnap.empty
    ) {
      await cleanupBatch.commit();
    }

    // ==========================================
    // Delete Storage Files
    // ==========================================

    const filesToDelete = [

      `profile_pictures/${uid}.jpg`,
      `profile_pictures/${uid}.jpeg`,
      `profile_pictures/${uid}.png`,
      `profile_pictures/${uid}.webp`,

      `database_backups/user_${uid}.db`,
    ];

    for (const filePath of filesToDelete) {

      try {

        await bucket.file(filePath).delete();

        console.log(`Deleted file: ${filePath}`);

      } catch (e) {

        console.log(`Skip file: ${filePath}`);
      }
    }

    return {
      success: true,
      message: "User deleted successfully"
    };

  } catch (e) {

    console.error("Delete User Error:", e);

    throw new HttpsError(
      "internal",
      e.message || "Unknown error"
    );
  }
});