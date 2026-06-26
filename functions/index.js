const nodemailer = require("nodemailer");

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const functions = require("firebase-functions");

const { generateDeck } = require("./generate-deck");

exports.generateDeck = generateDeck;

admin.initializeApp();

// Single source of truth for the verification window length on the
// backend. MUST stay equal to _kWindowSecs (480) in
// lib/ui-layer/auth/register/verify_email_screen.dart — that constant
// drives the UI countdown, this one drives the actual deletion. If they
// ever drift apart, the UI will show one number while the backend
// enforces another, which is exactly the bug this comment is here to
// prevent happening again.
//
// History: this was hardcoded to 30 seconds for local testing back when
// the feature was first built, and that 30s value accidentally shipped
// and stayed live for months before being corrected to 8 minutes. If you
// ever need a short window again for testing, change VERIFICATION_WINDOW_MINUTES
// below — do NOT hand-edit the cutoff math, and do not forget to revert it.
const VERIFICATION_WINDOW_MINUTES = 8;
const VERIFICATION_WINDOW_MS = VERIFICATION_WINDOW_MINUTES * 60 * 1000;

exports.deleteUnverifiedUsers = onSchedule("every 1 minutes", async () => {

  const now = Date.now();
  const cutoff = now - VERIFICATION_WINDOW_MS;

  // Loud, unambiguous log line — check this in the Cloud Functions logs
  // any time the live behavior is in doubt. If this doesn't say 8, the
  // deployed function is NOT running the code in this repo.
  console.log(
    `[deleteUnverifiedUsers] window=${VERIFICATION_WINDOW_MINUTES}min ` +
    `cutoffISO=${new Date(cutoff).toISOString()} nowISO=${new Date(now).toISOString()}`
  );

  const snapshot = await admin.firestore()
    .collection("users")
    .get();

  const tasks = [];
  let checked = 0;
  let deleted = 0;

  snapshot.forEach((doc) => {

    const data = doc.data();

    if (!data.createdAt) return;
    if (data.emailVerified !== false) return;

    checked++;

    const createdAt = data.createdAt.toDate().getTime();
    const ageSeconds = Math.round((now - createdAt) / 1000);

    if (createdAt < cutoff) {

      const uid = data.uid;

      console.log(
        `[deleteUnverifiedUsers] Deleting unverified user: ${uid} ` +
        `(age=${ageSeconds}s, window=${VERIFICATION_WINDOW_MINUTES * 60}s)`
      );
      deleted++;

      tasks.push(admin.auth().deleteUser(uid));
      tasks.push(doc.ref.delete());
    }
  });

  await Promise.all(tasks);

  console.log(
    `[deleteUnverifiedUsers] Cleanup complete. ` +
    `unverifiedChecked=${checked} deleted=${deleted}`
  );
});

// ─── Study Reminder Email ────────────────────────────────────────────────────
// Runs every minute, checks each user's reminder settings, and sends an email
// when it matches the user's preferred hour (in their local timezone).

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

exports.sendStudyReminders = onSchedule({
  schedule: "every 1 minutes",
  secrets: ["GMAIL_USER", "GMAIL_APP_PASSWORD"],
}, async () => {
  const now = new Date();
  const currentUTCHour = now.getUTCHours();
  const currentUTCMinute = now.getUTCMinutes();

  const snapshot = await admin.firestore()
    .collection("users")
    .where("reminderEnabled", "==", true)
    .get();

  if (snapshot.empty) return;

  const tasks = [];

  snapshot.forEach((doc) => {
    const data = doc.data();

    const email = data.email;
    const displayName = data.displayName || "Learner";
    const educationLevel = data.educationLevel || "general";
    const reminderHourUTC = data.reminderHourUTC; // stored as UTC hour (0–23)
    const reminderMinuteUTC = data.reminderMinuteUTC ?? 0;
    const reminderEnabled = data.reminderEnabled;

    if (!email || !reminderEnabled || reminderHourUTC == null) return;
    if (reminderHourUTC !== currentUTCHour) return;
    if (reminderMinuteUTC !== currentUTCMinute) return;

    const subject = _getReminderSubject(educationLevel);
    const html = _getReminderHtml(displayName, educationLevel);

    tasks.push(
      transporter.sendMail({
        from: `"MnemoApp 🧠" <${process.env.GMAIL_USER}>`,
        to: email,
        subject,
        html,
      }).then(() => {
        console.log(`✅ Reminder sent to ${email}`);
      }).catch((err) => {
        console.error(`❌ Failed to send reminder to ${email}:`, err.message);
      })
    );
  });

  await Promise.all(tasks);
  console.log(`📬 Reminder run complete at UTC ${currentUTCHour}:00`);
});

function _getReminderSubject(educationLevel) {
  const subjects = {
    elementary: "🌟 Time to Practice! Your flashcards are waiting!",
    highschool: "📚 Study Time! Don't break your streak today!",
    college: "🎓 Daily Reminder: Keep your mastery score climbing!",
    professional: "💼 Knowledge is compounding — review your deck today.",
    general: "🧠 Your Daily Study Reminder is Here!",
  };
  return subjects[educationLevel] || subjects.general;
}

function _getReminderHtml(displayName, educationLevel) {
  const messages = {
    elementary: {
      headline: `Hey ${displayName}, ready to learn something cool? 🚀`,
      body: "Just a few flashcards a day keeps forgetting away! Open MnemoApp and let's go!",
      tip: "⭐ Tip: Even 5 minutes of review today makes a big difference!",
    },
    highschool: {
      headline: `What's up, ${displayName}! 📖`,
      body: "Exams don't study themselves. A quick review session today keeps your streak alive and your brain sharp.",
      tip: "🔥 Tip: Focus on your weak spots — they're the ones that show up on tests.",
    },
    college: {
      headline: `Good day, ${displayName}! 🎓`,
      body: "Spaced repetition is the most efficient study method proven by research. Your daily review session is the most valuable 10 minutes of your day.",
      tip: "💡 Tip: Review forgotten cards first — they need the most repetition to stick.",
    },
    professional: {
      headline: `Hello, ${displayName}.`,
      body: "Consistent daily review is how expertise is built. Your flashcard session today is an investment in long-term retention.",
      tip: "📈 Tip: Mastery compounds — even a 1% improvement each day adds up significantly over time.",
    },
    general: {
      headline: `Hi ${displayName}! 🧠`,
      body: "It's time for your daily study session! A few minutes of focused review keeps your knowledge fresh and your streak growing.",
      tip: "✨ Tip: Consistency beats intensity — showing up every day is what makes the difference.",
    },
  };

  const msg = messages[educationLevel] || messages.general;

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
</head>
<body style="margin:0;padding:0;background-color:#f4f4f5;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;padding:32px 0;">
    <tr>
      <td align="center">
        <table width="560" cellpadding="0" cellspacing="0"
          style="background:#ffffff;border-radius:16px;overflow:hidden;
                 box-shadow:0 4px 24px rgba(0,0,0,0.08);max-width:560px;width:100%;">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#6366f1,#8b5cf6);
                        padding:32px 40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:26px;font-weight:800;
                          letter-spacing:-0.5px;">🧠 MnemoApp</h1>
              <p style="margin:6px 0 0;color:rgba(255,255,255,0.80);font-size:14px;">
                Your Daily Study Reminder
              </p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 40px;">
              <h2 style="margin:0 0 12px;color:#1e1b4b;font-size:20px;font-weight:700;">
                ${msg.headline}
              </h2>
              <p style="margin:0 0 20px;color:#4b5563;font-size:15px;line-height:1.7;">
                ${msg.body}
              </p>

              <!-- CTA -->
              <table cellpadding="0" cellspacing="0" style="margin:24px 0;">
                <tr>
                  <td style="background:#6366f1;border-radius:10px;padding:14px 28px;">
                    <span style="color:#ffffff;font-size:15px;font-weight:700;">
                      📖 Open MnemoApp &amp; Study Now
                    </span>
                  </td>
                </tr>
              </table>

              <!-- Tip Box -->
              <div style="background:#f0f0ff;border-left:4px solid #6366f1;
                           border-radius:8px;padding:14px 18px;margin-top:8px;">
                <p style="margin:0;color:#4338ca;font-size:14px;font-weight:600;">
                  ${msg.tip}
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#f9fafb;padding:20px 40px;border-top:1px solid #e5e7eb;
                        text-align:center;">
              <p style="margin:0;color:#9ca3af;font-size:12px;line-height:1.6;">
                You're receiving this because you enabled Study Reminders in MnemoApp.<br/>
                To stop these emails, turn off reminders in your app settings.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}