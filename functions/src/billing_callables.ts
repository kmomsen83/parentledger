/**
 * Server-side billing field updates (Firestore rules block client writes to tiers / isPremium).
 */
import { db } from "./firebase_init";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { requireAuthUid } from "./callable_auth";

const PARENT_FREE_FLAGS = {
  messagingFull: false,
  exportsFull: false,
  reportsFull: false,
  aiToolsFull: false,
  timelineHistoryFull: false,
};

const COUNSEL_FLAGS = {
  counselWorkspace: true,
  messagingFull: true,
  exportsFull: true,
  reportsFull: true,
  aiToolsFull: true,
  timelineHistoryFull: true,
};

/** Parent skips paywall — free tier fields (callable; not RevenueCat). */
export const markParentContinueFree = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  const role = String(snap.data()?.["role"] ?? "parent").trim().toLowerCase();
  if (role === "attorney") {
    throw new HttpsError("failed-precondition", "Attorney accounts do not use this flow.");
  }

  await userRef.set(
    {
      onboardingStep: "onboardingComplete",
      onboardingLimitedAt: FieldValue.serverTimestamp(),
      accessLevel: "free",
      subscriptionStatus: "free",
      subscriptionTier: "free",
      accountType: "parent",
      entitlementFlags: PARENT_FREE_FLAGS,
      isPremium: false,
      premiumSource: FieldValue.delete(),
      premiumUpdatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return { ok: true };
});

/** After client sets `role: attorney`, apply counsel tier + flags (Admin). */
export const applyCounselSubscriptionDefaults = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  const role = String(snap.data()?.["role"] ?? "").trim().toLowerCase();
  if (role !== "attorney") {
    throw new HttpsError(
      "failed-precondition",
      "Set account type to Attorney before applying counsel billing defaults."
    );
  }

  await userRef.set(
    {
      subscriptionTier: "attorney_pro",
      subscriptionStatus: "active",
      accountType: "attorney",
      entitlementFlags: COUNSEL_FLAGS,
      premiumSource: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return { ok: true };
});
