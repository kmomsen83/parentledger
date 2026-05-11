/**
 * Single default-app bootstrap for Cloud Functions (v2).
 * Import this module before any Firestore/Auth/Messaging use — including via `export … from` chains.
 */
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

if (!getApps().length) {
  initializeApp();
}

export const db = getFirestore();
