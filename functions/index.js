const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteUnverifiedUsers = onSchedule("every 1 minutes", async () => {

  const now = Date.now();

  // 30 seconds for testing
  const cutoff = now - (30 * 1000);

  const snapshot = await admin.firestore()
    .collection("users")
    .get();

  const tasks = [];

  snapshot.forEach((doc) => {

    const data = doc.data();

    if (!data.createdAt) return;

    const createdAt = data.createdAt.toDate().getTime();

    if (createdAt < cutoff && data.emailVerified === false) {

      const uid = data.uid;

      console.log("Deleting unverified user:", uid);

      tasks.push(admin.auth().deleteUser(uid));
      tasks.push(doc.ref.delete());
    }
  });

  await Promise.all(tasks);

  console.log("Cleanup complete");
});