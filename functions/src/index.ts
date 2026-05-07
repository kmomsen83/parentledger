/**
 * Server-side validation and transactions for critical co-parent flows.
 * Clients should call these callables instead of writing sensitive paths directly.
 */
import * as admin from "firebase-admin";
import { randomUUID } from "node:crypto";
import sgMail from "@sendgrid/mail";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2/options";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { requireAuthUid } from "./callable_auth";
import {
  assertCaseMember,
  commitCaseLedgerEvent,
  logCaseEvent,
  verifyCaseEventChain,
} from "./case_event_ledger";

export { logCaseEvent, verifyCaseEventChain };

export {
  analyzeFairness,
  classifyCoParentMessage,
  detectCompliance,
  detectViolations,
  generateCourtSummary,
} from "./gemini_ai";
export { smartAssistant } from "./smart_assistant";

setGlobalOptions({ region: "us-central1", maxInstances: 10 });

admin.initializeApp();
const db = admin.firestore();

const MEMBER_IDS = "memberIds";
/** Must stay aligned with `lib/util/subscription_limits.dart` (freeMaxExpenses). */
const FREE_MAX_EXPENSES = 5;
const INVITE_FAILURE_LIMIT = 5;
const RATE_LIMIT_MAX_ATTEMPTS = 20;
const RATE_LIMIT_WINDOW_MS = 60_000;
const LOG_RETENTION_DAYS = 90;

const SIGNUP_PARENT_TYPES = new Set(["mom", "dad", "guardian"]);
const SUPPORT_FROM_EMAIL = "noreply@parentledgerinfo.com";
let sendgridConfigured = false;

function trimMax(s: string, max: number): string {
  return s.trim().slice(0, max);
}

/** Structured JSON logs for invite debugging (search logs for `invite_flow`). */
function inviteStructuredLog(
  event: string,
  data: Record<string, unknown> = {}
): void {
  console.log(
    JSON.stringify({
      component: "invite_flow",
      ts: Date.now(),
      event,
      ...data,
    })
  );
}

async function copyInviterDisplayToInvitee(
  inviteeUid: string,
  senderUid: string | undefined
): Promise<void> {
  if (!senderUid) {
    return;
  }
  try {
    const snap = await db.collection("users").doc(senderUid).get();
    const ud = snap.data() ?? {};
    let display = trimMax(String(ud["displayName"] ?? ""), 200);
    if (!display.trim()) {
      const fn = trimMax(String(ud["firstName"] ?? ""), 80);
      const ln = trimMax(String(ud["lastName"] ?? ""), 80);
      display = trimMax(`${fn} ${ln}`.trim(), 200);
    }
    if (!display.trim()) {
      return;
    }
    await db.collection("users").doc(inviteeUid).set(
      { inviterDisplayName: display.trim() },
      { merge: true }
    );
  } catch (e) {
    console.error("copyInviterDisplayToInvitee failed", { inviteeUid, senderUid, e });
  }
}

const DEFAULT_COPARENT_INVITE_PERMISSIONS = {
  messaging: true,
  calendar: true,
  proposals: true,
  compromise: true,
  sharedChildData: true,
  read: true,
  comment: true,
  export: true,
  write: true,
};

function normalizePhone(input: unknown): string {
  const raw = String(input ?? "");
  return raw.replace(/[^\d+]/g, "");
}

function normalizeEmail(input: unknown): string {
  return String(input ?? "").trim().toLowerCase();
}

function asTrimmedString(input: unknown, max: number): string {
  return String(input ?? "").trim().slice(0, max);
}

async function findInviteByToken(
  token: string
): Promise<{ id: string; ref: admin.firestore.DocumentReference; data: Record<string, unknown> }> {
  const byIdRef = db.collection("caseInvites").doc(token);
  const byIdSnap = await byIdRef.get();
  if (byIdSnap.exists) {
    return {
      id: byIdSnap.id,
      ref: byIdRef,
      data: (byIdSnap.data() ?? {}) as Record<string, unknown>,
    };
  }
  const snap = await db
    .collection("caseInvites")
    .where("token", "==", token)
    .limit(1)
    .get();
  if (snap.empty) {
    throw new HttpsError("not-found", "Invite not found.");
  }
  const doc = snap.docs[0];
  return {
    id: doc.id,
    ref: doc.ref,
    data: (doc.data() ?? {}) as Record<string, unknown>,
  };
}

type ResolvedTokenInvite =
  | {
      kind: "coparentInvite";
      id: string;
      ref: admin.firestore.DocumentReference;
      data: Record<string, unknown>;
    }
  | {
      kind: "caseInvite";
      id: string;
      ref: admin.firestore.DocumentReference;
      data: Record<string, unknown>;
    };

async function resolveCoparentOrCaseInviteByToken(
  token: string
): Promise<ResolvedTokenInvite> {
  const copRef = db.collection("coparentInvites").doc(token);
  const copSnap = await copRef.get();
  if (copSnap.exists) {
    return {
      kind: "coparentInvite",
      id: token,
      ref: copRef,
      data: (copSnap.data() ?? {}) as Record<string, unknown>,
    };
  }
  const legacy = await findInviteByToken(token);
  return {
    kind: "caseInvite",
    id: legacy.id,
    ref: legacy.ref,
    data: legacy.data,
  };
}

async function summarizeCaseChildrenForInvite(caseId: string): Promise<Array<{ name: string }>> {
  if (!caseId) {
    return [];
  }
  const snap = await db
    .collection("cases")
    .doc(caseId)
    .collection("children")
    .limit(24)
    .get();
  const out: Array<{ name: string }> = [];
  for (const doc of snap.docs) {
    const d = doc.data() ?? {};
    let name =
      trimMax(String(d["name"] ?? d["displayName"] ?? ""), 120) || "Child";
    out.push({ name });
  }
  return out;
}

function toParentType(input: unknown): string {
  const normalized = asTrimmedString(input, 32).toLowerCase();
  if (!SIGNUP_PARENT_TYPES.has(normalized)) {
    throw new HttpsError("invalid-argument", "Invalid parentType.");
  }
  return normalized;
}

function recipientMatchesInvite(
  invite: Record<string, unknown>,
  uid: string,
  authPhone: string,
  authEmail: string
): { matched: boolean; reason: string } {
  const intendedRecipient = (invite["intendedRecipient"] ?? {}) as Record<string, unknown>;
  const intendedUserId = asTrimmedString(intendedRecipient["userId"], 128);
  const intendedEmail = normalizeEmail(intendedRecipient["email"]);
  const intendedPhone = normalizePhone(intendedRecipient["phone"]);
  const role = String(invite["role"] ?? "coparent");

  if (intendedUserId) {
    return {
      matched: intendedUserId === uid,
      reason: "Invite is assigned to a different account.",
    };
  }
  if (intendedEmail) {
    return {
      matched: !!authEmail && intendedEmail === authEmail,
      reason: "Invite email does not match this account.",
    };
  }
  if (intendedPhone) {
    return {
      matched: !!authPhone && intendedPhone === authPhone,
      reason: "Invite phone does not match this account.",
    };
  }

  if (role !== "attorney") {
    const invitePhone = normalizePhone(invite["toPhone"]);
    return {
      matched: !!invitePhone && !!authPhone && invitePhone === authPhone,
      reason: "Invite does not match this signed-in phone.",
    };
  }

  return {
    matched: false,
    reason: "Invite recipient is not configured.",
  };
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function getSendgridKey(): string {
  const direct = (
    process.env.SENDGRID_KEY ??
    process.env.SENDGRID_API_KEY ??
    process.env.SENDGRID_MAIL_KEY ??
    ""
  ).trim();
  if (direct) return direct;

  const runtimeConfigRaw = process.env.CLOUD_RUNTIME_CONFIG ?? "";
  if (!runtimeConfigRaw.trim()) return "";
  try {
    const parsed = JSON.parse(runtimeConfigRaw) as {
      sendgrid?: { key?: string };
    };
    return String(parsed.sendgrid?.key ?? "").trim();
  } catch (_) {
    return "";
  }
}

function ensureSendgridConfigured(): string {
  const key = getSendgridKey();
  if (!key) {
    throw new HttpsError("internal", "Email service is not configured.");
  }
  if (!sendgridConfigured) {
    sgMail.setApiKey(key);
    sendgridConfigured = true;
  }
  return key;
}

async function enforceRateLimit(
  key: string,
  maxAttempts = RATE_LIMIT_MAX_ATTEMPTS,
  windowMs = RATE_LIMIT_WINDOW_MS
): Promise<void> {
  const now = Date.now();
  const ref = db.collection("rateLimits").doc(key);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() as Record<string, unknown> | undefined;
    const windowStart = Number(data?.["windowStartMs"] ?? 0);
    const attempts = Number(data?.["attempts"] ?? 0);
    const inWindow = now - windowStart < windowMs;
    const nextAttempts = inWindow ? attempts + 1 : 1;
    if (inWindow && attempts >= maxAttempts) {
      throw new HttpsError("resource-exhausted", "Too many attempts. Try again later.");
    }
    tx.set(
      ref,
      {
        attempts: nextAttempts,
        windowStartMs: inWindow ? windowStart : now,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

async function incrementInviteFailure(inviteId: string): Promise<number> {
  const ref = db.collection("invites").doc(inviteId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = Number((snap.data() as Record<string, unknown> | undefined)?.["failedAttempts"] ?? 0);
    const next = current + 1;
    tx.set(
      ref,
      {
        failedAttempts: next,
        lastFailedAt: FieldValue.serverTimestamp(),
        status: next >= INVITE_FAILURE_LIMIT ? "failed" : FieldValue.delete(),
      },
      { merge: true }
    );
    return next;
  });
}

function getRequestIp(request: Record<string, unknown>): string {
  const rawRequest = request["rawRequest"] as { ip?: string } | undefined;
  return String(rawRequest?.ip ?? "unknown").trim() || "unknown";
}

/** Mirrors lib/services/invite_service acceptInvite + merge helper. */
export const acceptInvite = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const ip = getRequestIp(request as unknown as Record<string, unknown>);
  await enforceRateLimit(`acceptInvite_uid_${uid}`);
  await enforceRateLimit(`acceptInvite_ip_${ip}`);
  const inviteId = request.data?.inviteId as string | undefined;
  if (!inviteId || typeof inviteId !== "string") {
    throw new HttpsError("invalid-argument", "inviteId is required.");
  }

  const inviteRef = db.collection("caseInvites").doc(inviteId);
  const inviteLifecycleRef = db.collection("invites").doc(inviteId);
  const userRef = db.collection("users").doc(uid);

  try {
    await db.runTransaction(async (tx) => {
      const inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        throw new HttpsError("not-found", "Invite not found.");
      }
      const invite = inviteSnap.data() as Record<string, unknown>;
      if (invite["status"] !== "pending") {
        throw new HttpsError("failed-precondition", "Invite already used.");
      }
      const expiresAt = invite["expiresAt"] as admin.firestore.Timestamp | undefined;
      if (expiresAt && expiresAt.toDate().getTime() <= Date.now()) {
        tx.set(inviteRef, {
          status: "expired",
          expiredAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        throw new HttpsError("failed-precondition", "Invite expired.");
      }
      const caseId = invite["caseId"] as string | undefined;
      if (!caseId) {
        throw new HttpsError("failed-precondition", "Invalid invite.");
      }
      const role = String(invite["role"] ?? "coparent");
      const authPhone = normalizePhone(request.auth?.token?.phone_number);
      const authEmail = normalizeEmail(request.auth?.token?.email);
      const recipientMatch = recipientMatchesInvite(invite, uid, authPhone, authEmail);
      if (!recipientMatch.matched) {
        throw new HttpsError("permission-denied", recipientMatch.reason);
      }

    const userSnap = await tx.get(userRef);
    const userData = userSnap.data();
    const existingCaseId = userData?.["caseId"] as string | undefined;

    if (existingCaseId != null && existingCaseId !== caseId) {
      tx.update(userRef, {
        mergeFromCaseId: existingCaseId,
      });
    }

    tx.set(
      userRef,
      {
        caseId:
          role === "attorney" || role === "third_party"
            ? (existingCaseId ?? caseId)
            : caseId,
        onboardingStep:
          role === "attorney" || role === "third_party"
            ? "subscribed"
            : "invite_context",
        role:
          role === "attorney" || role === "third_party" ? "attorney" : "parent",
        parentType:
          role === "attorney" || role === "third_party"
            ? FieldValue.delete()
            : (userData?.["parentType"] as string | undefined) ?? "mom",
        accessLevel:
          role === "attorney" || role === "third_party"
            ? "lifetime"
            : (userData?.["accessLevel"] as string | undefined) ?? "free",
        subscriptionTier:
          role === "attorney" || role === "third_party"
            ? "free"
            : ((userData?.["subscriptionTier"] as string | undefined) ?? "free"),
      },
      { merge: true }
    );

    const caseRef = db.collection("cases").doc(caseId);
    const memberRef = caseRef.collection("members").doc(uid);
      const caseMemberRef = db.collection("caseMembers").doc(`${caseId}_${uid}`);

    tx.update(caseRef, {
      [MEMBER_IDS]: FieldValue.arrayUnion(uid),
    });

    tx.set(memberRef, {
      userId: uid,
      joinedAt: FieldValue.serverTimestamp(),
      role: role === "attorney" || role === "third_party" ? "attorney" : "parent",
    });
      tx.set(
        caseMemberRef,
        {
          caseId,
          userId: uid,
          role: role === "attorney" || role === "third_party" ? "attorney" : "parent",
          permissions: {
            read: true,
            comment: true,
            export: true,
            write: !(role === "attorney" || role === "third_party"),
          },
          linkedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    if (role === "attorney" || role === "third_party") {
      const attorneyCaseRef = userRef.collection("cases").doc(caseId);
      tx.set(
        attorneyCaseRef,
        {
          caseId,
          role: "attorney",
          linkedAt: FieldValue.serverTimestamp(),
          status: "active",
        },
        { merge: true }
      );
    }

      tx.update(inviteRef, {
        status: "accepted",
        acceptedBy: uid,
        acceptedAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        inviteLifecycleRef,
        {
          inviteId,
          status: "accepted",
          acceptedBy: uid,
          acceptedAt: FieldValue.serverTimestamp(),
          role,
        },
        { merge: true }
      );
    });
  } catch (error) {
    const failedAttempts = inviteId ? await incrementInviteFailure(inviteId) : 0;
    await inviteLifecycleRef.set(
      {
        status: failedAttempts >= INVITE_FAILURE_LIMIT ? "failed" : "pending",
        failedAt: FieldValue.serverTimestamp(),
        failedAttempts,
      },
      { merge: true }
    );
    await db.collection("inviteLogs").add({
      event: "invite_failed",
      inviteId,
      uid,
      error: error instanceof Error ? error.message : String(error),
      ip,
      timestamp: FieldValue.serverTimestamp(),
    });
    throw error;
  }

  await mergeChildrenIfNeeded(uid);

  const acceptedInvite = await inviteRef.get();
  const acceptedCaseId = acceptedInvite.data()?.["caseId"] as string | undefined;
  if (acceptedCaseId) {
    try {
      await commitCaseLedgerEvent({
        caseId: acceptedCaseId,
        type: "invite_accepted",
        actorId: uid,
        title: "Invite accepted",
        description: "A participant joined the case via invite.",
        data: { inviteId, status: "accepted" },
      });
    } catch (e) {
      console.error("case_events invite_accepted", e);
    }
  }

  await db.collection("inviteLogs").add({
    event: "invite_accepted",
    inviteId,
    uid,
    ip,
    timestamp: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

async function mergeChildrenIfNeeded(userId: string): Promise<void> {
  const userRef = db.collection("users").doc(userId);
  const userSnap = await userRef.get();
  const data = userSnap.data();
  const mergeFrom = data?.["mergeFromCaseId"] as string | undefined;
  const newCaseId = data?.["caseId"] as string | undefined;
  if (!mergeFrom || !newCaseId) {
    return;
  }

  const oldChildren = await db
    .collection("cases")
    .doc(mergeFrom)
    .collection("children")
    .get();

  if (oldChildren.empty) {
    await userRef.update({
      mergeFromCaseId: FieldValue.delete(),
    });
    return;
  }

  let batch = db.batch();
  let n = 0;
  for (const doc of oldChildren.docs) {
    const newRef = db
      .collection("cases")
      .doc(newCaseId)
      .collection("children")
      .doc();
    batch.set(newRef, doc.data());
    n++;
    if (n >= 400) {
      await batch.commit();
      batch = db.batch();
      n = 0;
    }
  }
  if (n > 0) {
    await batch.commit();
  }

  await userRef.update({
    mergeFromCaseId: FieldValue.delete(),
  });
}

/** Atomic case + profile creation after phone auth (replaces client-side signup writes). */
export const completeSignup = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const firstName = trimMax(String(request.data?.firstName ?? ""), 80);
  const lastName = trimMax(String(request.data?.lastName ?? ""), 80);
  const email = trimMax(String(request.data?.email ?? ""), 200);
  const parentType = toParentType(request.data?.parentType ?? request.data?.role);

  if (!firstName || !lastName) {
    throw new HttpsError("invalid-argument", "First and last name are required.");
  }
  const userRef = db.collection("users").doc(uid);
  const priorSnap = await userRef.get();
  const priorRole = String((priorSnap.data() as Record<string, unknown> | undefined)?.["role"] ?? "")
    .trim()
    .toLowerCase();
  if (priorRole === "attorney") {
    throw new HttpsError(
      "failed-precondition",
      "Attorney accounts use the counsel onboarding flow, not parent case setup."
    );
  }
  const caseRef = db.collection("cases").doc();
  const caseId = caseRef.id;
  const memberRef = caseRef.collection("members").doc(uid);
  const caseMemberRef = db.collection("caseMembers").doc(`${caseId}_${uid}`);

  const phone = request.auth?.token?.phone_number as string | undefined;

  const batch = db.batch();
  batch.set(
    userRef,
    {
      firstName,
      lastName,
      email: email || null,
      phone: phone ?? null,
      role: "parent",
      parentType,
      accessLevel: "free",
      subscriptionTier: "free",
      caseId,
      onboardingStep: "profile_complete",
      isPremium: false,
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  batch.set(caseRef, {
    ownerId: uid,
    [MEMBER_IDS]: [uid],
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(memberRef, {
    role: "parent",
    parentType,
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(
    caseMemberRef,
    {
      caseId,
      userId: uid,
      role: "parent",
      permissions: {
        read: true,
        comment: true,
        export: true,
        write: true,
      },
      linkedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();
  return { caseId };
});

/** Counsel profile completion — no custody case creation. */
export const completeAttorneyOnboarding = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const firstName = trimMax(String(request.data?.firstName ?? ""), 80);
  const lastName = trimMax(String(request.data?.lastName ?? ""), 80);
  const firmName = trimMax(String(request.data?.firmName ?? ""), 160);
  const barNumber = trimMax(String(request.data?.barNumber ?? ""), 120);

  if (!firstName || !lastName) {
    throw new HttpsError("invalid-argument", "First and last name are required.");
  }

  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  const role = String((snap.data() as Record<string, unknown> | undefined)?.["role"] ?? "")
    .trim()
    .toLowerCase();
  if (role !== "attorney") {
    throw new HttpsError("failed-precondition", "Account must be set to attorney before completing this step.");
  }

  await userRef.set(
    {
      firstName,
      lastName,
      firmName: firmName || null,
      barNumber: barNumber || null,
      onboardingStep: "onboarding_complete",
      role: "attorney",
    },
    { merge: true }
  );
  return { ok: true };
});

/** Minimal user document when a user first lands (replaces client ensureUserDoc). */
export const ensureUserBootstrap = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (snap.exists) {
      return;
    }
    tx.set(userRef, {
      createdAt: FieldValue.serverTimestamp(),
      onboardingStep: "account_type",
      isPremium: false,
      accessLevel: "free",
      subscriptionTier: "free",
    });
  });
  return { ok: true };
});

/**
 * Creates `cases/{caseId}/expenses/{id}` + ledger row with server-side free-tier enforcement.
 * Clients should call this instead of writing expenses directly.
 */
export const createCaseExpense = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const caseId = String(request.data?.caseId ?? "").trim();
  const amountRaw = request.data?.amount;
  const amount =
    typeof amountRaw === "number"
      ? amountRaw
      : typeof amountRaw === "string"
        ? Number(amountRaw)
        : Number.NaN;
  const description = trimMax(String(request.data?.description ?? ""), 4000);
  const paid = Boolean(request.data?.paid);

  if (!caseId || !description.trim()) {
    throw new HttpsError("invalid-argument", "caseId and description are required.");
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "amount must be a positive number.");
  }

  await assertCaseMember(caseId, uid);

  const userSnap = await db.collection("users").doc(uid).get();
  const ud = userSnap.data() as Record<string, unknown> | undefined;
  const fullAccess =
    ud?.isPremium === true ||
    ud?.accessLevel === "lifetime" ||
    ud?.accessLevel === "subscription";

  const expensesCol = db.collection("cases").doc(caseId).collection("expenses");
  if (!fullAccess) {
    const agg = await expensesCol.count().get();
    const n = agg.data().count ?? 0;
    if (n >= FREE_MAX_EXPENSES) {
      throw new HttpsError(
        "resource-exhausted",
        "Free tier expense limit reached. Upgrade to add more expenses.",
      );
    }
  }

  const expenseRef = expensesCol.doc();
  await expenseRef.set({
    amount,
    description,
    paid,
    status: paid ? "paid" : "unpaid",
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  try {
    await commitCaseLedgerEvent({
      caseId,
      type: "expense_created",
      actorId: uid,
      title: "Expense created",
      description:
        description.trim().length === 0 ? `$${amount.toFixed(2)}` : description.trim(),
      data: {
        expenseId: expenseRef.id,
        amount,
        title: description,
        status: paid ? "paid" : "unpaid",
      },
    });
  } catch (e) {
    await expenseRef.delete().catch(() => undefined);
    throw e;
  }

  return { expenseId: expenseRef.id };
});

/** Validates membership before writing immutable message + conversation envelope. */
export const sendConversationMessage = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const conversationId = request.data?.conversationId as string | undefined;
  const textRaw = String(request.data?.text ?? "");
  const text = trimMax(textRaw, 10000);
  const imageUrlRaw = request.data?.imageUrl as string | undefined;
  const imageUrl =
    imageUrlRaw && typeof imageUrlRaw === "string" && imageUrlRaw.startsWith("https://")
      ? imageUrlRaw.slice(0, 2048)
      : undefined;
  const exchangeId = request.data?.exchangeId as string | undefined | null;

  if (!conversationId) {
    throw new HttpsError("invalid-argument", "conversationId is required.");
  }
  if (!text && !imageUrl) {
    throw new HttpsError(
      "invalid-argument",
      "Either text or a valid https imageUrl is required."
    );
  }

  const convoRef = db.collection("conversations").doc(conversationId);
  const convoSnap = await convoRef.get();
  if (!convoSnap.exists) {
    throw new HttpsError("not-found", "Conversation not found.");
  }
  const data = convoSnap.data() as Record<string, unknown>;
  const members = (data[MEMBER_IDS] as string[] | undefined) ??
    (data["participants"] as string[] | undefined) ??
    [];
  if (!members.includes(uid)) {
    throw new HttpsError("permission-denied", "Not a member of this conversation.");
  }

  const msgRef = convoRef.collection("messages").doc();
  const batch = db.batch();

  if (imageUrl) {
    batch.set(msgRef, {
      senderId: uid,
      type: "image",
      imageUrl,
      createdAt: FieldValue.serverTimestamp(),
      readAt: null,
      exchangeId: exchangeId ?? null,
      edited: false,
      deleted: false,
    });
    batch.set(
      convoRef,
      {
        [MEMBER_IDS]: FieldValue.arrayUnion(uid),
        lastMessage: "[Image]",
        lastTimestamp: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } else {
    batch.set(msgRef, {
      text,
      senderId: uid,
      type: "text",
      createdAt: FieldValue.serverTimestamp(),
      readAt: null,
      exchangeId: exchangeId ?? null,
      edited: false,
      deleted: false,
    });
    batch.set(
      convoRef,
      {
        [MEMBER_IDS]: FieldValue.arrayUnion(uid),
        lastMessage: text,
        lastTimestamp: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch.commit();

  return { messageId: msgRef.id };
});

/** Creates a pending invite document; server enforces sender owns a case. */
export const createCaseInvite = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const ip = getRequestIp(request as unknown as Record<string, unknown>);
  const toPhone = trimMax(String(request.data?.toPhone ?? ""), 32);
  const email = trimMax(String(request.data?.email ?? ""), 200);
  const role = trimMax(String(request.data?.role ?? ""), 40);
  const intendedRecipientUserId = asTrimmedString(request.data?.intendedRecipientUserId, 128);
  const intendedRecipientEmail = normalizeEmail(request.data?.intendedRecipientEmail);
  const intendedRecipientPhone = normalizePhone(
    request.data?.intendedRecipientPhone ?? toPhone
  );

  if (!toPhone && !intendedRecipientEmail && !intendedRecipientUserId) {
    throw new HttpsError("invalid-argument", "A recipient phone, email, or user is required.");
  }

  const userSnap = await db.collection("users").doc(uid).get();
  const caseId = userSnap.data()?.["caseId"] as string | undefined;
  if (!caseId) {
    throw new HttpsError("failed-precondition", "You must belong to a case to send invites.");
  }

  const inviteRef = db.collection("caseInvites").doc();
  const lifecycleRef = db.collection("invites").doc(inviteRef.id);
  const roleValue = role || "coparent";
  const intendedRecipient = {
    userId: intendedRecipientUserId || null,
    email: intendedRecipientEmail || null,
    phone: intendedRecipientPhone || null,
  };
  await inviteRef.set({
    inviteId: inviteRef.id,
    fromUserId: uid,
    caseId,
    toPhone,
    email: email || null,
    role: roleValue,
    intendedRecipient,
    status: "pending",
    openedAt: null,
    acceptedAt: null,
    expiredAt: null,
    expiresAt: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 1000 * 60 * 60 * 24 * 30)
    ),
    createdAt: FieldValue.serverTimestamp(),
  });
  await lifecycleRef.set(
    {
      inviteId: inviteRef.id,
      caseId,
      fromUserId: uid,
      role: roleValue,
      intendedRecipient,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      openedAt: null,
      acceptedAt: null,
      expiredAt: null,
      failedAttempts: 0,
    },
    { merge: true }
  );
  await db.collection("inviteLogs").add({
    event: "invite_created",
    inviteId: inviteRef.id,
    uid,
    ip,
    timestamp: FieldValue.serverTimestamp(),
  });

  try {
    await commitCaseLedgerEvent({
      caseId,
      type: "invite_sent",
      actorId: uid,
      title: "Invite sent",
      description:
        roleValue === "attorney"
          ? `Attorney invite created (${inviteRef.id}).`
          : `Co-parent invite created (${inviteRef.id}).`,
      data: { inviteId: inviteRef.id, role: roleValue },
    });
  } catch (e) {
    console.error("case_events invite_sent", e);
  }

  const inviteId = inviteRef.id;
  const origin = "https://parentledger.org";
  const universalLink =
    roleValue === "attorney"
      ? `${origin}/invite/attorney/${inviteId}`
      : `${origin}/invite/${inviteId}`;
  const deepLink =
    roleValue === "attorney"
      ? `parentledger://invite/attorney/${inviteId}`
      : `parentledger://invite/${inviteId}`;

  return {
    inviteId,
    token: inviteId,
    universalLink,
    deepLink,
  };
});

export const validateInvite = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const ip = getRequestIp(request as unknown as Record<string, unknown>);
  await enforceRateLimit(`validateInvite_uid_${uid}`);
  await enforceRateLimit(`validateInvite_ip_${ip}`);
  const inviteId = asTrimmedString(request.data?.inviteId, 128);
  if (!inviteId) {
    throw new HttpsError("invalid-argument", "inviteId is required.");
  }

  const inviteRef = db.collection("caseInvites").doc(inviteId);
  const inviteLifecycleRef = db.collection("invites").doc(inviteId);
  const snap = await inviteRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Invite not found.");
  }
  const invite = snap.data() as Record<string, unknown>;
  const status = String(invite["status"] ?? "pending");
  const authPhone = normalizePhone(request.auth?.token?.phone_number);
  const authEmail = normalizeEmail(request.auth?.token?.email);
  const recipientMatch = recipientMatchesInvite(invite, uid, authPhone, authEmail);
  if (!recipientMatch.matched) {
    const failedAttempts = await incrementInviteFailure(inviteId);
    await db.collection("inviteLogs").add({
      event: "unauthorized_attempt",
      inviteId,
      uid,
      ip,
      failedAttempts,
      reason: recipientMatch.reason,
      timestamp: FieldValue.serverTimestamp(),
    });
    throw new HttpsError("permission-denied", recipientMatch.reason);
  }
  const expiresAt = invite["expiresAt"] as admin.firestore.Timestamp | undefined;
  if (status !== "pending") {
    throw new HttpsError("failed-precondition", "Invite already used.");
  }
  if (expiresAt && expiresAt.toDate().getTime() <= Date.now()) {
    await inviteRef.set(
      { status: "expired", expiredAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    await inviteLifecycleRef.set(
      { status: "expired", expiredAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    throw new HttpsError("failed-precondition", "Invite expired.");
  }

  await inviteRef.set(
    { openedAt: FieldValue.serverTimestamp() },
    { merge: true }
  );
  await inviteLifecycleRef.set(
    { openedAt: FieldValue.serverTimestamp(), status: status },
    { merge: true }
  );
  await db.collection("inviteLogs").add({
    event: "invite_opened",
    inviteId,
    uid,
    ip,
    timestamp: FieldValue.serverTimestamp(),
  });

  return {
    inviteId,
    role: String(invite["role"] ?? "coparent"),
    fromDisplayName: String(invite["fromDisplayName"] ?? ""),
    status,
  };
});

/** Token-based validation used by invite deep links. */
export const validateCaseInvite = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const token = asTrimmedString(request.data?.token, 200);
  if (!token) {
    throw new HttpsError("invalid-argument", "token is required.");
  }
  inviteStructuredLog("validate_case_invite_begin", {
    tokenPrefix: token.slice(0, 8),
    uid,
  });
  const resolved = await resolveCoparentOrCaseInviteByToken(token);

  if (resolved.kind === "coparentInvite") {
    const d = resolved.data;
    const status = String(d["status"] ?? "pending");
    const recipientStatus = String(d["recipientStatus"] ?? "pending");
    const caseId = String(d["caseId"] ?? "");
    const expiresAt = d["expiresAt"] as admin.firestore.Timestamp | undefined;
    const senderUid = String(d["senderUid"] ?? "");

    if (status !== "pending") {
      throw new HttpsError("failed-precondition", "Invite already used.");
    }
    if (recipientStatus === "declined") {
      throw new HttpsError("failed-precondition", "Invite was declined.");
    }
    if (expiresAt && expiresAt.toDate().getTime() <= Date.now()) {
      await resolved.ref.set(
        {
          status: "expired",
          recipientStatus: "expired",
          expiredAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      throw new HttpsError("failed-precondition", "Invite expired.");
    }

    let fromDisplayName = "";
    let fromPhotoUrl = "";
    if (senderUid) {
      const uSnap = await db.collection("users").doc(senderUid).get();
      const ud = uSnap.data() ?? {};
      fromDisplayName = trimMax(String(ud["displayName"] ?? ""), 200);
      if (!fromDisplayName.trim()) {
        const fn = trimMax(String(ud["firstName"] ?? ""), 80);
        const ln = trimMax(String(ud["lastName"] ?? ""), 80);
        fromDisplayName = trimMax(`${fn} ${ln}`.trim(), 200);
      }
      fromPhotoUrl = trimMax(
        String(ud["photoURL"] ?? ud["photoUrl"] ?? ""),
        800
      );
    }
    const children = await summarizeCaseChildrenForInvite(caseId);
    inviteStructuredLog("validate_case_invite_ok", {
      inviteKind: "coparentFirestore",
      caseId,
      uid,
      tokenPrefix: token.slice(0, 8),
    });
    return {
      inviteKind: "coparentFirestore",
      inviteId: token,
      token,
      caseId,
      role: "coparent",
      status,
      recipientStatus,
      fromDisplayName,
      fromPhotoUrl,
      children,
      senderUid,
    };
  }

  const invite = resolved.data;
  const status = String(invite["status"] ?? "pending");
  const role = String(invite["role"] ?? "coparent");
  const caseId = String(invite["caseId"] ?? "");
  const uses = Number(invite["uses"] ?? 0);
  const maxUses = Number(invite["maxUses"] ?? 1);
  const expiresAt = invite["expiresAt"] as admin.firestore.Timestamp | undefined;
  if (status !== "pending") {
    throw new HttpsError("failed-precondition", "Invite already used.");
  }
  if (uses >= maxUses) {
    throw new HttpsError("failed-precondition", "Invite has no uses remaining.");
  }
  if (expiresAt && expiresAt.toDate().getTime() <= Date.now()) {
    await resolved.ref.set(
      { status: "expired", expiredAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    throw new HttpsError("failed-precondition", "Invite expired.");
  }
  inviteStructuredLog("validate_case_invite_ok", {
    inviteKind: "caseInviteDoc",
    caseId,
    inviteDocId: resolved.id,
    uid,
    tokenPrefix: token.slice(0, 8),
  });
  return {
    inviteKind: "caseInviteDoc",
    inviteId: resolved.id,
    caseId,
    role,
    status,
    uses,
    maxUses,
  };
});

async function transactionAcceptLegacyCaseInviteToken(
  uid: string,
  inviteRef: admin.firestore.DocumentReference
): Promise<{ caseId: string; role: string; alreadyMember: boolean }> {
  return db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invite not found.");
    }
    const invite = (inviteSnap.data() ?? {}) as Record<string, unknown>;
    const caseId = String(invite["caseId"] ?? "");
    if (!caseId) {
      throw new HttpsError("failed-precondition", "Invite is missing caseId.");
    }
    const role = String(invite["role"] ?? "coparent");
    const status = String(invite["status"] ?? "pending");
    const uses = Number(invite["uses"] ?? 0);
    const maxUses = Number(invite["maxUses"] ?? 1);
    const expiresAt = invite["expiresAt"] as admin.firestore.Timestamp | undefined;

    if (status !== "pending") {
      throw new HttpsError("failed-precondition", "Invite already used.");
    }
    if (uses >= maxUses) {
      throw new HttpsError("failed-precondition", "Invite has no uses remaining.");
    }
    if (expiresAt && expiresAt.toDate().getTime() <= Date.now()) {
      tx.set(inviteRef, {
        status: "expired",
        expiredAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      throw new HttpsError("failed-precondition", "Invite expired.");
    }

    const caseRef = db.collection("cases").doc(caseId);
    const caseSnap = await tx.get(caseRef);
    if (!caseSnap.exists) {
      throw new HttpsError("not-found", "Case not found.");
    }
    const caseData = (caseSnap.data() ?? {}) as Record<string, unknown>;
    const participants = (caseData["participants"] as string[] | undefined) ?? [];
    const memberIds = (caseData[MEMBER_IDS] as string[] | undefined) ?? [];
    const alreadyMember = participants.includes(uid) || memberIds.includes(uid);
    if (alreadyMember) {
      return { caseId, role, alreadyMember: true };
    }

    tx.set(
      caseRef,
      {
        participants: FieldValue.arrayUnion(uid),
        [MEMBER_IDS]: FieldValue.arrayUnion(uid),
      },
      { merge: true }
    );
    tx.set(
      caseRef.collection("members").doc(uid),
      {
        userId: uid,
        role: role === "attorney" ? "attorney" : "parent",
        joinedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    tx.set(
      caseRef.collection("caseMembers").doc(uid),
      {
        userId: uid,
        role: role,
        joinedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    tx.set(
      db.collection("caseMembers").doc(`${caseId}_${uid}`),
      {
        caseId,
        userId: uid,
        role: role === "attorney" ? "attorney" : "parent",
        linkedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const userRef = db.collection("users").doc(uid);
    tx.set(
      userRef,
      role === "attorney"
        ? {
            role: "attorney",
            onboardingStep: "subscribed",
          }
        : {
            role: "parent",
            caseId,
            onboardingStep: "invite_context",
          },
      { merge: true }
    );

    const nextUses = uses + 1;
    tx.set(
      inviteRef,
      {
        uses: nextUses,
        status: nextUses >= maxUses ? "accepted" : "pending",
        acceptedBy: uid,
        acceptedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { caseId, role, alreadyMember: false };
  });
}

async function transactionAcceptCoparentFirestoreInvite(
  uid: string,
  inviteRef: admin.firestore.DocumentReference
): Promise<{ caseId: string; role: string; alreadyMember: boolean }> {
  return db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invite not found.");
    }
    const inv = (inviteSnap.data() ?? {}) as Record<string, unknown>;
    const caseId = String(inv["caseId"] ?? "");
    const senderUid = String(inv["senderUid"] ?? "");
    const status = String(inv["status"] ?? "pending");
    const recipientStatus = String(inv["recipientStatus"] ?? "pending");
    const expiresAt = inv["expiresAt"] as admin.firestore.Timestamp | undefined;

    if (!caseId) {
      throw new HttpsError("failed-precondition", "Invite is missing caseId.");
    }
    if (senderUid && senderUid === uid) {
      throw new HttpsError("invalid-argument", "You cannot accept your own invite.");
    }
    if (status !== "pending") {
      throw new HttpsError("failed-precondition", "Invite already used.");
    }
    if (recipientStatus === "declined") {
      throw new HttpsError("failed-precondition", "Invite was declined.");
    }
    if (expiresAt && expiresAt.toDate().getTime() <= Date.now()) {
      tx.set(
        inviteRef,
        {
          status: "expired",
          recipientStatus: "expired",
          expiredAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      throw new HttpsError("failed-precondition", "Invite expired.");
    }

    const role = "coparent";
    const caseRef = db.collection("cases").doc(caseId);
    const caseSnap = await tx.get(caseRef);
    if (!caseSnap.exists) {
      throw new HttpsError("not-found", "Case not found.");
    }
    const caseData = (caseSnap.data() ?? {}) as Record<string, unknown>;
    const participants = (caseData["participants"] as string[] | undefined) ?? [];
    const memberIds = (caseData[MEMBER_IDS] as string[] | undefined) ?? [];
    const alreadyMember = participants.includes(uid) || memberIds.includes(uid);

    const userRef = db.collection("users").doc(uid);
    const userSnap = await tx.get(userRef);
    const userData = userSnap.data();

    const preRole = String(userData?.["role"] ?? "parent");
    if (preRole === "attorney") {
      throw new HttpsError(
        "permission-denied",
        "Attorney accounts cannot join via co-parent invite."
      );
    }

    const existingCaseIdEarly = userData?.["caseId"] as string | undefined;
    if (existingCaseIdEarly === caseId) {
      return { caseId, role, alreadyMember: true };
    }

    if (alreadyMember) {
      return { caseId, role, alreadyMember: true };
    }

    if (existingCaseIdEarly != null && existingCaseIdEarly !== caseId) {
      tx.update(userRef, {
        mergeFromCaseId: existingCaseIdEarly,
      });
    }

    tx.set(
      caseRef,
      {
        participants: FieldValue.arrayUnion(uid),
        [MEMBER_IDS]: FieldValue.arrayUnion(uid),
      },
      { merge: true }
    );
    tx.set(
      caseRef.collection("members").doc(uid),
      {
        userId: uid,
        role: "parent",
        joinedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    tx.set(
      caseRef.collection("caseMembers").doc(uid),
      {
        userId: uid,
        role,
        joinedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    tx.set(
      db.collection("caseMembers").doc(`${caseId}_${uid}`),
      {
        caseId,
        userId: uid,
        role: "parent",
        permissions: {
          read: true,
          comment: true,
          export: true,
          write: true,
        },
        linkedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(
      userRef,
      {
        role: "parent",
        caseId,
        onboardingStep: "invite_context",
        parentType: (userData?.["parentType"] as string | undefined) ?? "mom",
        accessLevel: (userData?.["accessLevel"] as string | undefined) ?? "free",
        subscriptionTier: (userData?.["subscriptionTier"] as string | undefined) ?? "free",
      },
      { merge: true }
    );

    tx.set(
      inviteRef,
      {
        status: "accepted",
        recipientStatus: "accepted",
        used: true,
        acceptedAt: FieldValue.serverTimestamp(),
        acceptedByUid: uid,
      },
      { merge: true }
    );

    return { caseId, role, alreadyMember: false };
  });
}

/** Secure token acceptance: transactional case join + role assignment. */
export const acceptCaseInvite = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const token = asTrimmedString(request.data?.token, 200);
  if (!token) {
    throw new HttpsError("invalid-argument", "token is required.");
  }
  const resolved = await resolveCoparentOrCaseInviteByToken(token);
  let result: { caseId: string; role: string; alreadyMember: boolean };
  let ledgerInviteId = token;

  if (resolved.kind === "coparentInvite") {
    result = await transactionAcceptCoparentFirestoreInvite(uid, resolved.ref);
  } else {
    ledgerInviteId = resolved.id;
    result = await transactionAcceptLegacyCaseInviteToken(uid, resolved.ref);
  }

  inviteStructuredLog("accept_case_invite_applied", {
    inviteKind: resolved.kind,
    uid,
    caseId: result.caseId,
    alreadyMember: result.alreadyMember,
    tokenPrefix: token.slice(0, 8),
  });

  if (resolved.kind === "coparentInvite" && !result.alreadyMember) {
    await mergeChildrenIfNeeded(uid);
    await copyInviterDisplayToInvitee(
      uid,
      String(resolved.data["senderUid"] ?? "")
    );
  }

  if (!result.alreadyMember) {
    await commitCaseLedgerEvent({
      caseId: result.caseId,
      type: "invite_accepted",
      actorId: uid,
      title: "Invite accepted",
      description: `Invite accepted as ${result.role}.`,
      data: {
        role: result.role,
        inviteId: ledgerInviteId,
      },
    });
  }

  return {
    ok: true,
    caseId: result.caseId,
    role: result.role,
    alreadyMember: result.alreadyMember,
  };
});

/** Invitee declines a pending co-parent token invite (`coparentInvites/{token}`). */
export const declineCoparentInvite = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const token = asTrimmedString(request.data?.token, 200);
  if (!token) {
    throw new HttpsError("invalid-argument", "token is required.");
  }
  const ref = db.collection("coparentInvites").doc(token);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Invite not found.");
  }
  const d = snap.data() ?? {};
  const status = String(d["status"] ?? "pending");
  if (status !== "pending") {
    throw new HttpsError("failed-precondition", "Invite is no longer pending.");
  }
  await ref.set(
    {
      recipientStatus: "declined",
      status: "declined",
      declinedAt: FieldValue.serverTimestamp(),
      declinedByUid: uid,
    },
    { merge: true }
  );
  return { ok: true };
});

export const cleanupExpiredInvites = onSchedule("every 24 hours", async () => {
  const now = admin.firestore.Timestamp.now();

  const staleCase = await db
    .collection("caseInvites")
    .where("status", "==", "pending")
    .where("expiresAt", "<=", now)
    .limit(500)
    .get();
  if (!staleCase.empty) {
    const batch = db.batch();
    for (const doc of staleCase.docs) {
      batch.set(
        doc.ref,
        { status: "expired", expiredAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
      batch.set(
        db.collection("invites").doc(doc.id),
        { status: "expired", expiredAt: FieldValue.serverTimestamp() },
        { merge: true }
      );
    }
    await batch.commit();
  }

  const staleCoparent = await db
    .collection("coparentInvites")
    .where("status", "==", "pending")
    .where("expiresAt", "<=", now)
    .limit(500)
    .get();
  if (staleCoparent.empty) {
    return;
  }
  const batch2 = db.batch();
  for (const doc of staleCoparent.docs) {
    batch2.set(
      doc.ref,
      {
        status: "expired",
        recipientStatus: "expired",
        expiredAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await batch2.commit();
});

export const pruneOldLogs = onSchedule("every 24 hours", async () => {
  const cutoff = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - LOG_RETENTION_DAYS * 24 * 60 * 60 * 1000)
  );
  const collections = [
    { name: "inviteLogs", timeField: "timestamp" },
    { name: "emailLogs", timeField: "timestamp" },
    { name: "rateLimits", timeField: "updatedAt" },
  ];
  for (const entry of collections) {
    const query = await db.collection(entry.name).where(entry.timeField, "<", cutoff).limit(500).get();
    if (query.empty) continue;
    const batch = db.batch();
    for (const doc of query.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
});

export const softDeleteCase = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const caseId = asTrimmedString(request.data?.caseId, 128);
  if (!caseId) {
    throw new HttpsError("invalid-argument", "caseId is required.");
  }
  const caseRef = db.collection("cases").doc(caseId);
  const caseSnap = await caseRef.get();
  if (!caseSnap.exists) {
    throw new HttpsError("not-found", "Case not found.");
  }
  const data = caseSnap.data() as Record<string, unknown>;
  if (String(data["ownerId"] ?? "") !== uid) {
    throw new HttpsError("permission-denied", "Only case owner can archive this case.");
  }
  await caseRef.set(
    {
      deletedAt: FieldValue.serverTimestamp(),
      deletedBy: uid,
      status: "archived",
    },
    { merge: true }
  );
  await db.collection("inviteLogs").add({
    event: "case_soft_deleted",
    caseId,
    uid,
    timestamp: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

/** Server relay for court document email delivery via SendGrid. */
export const sendCourtDocumentEmail = onCall(
  { secrets: ["SENDGRID_KEY"] },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const toEmail = normalizeEmail(asTrimmedString(request.data?.toEmail, 320));
  const subject = asTrimmedString(
    request.data?.subject ?? "Court Document from ParentLedger",
    200
  ) || "Court Document from ParentLedger";
  const message = asTrimmedString(
    request.data?.message ?? "A court document has been shared with you.",
    10000
  ) || "A court document has been shared with you.";
  const pdfBase64Raw = asTrimmedString(request.data?.pdfBase64, 12_000_000);
  const fileNameRaw = asTrimmedString(
    request.data?.fileName ?? "court-document.pdf",
    180
  );
  const fileName = fileNameRaw || "court-document.pdf";
  const hasAttachment = pdfBase64Raw.length > 0;

  if (!toEmail) {
    throw new HttpsError("invalid-argument", "toEmail is required");
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(toEmail)) {
    throw new HttpsError("invalid-argument", "Invalid toEmail format.");
  }
  if (hasAttachment && !/^[A-Za-z0-9+/=]+$/.test(pdfBase64Raw)) {
    throw new HttpsError("invalid-argument", "pdfBase64 must be valid base64.");
  }

  ensureSendgridConfigured();

  const htmlBody = `
    <div style="font-family:Arial,Helvetica,sans-serif;line-height:1.55;color:#111827;">
      <h2 style="margin:0 0 12px 0;font-size:18px;">ParentLedger Court Communication</h2>
      <p style="margin:0 0 12px 0;">${escapeHtml(message).replace(/\n/g, "<br/>")}</p>
      <hr style="border:none;border-top:1px solid #e5e7eb;margin:16px 0;" />
      <p style="margin:0;font-size:12px;color:#6b7280;">Sent via ParentLedger</p>
    </div>
  `.trim();

  try {
    console.log("Court document sent", {
      toEmail,
      subject,
      uid,
    });
    await sgMail.send({
      to: toEmail,
      from: SUPPORT_FROM_EMAIL,
      subject,
      text: message,
      html: htmlBody,
      ...(hasAttachment
        ? {
            attachments: [
              {
                content: pdfBase64Raw,
                filename: fileName,
                type: "application/pdf",
                disposition: "attachment",
              },
            ],
          }
        : {}),
    });

    await db.collection("emailLogs").add({
      uid,
      toEmail,
      subject,
      messageLength: message.length,
      hasAttachment,
      timestamp: FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error("sendCourtDocumentEmail failed", {
      uid,
      toEmail,
      subject,
      messageLength: message.length,
      hasAttachment,
      error,
    });
    throw new HttpsError("internal", "Email failed to send");
  }
  }
);

export const sendSupportEmail = onCall(
  { secrets: ["SENDGRID_KEY"] },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const userId = asTrimmedString(request.data?.userId ?? uid, 128);
  const email = normalizeEmail(asTrimmedString(request.data?.email, 320));
  const issue = asTrimmedString(request.data?.issue ?? "general", 80).toLowerCase();
  const message = asTrimmedString(request.data?.message ?? "", 1000);
  const appVersion = asTrimmedString(request.data?.appVersion ?? "", 64);
  const platform = asTrimmedString(request.data?.platform ?? "", 64);

  if (!email) {
    throw new HttpsError("invalid-argument", "email is required");
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Invalid email format.");
  }
  if (!issue) {
    throw new HttpsError("invalid-argument", "issue is required");
  }

  ensureSendgridConfigured();
  const subject = `ParentLedger Support: ${issue}`;
  const textBody = [
    `Issue: ${issue}`,
    `User ID: ${userId || uid}`,
    `Email: ${email}`,
    appVersion ? `App Version: ${appVersion}` : null,
    platform ? `Platform: ${platform}` : null,
    "",
    "Message:",
    message || "(none provided)",
  ]
    .filter((line): line is string => !!line)
    .join("\n");

  try {
    await sgMail.send({
      to: SUPPORT_FROM_EMAIL,
      from: SUPPORT_FROM_EMAIL,
      subject,
      text: textBody,
      html: `<pre style="font-family:Arial,Helvetica,sans-serif;white-space:pre-wrap;">${escapeHtml(textBody)}</pre>`,
      replyTo: email,
    });

    await db.collection("emailLogs").add({
      uid,
      supportIssue: issue,
      requesterEmail: email,
      hasMessage: message.length > 0,
      timestamp: FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error("sendSupportEmail failed", {
      uid,
      userId,
      issue,
      email,
      error,
    });
    throw new HttpsError("internal", "Support request failed");
  }
  }
);

// -----------------------------------------------------------------------------
// Co-parent invites: `coparentInvites/{uuid}` — Universal Links + app deep link (48h TTL)
// Legacy alphanumeric codes remain in `coparentInviteCodes` for `acceptCoparentInviteCode`.
// Shareable URLs: `https://parentledger.org/invite/{token}` (path-only, one-time use).
// -----------------------------------------------------------------------------

const COPARENT_INVITE_TTL_MS = 48 * 60 * 60 * 1000;

/** Creates `coparentInvites/{token}` for native Universal Links (`/invite/{token}`). */
export const createCoparentInviteCode = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const ip = getRequestIp(request as unknown as Record<string, unknown>);
  await enforceRateLimit(`createCoparentInviteCode_uid_${uid}`);
  await enforceRateLimit(`createCoparentInviteCode_ip_${ip}`);

  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data() ?? {};
  const caseId = userData["caseId"] as string | undefined;
  if (!caseId) {
    throw new HttpsError("failed-precondition", "You must belong to a case to invite someone.");
  }
  const userRole = String(userData["role"] ?? "parent");
  if (userRole === "attorney") {
    throw new HttpsError("permission-denied", "Attorney accounts cannot create co-parent invites.");
  }

  const token = randomUUID();
  const ref = db.collection("coparentInvites").doc(token);
  const collide = await ref.get();
  if (collide.exists) {
    throw new HttpsError("resource-exhausted", "Could not allocate invite. Try again.");
  }

  const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + COPARENT_INVITE_TTL_MS);
  await ref.set({
    caseId,
    workspaceId: caseId,
    senderUid: uid,
    intendedRecipientEmail: null,
    intendedRecipientPhone: null,
    intendedRecipientUserId: null,
    recipientStatus: "pending",
    createdAt: FieldValue.serverTimestamp(),
    acceptedAt: null,
    expiresAt,
    status: "pending",
    used: false,
    permissions: DEFAULT_COPARENT_INVITE_PERMISSIONS,
  });

  const universalLink = `https://parentledger.org/invite/${token}`;
  const deepLink = `parentledger://invite/${token}`;
  inviteStructuredLog("coparent_invite_created", {
    caseId,
    tokenPrefix: token.slice(0, 8),
    senderUid: uid,
  });
  await db.collection("inviteLogs").add({
    event: "coparent_firestore_invite_created",
    token,
    caseId,
    uid,
    ip,
    timestamp: FieldValue.serverTimestamp(),
  });

  try {
    await commitCaseLedgerEvent({
      caseId,
      type: "invite_sent",
      actorId: uid,
      title: "Co-parent invite sent",
      description: "A secure co-parent invite link was generated.",
      data: { token, kind: "coparent_firestore" },
    });
  } catch (e) {
    console.error("case_events coparent_firestore_invite", e);
  }

  return {
    token,
    universalLink,
    deepLink,
    universalUrl: universalLink,
    appDeepLink: deepLink,
    expiresAt: expiresAt.toDate().toISOString(),
  };
});

/** Accepts a co-parent invite code and links the signed-in user to the inviter's case. */
export const acceptCoparentInviteCode = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const ip = getRequestIp(request as unknown as Record<string, unknown>);
  await enforceRateLimit(`acceptCoparentInviteCode_uid_${uid}`);
  await enforceRateLimit(`acceptCoparentInviteCode_ip_${ip}`);

  const raw = asTrimmedString(request.data?.code, 16);
  const normalized = raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (normalized.length < 6 || normalized.length > 8) {
    throw new HttpsError("invalid-argument", "Enter a valid invite code.");
  }

  const codeRef = db.collection("coparentInviteCodes").doc(normalized);
  const userRef = db.collection("users").doc(uid);

  const preUser = await userRef.get();
  const preRole = String(preUser.data()?.["role"] ?? "parent");
  if (preRole === "attorney") {
    throw new HttpsError("permission-denied", "Attorney accounts cannot join via co-parent invite.");
  }

  const codeSnap = await codeRef.get();
  if (!codeSnap.exists) {
    throw new HttpsError("not-found", "Invalid or expired invite code.");
  }
  const preview = codeSnap.data() as Record<string, unknown>;
  const targetCaseId = preview["caseId"] as string | undefined;
  const inviterUid =
    (preview["inviterId"] ?? preview["inviterUserId"]) as string | undefined;
  if (!targetCaseId || !inviterUid) {
    throw new HttpsError("failed-precondition", "Invalid invite.");
  }

  if (inviterUid === uid) {
    throw new HttpsError("invalid-argument", "You cannot use your own invite code.");
  }

  const existingCaseEarly = preUser.data()?.["caseId"] as string | undefined;
  if (existingCaseEarly === targetCaseId) {
    return { ok: true, alreadyMember: true, caseId: targetCaseId };
  }

  let acceptedCaseIdForLedger = targetCaseId;

  try {
    await db.runTransaction(async (tx) => {
      const cSnap = await tx.get(codeRef);
      if (!cSnap.exists) {
        throw new HttpsError("not-found", "Invalid or expired invite code.");
      }
      const inv = cSnap.data() as Record<string, unknown>;
      if (inv["status"] !== "pending") {
        throw new HttpsError("failed-precondition", "This invite has already been used.");
      }
      const exp = inv["expiresAt"] as admin.firestore.Timestamp | undefined;
      if (exp && exp.toDate().getTime() <= Date.now()) {
        tx.set(
          codeRef,
          { status: "expired", expiredAt: FieldValue.serverTimestamp() },
          { merge: true }
        );
        throw new HttpsError("failed-precondition", "This invite code has expired.");
      }
      const caseId = inv["caseId"] as string;
      const fromUid =
        (inv["inviterId"] ?? inv["inviterUserId"]) as string | undefined;
      if (!caseId || !fromUid || fromUid !== inviterUid || caseId !== targetCaseId) {
        throw new HttpsError("failed-precondition", "Invalid invite.");
      }

      const userSnap = await tx.get(userRef);
      const userData = userSnap.data();
      const existingCaseId = userData?.["caseId"] as string | undefined;

      if (existingCaseId === caseId) {
        return;
      }

      if (existingCaseId != null && existingCaseId !== caseId) {
        tx.update(userRef, {
          mergeFromCaseId: existingCaseId,
        });
      }

      tx.set(
        userRef,
        {
          caseId,
          onboardingStep: "invite_context",
          role: "parent",
          parentType: (userData?.["parentType"] as string | undefined) ?? "mom",
          accessLevel: (userData?.["accessLevel"] as string | undefined) ?? "free",
          subscriptionTier: (userData?.["subscriptionTier"] as string | undefined) ?? "free",
        },
        { merge: true }
      );

      const caseRef = db.collection("cases").doc(caseId);
      const memberRef = caseRef.collection("members").doc(uid);
      const caseMemberRef = db.collection("caseMembers").doc(`${caseId}_${uid}`);

      tx.update(caseRef, {
        [MEMBER_IDS]: FieldValue.arrayUnion(uid),
      });

      tx.set(memberRef, {
        userId: uid,
        joinedAt: FieldValue.serverTimestamp(),
        role: "parent",
      });

      tx.set(
        caseMemberRef,
        {
          caseId,
          userId: uid,
          role: "parent",
          permissions: {
            read: true,
            comment: true,
            export: true,
            write: true,
          },
          linkedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        codeRef,
        {
          status: "accepted",
          acceptedByUserId: uid,
          acceptedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  } catch (err) {
    await db.collection("inviteLogs").add({
      event: "coparent_code_failed",
      code: normalized,
      uid,
      ip,
      error: err instanceof Error ? err.message : String(err),
      timestamp: FieldValue.serverTimestamp(),
    });
    throw err;
  }

  const afterSnap = await codeRef.get();
  const finalStatus = String(afterSnap.data()?.["status"] ?? "");
  if (finalStatus !== "accepted") {
    return { ok: true, alreadyMember: true, caseId: targetCaseId };
  }

  await mergeChildrenIfNeeded(uid);

  try {
    await commitCaseLedgerEvent({
      caseId: acceptedCaseIdForLedger,
      type: "invite_accepted",
      actorId: uid,
      title: "Invite accepted",
      description: "A co-parent joined using an invite code.",
      data: { code: normalized, status: "accepted", kind: "coparent_code" },
    });
  } catch (e) {
    console.error("case_events coparent_code_accept", e);
  }

  await db.collection("inviteLogs").add({
    event: "coparent_code_accepted",
    code: normalized,
    uid,
    ip,
    timestamp: FieldValue.serverTimestamp(),
  });

  return { ok: true, caseId: acceptedCaseIdForLedger };
});

// -----------------------------------------------------------------------------
// Case connections: remove co-parent or revoke attorney (admin writes only)
// -----------------------------------------------------------------------------

async function assertParentCanManageConnections(caseId: string, actorUid: string): Promise<void> {
  await assertCaseMember(caseId, actorUid);
  const userSnap = await db.collection("users").doc(actorUid).get();
  const ud = userSnap.data() ?? {};
  if (String(ud["role"] ?? "parent") === "attorney") {
    throw new HttpsError(
      "permission-denied",
      "Attorney accounts cannot manage case connections."
    );
  }
  const linkId = `${caseId}_${actorUid}`;
  const linkSnap = await db.collection("caseMembers").doc(linkId).get();
  if (linkSnap.exists) {
    const perms = (linkSnap.data()?.["permissions"] ?? {}) as Record<string, unknown>;
    if (perms["write"] === false) {
      throw new HttpsError("permission-denied", "Your access to this case is read-only.");
    }
  }
}

function arrayRemoveUpdatesForUser(caseData: Record<string, unknown>, uid: string): Record<string, unknown> {
  const updates: Record<string, unknown> = {
    [MEMBER_IDS]: FieldValue.arrayRemove(uid),
  };
  const participants = caseData["participants"] as string[] | undefined;
  if (participants?.includes(uid)) {
    updates["participants"] = FieldValue.arrayRemove(uid);
  }
  const parents = caseData["parents"] as string[] | undefined;
  if (parents?.includes(uid)) {
    updates["parents"] = FieldValue.arrayRemove(uid);
  }
  return updates;
}

/** Parent removes the other parent from the shared case; target receives a new solo case. */
export const removeCoParentFromCase = onCall(async (request) => {
  const actorUid = requireAuthUid(request);
  const ip = getRequestIp(request as unknown as Record<string, unknown>);
  await enforceRateLimit(`removeCoParent_uid_${actorUid}`);
  await enforceRateLimit(`removeCoParent_ip_${ip}`);

  const targetUid = asTrimmedString(request.data?.targetUserId, 128);
  if (!targetUid || targetUid === actorUid) {
    throw new HttpsError("invalid-argument", "Invalid target user.");
  }

  const actorDoc = await db.collection("users").doc(actorUid).get();
  const caseId = actorDoc.data()?.["caseId"] as string | undefined;
  if (!caseId) {
    throw new HttpsError("failed-precondition", "No case on account.");
  }

  await assertParentCanManageConnections(caseId, actorUid);

  const targetLinkRef = db.collection("caseMembers").doc(`${caseId}_${targetUid}`);
  const targetLinkSnap = await targetLinkRef.get();
  const targetRole = String(targetLinkSnap.data()?.["role"] ?? "parent");
  if (targetLinkSnap.exists && targetRole === "attorney") {
    throw new HttpsError("invalid-argument", "Use revoke attorney for counsel.");
  }

  const targetUserSnap = await db.collection("users").doc(targetUid).get();
  const targetCaseId = targetUserSnap.data()?.["caseId"] as string | undefined;
  if (targetCaseId !== caseId) {
    throw new HttpsError("failed-precondition", "That person is not linked to this case.");
  }

  const caseRef = db.collection("cases").doc(caseId);
  const newCaseRef = db.collection("cases").doc();
  const newCaseId = newCaseRef.id;

  await db.runTransaction(async (tx) => {
    const caseSnap = await tx.get(caseRef);
    if (!caseSnap.exists) {
      throw new HttpsError("not-found", "Case not found.");
    }
    const caseData = (caseSnap.data() ?? {}) as Record<string, unknown>;
    const mids = (caseData[MEMBER_IDS] as string[] | undefined) ?? [];
    const parents = (caseData["parents"] as string[] | undefined) ?? [];
    const effective = mids.length > 0 ? mids : parents;
    if (!effective.includes(targetUid)) {
      throw new HttpsError("failed-precondition", "That user is not in this case.");
    }

    tx.update(caseRef, arrayRemoveUpdatesForUser(caseData, targetUid));

    const linkSnapTxn = await tx.get(targetLinkRef);
    if (linkSnapTxn.exists) {
      tx.delete(targetLinkRef);
    }

    const memberSub = caseRef.collection("members").doc(targetUid);
    const memberSnap = await tx.get(memberSub);
    if (memberSnap.exists) {
      tx.delete(memberSub);
    }
    const cmSub = caseRef.collection("caseMembers").doc(targetUid);
    const cmSnap = await tx.get(cmSub);
    if (cmSnap.exists) {
      tx.delete(cmSub);
    }

    tx.set(newCaseRef, {
      ownerId: targetUid,
      [MEMBER_IDS]: [targetUid],
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.set(newCaseRef.collection("members").doc(targetUid), {
      userId: targetUid,
      role: "parent",
      joinedAt: FieldValue.serverTimestamp(),
    });

    tx.set(
      db.collection("caseMembers").doc(`${newCaseId}_${targetUid}`),
      {
        caseId: newCaseId,
        userId: targetUid,
        role: "parent",
        permissions: {
          read: true,
          comment: true,
          export: true,
          write: true,
        },
        linkedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(
      db.collection("users").doc(targetUid),
      {
        caseId: newCaseId,
        onboardingStep: "profile_complete",
        role: "parent",
      },
      { merge: true }
    );
  });

  try {
    await commitCaseLedgerEvent({
      caseId,
      type: "member_removed",
      actorId: actorUid,
      title: "Co-parent removed",
      description: "A parent removed the co-parent from this case.",
      data: { removedUserId: targetUid, newCaseIdForRemovedUser: newCaseId },
    });
  } catch (e) {
    console.error("case_events member_removed", e);
  }

  await db.collection("inviteLogs").add({
    event: "coparent_removed",
    caseId,
    actorUid,
    targetUid,
    newCaseId,
    ip,
    timestamp: FieldValue.serverTimestamp(),
  });

  return { ok: true, newCaseIdForRemovedUser: newCaseId };
});

/** Parent revokes attorney read-only access to the case. */
export const revokeAttorneyCaseAccess = onCall(async (request) => {
  const actorUid = requireAuthUid(request);
  const ip = getRequestIp(request as unknown as Record<string, unknown>);
  await enforceRateLimit(`revokeAttorney_uid_${actorUid}`);
  await enforceRateLimit(`revokeAttorney_ip_${ip}`);

  const attorneyUid = asTrimmedString(request.data?.attorneyUserId, 128);
  if (!attorneyUid || attorneyUid === actorUid) {
    throw new HttpsError("invalid-argument", "Invalid attorney user.");
  }

  const actorDoc = await db.collection("users").doc(actorUid).get();
  const caseId = actorDoc.data()?.["caseId"] as string | undefined;
  if (!caseId) {
    throw new HttpsError("failed-precondition", "No case on account.");
  }

  await assertParentCanManageConnections(caseId, actorUid);

  const linkRef = db.collection("caseMembers").doc(`${caseId}_${attorneyUid}`);
  const linkSnap = await linkRef.get();
  if (!linkSnap.exists || String(linkSnap.data()?.["role"] ?? "") !== "attorney") {
    throw new HttpsError("failed-precondition", "That attorney is not linked to this case.");
  }

  const caseRef = db.collection("cases").doc(caseId);

  await db.runTransaction(async (tx) => {
    const caseSnap = await tx.get(caseRef);
    if (!caseSnap.exists) {
      throw new HttpsError("not-found", "Case not found.");
    }
    const caseData = (caseSnap.data() ?? {}) as Record<string, unknown>;
    tx.update(caseRef, arrayRemoveUpdatesForUser(caseData, attorneyUid));

    tx.delete(linkRef);

    const memberSub = caseRef.collection("members").doc(attorneyUid);
    const memberSnap = await tx.get(memberSub);
    if (memberSnap.exists) {
      tx.delete(memberSub);
    }
    const cmSub = caseRef.collection("caseMembers").doc(attorneyUid);
    const cmSnap = await tx.get(cmSub);
    if (cmSnap.exists) {
      tx.delete(cmSub);
    }

    const attorneyCaseLinkRef = db
      .collection("users")
      .doc(attorneyUid)
      .collection("cases")
      .doc(caseId);
    tx.delete(attorneyCaseLinkRef);
  });

  try {
    await commitCaseLedgerEvent({
      caseId,
      type: "attorney_access_revoked",
      actorId: actorUid,
      title: "Attorney access revoked",
      description: "Counsel access to this case was revoked.",
      data: { attorneyUserId: attorneyUid },
    });
  } catch (e) {
    console.error("case_events attorney_revoked", e);
  }

  await db.collection("inviteLogs").add({
    event: "attorney_revoked",
    caseId,
    actorUid,
    attorneyUid,
    ip,
    timestamp: FieldValue.serverTimestamp(),
  });

  return { ok: true };
});
