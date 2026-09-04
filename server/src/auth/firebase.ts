import {
  initializeApp,
  applicationDefault,
  cert,
  getApps,
  type App,
} from "firebase-admin/app";
import { getAuth, type DecodedIdToken } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { readFileSync } from "node:fs";
import { config } from "../config.js";

let app: App;

function init(): App {
  if (getApps().length) return getApps()[0]!;

  const credPath = config.GOOGLE_APPLICATION_CREDENTIALS;
  const credential = credPath
    ? cert(JSON.parse(readFileSync(credPath, "utf8")))
    : applicationDefault();

  return initializeApp({ credential, projectId: config.FIREBASE_PROJECT_ID });
}

app = init();

/** Verifies a Firebase ID token. Throws if invalid/expired. */
export function verifyIdToken(idToken: string): Promise<DecodedIdToken> {
  return getAuth(app).verifyIdToken(idToken, true);
}

/** Admin Firestore handle — bypasses security rules. Server writes only. */
export function adminFirestore(): Firestore {
  return getFirestore(app);
}
