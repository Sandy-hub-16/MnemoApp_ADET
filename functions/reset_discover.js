/**
 * ─────────────────────────────────────────────────────────────────────────────
 * RESET DISCOVER SCREEN
 *
 * One-time admin maintenance script. NOT part of the app, NOT a Cloud
 * Function, NOT wired to any button. Run manually from your own machine
 * whenever you, the developer, decide to wipe the Discover screen clean.
 *
 * What it does, for EVERY account in the system:
 *   1. Reads every document in the public_decks/ collection.
 *   2. Backs up that collection to a local JSON file (see BACKUP_PATH below)
 *      so the sharedAt/cloneCount/etc. history isn't lost forever.
 *   3. For each public deck:
 *        a. Updates users/{ownerUid}/decks/{deckId} -> visibility: "private"
 *        b. Deletes the public_decks/{deckId} mirror doc
 *   4. Prints a summary of how many decks were affected.
 *
 * This mirrors exactly what ShareService.setVisibility(visibility: "private")
 * already does for a single deck — this script just loops it over every
 * public deck in the system, using the Admin SDK so it can write to every
 * user's data regardless of who's signed in (security rules don't apply
 * to Admin SDK calls).
 *
 * ── SETUP (one-time) ─────────────────────────────────────────────────────
 *   1. Firebase Console -> Project Settings -> Service Accounts
 *      -> "Generate new private key" -> save the JSON file somewhere safe,
 *      OUTSIDE your git repo (this file contains full admin credentials).
 *   2. Place that file next to this script (or update SERVICE_ACCOUNT_PATH
 *      below to point at it).
 *   3. From the functions/ folder (or anywhere with firebase-admin
 *      installed): node reset_discover.js
 *      Add --dry-run to preview without writing anything:
 *        node reset_discover.js --dry-run
 *
 * ── SAFETY ───────────────────────────────────────────────────────────────
 *   - Always run with --dry-run first to see exactly what would change.
 *   - A JSON backup of every public_decks doc is written before any delete.
 *   - Firestore batches are capped at 500 writes, so this chunks decks into
 *     groups of 250 (2 writes per deck: 1 update + 1 delete) to stay safely
 *     under that limit per batch.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const path = require("path");
const fs = require("fs");
const admin = require("firebase-admin");

// ── Configuration ───────────────────────────────────────────────────────────

const SERVICE_ACCOUNT_PATH = path.join(__dirname, "serviceAccountKey.json");
const BACKUP_DIR = path.join(__dirname, "backups");
const DECKS_PER_BATCH = 250; // 2 writes per deck (update + delete) = 500/batch

const isDryRun = process.argv.includes("--dry-run");

// ── Init ──────────────────────────────────────────────────────────────────

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error(
    `Missing service account key at: ${SERVICE_ACCOUNT_PATH}\n` +
    "Download it from Firebase Console > Project Settings > " +
    "Service Accounts > Generate new private key, then place it there " +
    "(or edit SERVICE_ACCOUNT_PATH in this script).",
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
});

const db = admin.firestore();

// ── Main ──────────────────────────────────────────────────────────────────

async function main() {
  console.log(isDryRun ? "DRY RUN — no writes will be made.\n" : "LIVE RUN — this will modify Firestore.\n");

  console.log("Reading public_decks/ ...");
  const publicDecksSnap = await db.collection("public_decks").get();
  const deckDocs = publicDecksSnap.docs;

  console.log(`Found ${deckDocs.length} public deck(s).\n`);

  if (deckDocs.length === 0) {
    console.log("Nothing to do. Discover screen is already empty.");
    return;
  }

  // ── Backup before touching anything ────────────────────────────────────
  if (!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR, { recursive: true });

  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const backupPath = path.join(BACKUP_DIR, `public_decks_backup_${timestamp}.json`);

  const backupData = deckDocs.map((doc) => ({
    deckId: doc.id,
    ...doc.data(),
    // Firestore Timestamps don't serialize to plain JSON cleanly — convert
    // sharedAt to an ISO string so the backup file is human-readable.
    sharedAt: doc.data().sharedAt && doc.data().sharedAt.toDate
      ? doc.data().sharedAt.toDate().toISOString()
      : null,
  }));

  fs.writeFileSync(backupPath, JSON.stringify(backupData, null, 2));
  console.log(`Backed up ${deckDocs.length} deck(s) to:\n  ${backupPath}\n`);

  if (isDryRun) {
    console.log("Would update these decks to private and delete their public_decks mirror:");
    for (const doc of deckDocs) {
      const data = doc.data();
      const ownerUid = data.ownerUid;

      let note = "";
      if (!ownerUid) {
        note = "  [WARNING: missing ownerUid — will be skipped]";
      } else {
        const privateDeckSnap = await db
          .collection("users")
          .doc(ownerUid)
          .collection("decks")
          .doc(doc.id)
          .get();
        if (!privateDeckSnap.exists) {
          note = "  [ORPHANED: private deck no longer exists — mirror will just be deleted]";
        }
      }

      console.log(`  - ${doc.id}  "${data.title}"  owner=${ownerUid}${note}`);
    }
    console.log(`\nDry run complete. ${deckDocs.length} deck(s) would be affected. No writes were made.`);
    return;
  }

  // ── Chunk into batches and write ────────────────────────────────────────
  let processed = 0;
  let failed = 0;
  let orphaned = 0;

  for (let i = 0; i < deckDocs.length; i += DECKS_PER_BATCH) {
    const chunk = deckDocs.slice(i, i + DECKS_PER_BATCH);
    const batch = db.batch();

    for (const doc of chunk) {
      const data = doc.data();
      const deckId = doc.id;
      const ownerUid = data.ownerUid;

      if (!ownerUid) {
        console.warn(`  Skipping ${deckId} — missing ownerUid in public_decks doc.`);
        failed++;
        continue;
      }

      const privateDeckRef = db
        .collection("users")
        .doc(ownerUid)
        .collection("decks")
        .doc(deckId);

      // Guard against orphaned mirrors: the public_decks doc can outlive
      // the private deck it points to (e.g. the owner deleted the deck
      // from their library without the mirror being cleaned up). Trying to
      // update() a doc that doesn't exist fails the WHOLE batch, so check
      // first and only delete the stale mirror in that case.
      const privateDeckSnap = await privateDeckRef.get();
      if (!privateDeckSnap.exists) {
        console.warn(
          `  Orphaned mirror: ${deckId} "${data.title}" — private deck no longer exists. ` +
          "Deleting the public_decks mirror only.",
        );
        batch.delete(doc.ref);
        orphaned++;
        continue;
      }

      batch.update(privateDeckRef, { visibility: "private" });
      batch.delete(doc.ref);
    }

    await batch.commit();
    processed += chunk.length;
    console.log(`  Committed batch: ${processed}/${deckDocs.length} decks processed.`);
  }

  console.log("\nDone.");
  console.log(`  ${processed - failed - orphaned} deck(s) set to private and removed from Discover.`);
  if (orphaned > 0) console.log(`  ${orphaned} orphaned mirror(s) deleted (private deck no longer existed).`);
  if (failed > 0) console.log(`  ${failed} deck(s) skipped due to missing data (see warnings above).`);
  console.log(`  Backup saved at: ${backupPath}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Script failed:", err);
    process.exit(1);
  });