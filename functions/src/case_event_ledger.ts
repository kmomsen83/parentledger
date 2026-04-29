/**
 * Tamper-resistant append-only ledger in `case_events` with SHA-256 chain.
 * Hash input (concatenated, UTF-8): caseId + type + actorId + timestampMillis + stableJson(data) + previousHash
 */
import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { requireAuthUid } from "./callable_auth";

/** Must not run at module load — `index.ts` initializes the default app first. */
function firestore() {
  return admin.firestore();
}

export const GENESIS_PREVIOUS_HASH = "";

/** Ordered JSON.stringify with sorted keys (objects) and stable arrays. */
export function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return "[" + value.map((v) => stableStringify(v)).join(",") + "]";
  }
  const o = value as Record<string, unknown>;
  const keys = Object.keys(o).sort();
  return "{" + keys.map((k) => JSON.stringify(k) + ":" + stableStringify(o[k])).join(",") + "}";
}

export function computeLedgerHash(
  caseId: string,
  type: string,
  actorId: string,
  timestampMillis: number,
  data: Record<string, unknown>,
  previousHash: string
): string {
  const ts = String(timestampMillis);
  const dataStr = stableStringify(data);
  const input = `${caseId}${type}${actorId}${ts}${dataStr}${previousHash}`;
  return crypto.createHash("sha256").update(input, "utf8").digest("hex");
}

export const LEDGER_EVENT_TYPES = new Set([
  "message_sent",
  "expense_created",
  "expense_approved",
  "expense_denied",
  "schedule_created",
  "schedule_updated",
  "invite_sent",
  "invite_accepted",
  "status_change",
  "proposal_updated",
  "proposal_accepted",
  "proposal_rejected",
  "proposal_finalized",
]);

/**
 * Matches Firestore rules participant logic: memberIds / legacy parents / participants,
 * `caseMembers/{caseId_uid}`, or `users/{uid}.caseId`.
 */
export async function assertCaseMember(caseId: string, uid: string): Promise<void> {
  const caseSnap = await firestore().collection("cases").doc(caseId).get();
  if (!caseSnap.exists) {
    throw new HttpsError("not-found", "Case not found.");
  }
  const data = caseSnap.data() as Record<string, unknown> | undefined;
  const memberIds = (data?.memberIds as string[] | undefined) ?? [];
  const parents = (data?.parents as string[] | undefined) ?? [];
  const participantsExplicit = (data?.participants as string[] | undefined) ?? [];
  const coMembers = memberIds.length > 0 ? memberIds : parents;
  const effectiveParticipants = participantsExplicit.length > 0 ? participantsExplicit : coMembers;

  if (effectiveParticipants.includes(uid)) {
    return;
  }

  const linkSnap = await firestore().collection("caseMembers").doc(`${caseId}_${uid}`).get();
  if (linkSnap.exists) {
    return;
  }

  const userSnap = await firestore().collection("users").doc(uid).get();
  const userCaseId = userSnap.data()?.caseId as string | undefined;
  if (userCaseId === caseId) {
    return;
  }

  throw new HttpsError("permission-denied", "Not a case member.");
}

const META = "case_events_meta";

export interface CommitLedgerParams {
  caseId: string;
  type: string;
  actorId: string;
  actorName?: string;
  title: string;
  description: string;
  data?: Record<string, unknown>;
}

/**
 * Append one ledger row + advance chain tip (serialized via transaction on meta doc).
 */
export async function commitCaseLedgerEvent(
  params: CommitLedgerParams
): Promise<{ eventId: string; hash: string; previousHash: string }> {
  const { caseId, type, actorId, title, description } = params;
  const data = params.data ?? {};
  const actorName = params.actorName ?? "";

  if (!LEDGER_EVENT_TYPES.has(type)) {
    throw new HttpsError("invalid-argument", `Invalid event type: ${type}`);
  }
  if (!caseId || !actorId) {
    throw new HttpsError("invalid-argument", "caseId and actorId are required.");
  }

  const metaRef = firestore().collection(META).doc(caseId);
  const eventsCol = firestore().collection("case_events");

  return firestore().runTransaction(async (tx) => {
    const metaSnap = await tx.get(metaRef);
    const previousHash =
      (metaSnap.exists ? (metaSnap.data()?.tipHash as string | undefined) : undefined) ??
      GENESIS_PREVIOUS_HASH;

    const timestampMillis = admin.firestore.Timestamp.now().toMillis();
    const hash = computeLedgerHash(caseId, type, actorId, timestampMillis, data, previousHash);

    const eventRef = eventsCol.doc();
    tx.set(eventRef, {
      caseId,
      type,
      actorId,
      actorName,
      title,
      description,
      data,
      metadata: data,
      timestamp: admin.firestore.Timestamp.fromMillis(timestampMillis),
      timestampMillis,
      hash,
      previousHash,
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.set(
      metaRef,
      {
        caseId,
        tipHash: hash,
        lastEventId: eventRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { eventId: eventRef.id, hash, previousHash };
  });
}

/** Client-callable append (actor must match auth). */
export const logCaseEvent = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const caseId = String(request.data?.caseId ?? "").trim();
  const type = String(request.data?.type ?? "").trim();
  const actorId = String(request.data?.actorId ?? "").trim();
  const title = String(request.data?.title ?? "").slice(0, 500);
  const description = String(request.data?.description ?? "").slice(0, 8000);
  const actorName = String(request.data?.actorName ?? "").slice(0, 200);
  const rawData = request.data?.data;
  const data =
    rawData != null && typeof rawData === "object" && !Array.isArray(rawData)
      ? (rawData as Record<string, unknown>)
      : {};

  if (!caseId || !type || !actorId) {
    throw new HttpsError("invalid-argument", "caseId, type, and actorId are required.");
  }
  if (actorId !== uid) {
    throw new HttpsError("permission-denied", "actorId must match the signed-in user.");
  }

  await assertCaseMember(caseId, uid);

  return commitCaseLedgerEvent({
    caseId,
    type,
    actorId,
    actorName: actorName || undefined,
    title: title || type,
    description,
    data,
  });
});

export interface VerifyChainResult {
  valid: boolean;
  message?: string;
  eventCount: number;
  expectedHash?: string;
  storedHash?: string;
  badEventId?: string;
}

const VERIFY_PAGE_SIZE = 400;

/** Recompute chain for all rows of [caseId] in timestamp order (paginated for large cases). */
export async function verifyCaseEventChainInternal(caseId: string): Promise<VerifyChainResult> {
  let previousHash = GENESIS_PREVIOUS_HASH;
  let totalCount = 0;
  let lastMillis: number | null = null;
  let lastDocId: string | null = null;

  while (true) {
    let q = firestore()
      .collection("case_events")
      .where("caseId", "==", caseId)
      .orderBy("timestampMillis", "asc")
      .orderBy(FieldPath.documentId(), "asc")
      .limit(VERIFY_PAGE_SIZE);

    if (lastMillis !== null && lastDocId !== null) {
      q = q.startAfter(lastMillis, lastDocId);
    }

    const snap = await q.get();
    if (snap.empty) {
      break;
    }

    for (const doc of snap.docs) {
      const m = doc.data();
      totalCount++;
      const cid = String(m.caseId ?? "");
      const typ = String(m.type ?? "");
      const aid = String(m.actorId ?? "");
      const tsm = m.timestampMillis;
      const millis = typeof tsm === "number" ? tsm : 0;
      const dataRaw = m.data ?? m.metadata ?? {};
      const data =
        dataRaw != null && typeof dataRaw === "object" && !Array.isArray(dataRaw)
          ? (dataRaw as Record<string, unknown>)
          : {};
      const storedHash = String(m.hash ?? "");
      const prevStored = String(m.previousHash ?? "");

      if (cid !== caseId) {
        return {
          valid: false,
          message: "Event caseId mismatch.",
          eventCount: totalCount,
          badEventId: doc.id,
        };
      }
      if (prevStored !== previousHash) {
        return {
          valid: false,
          message: "previousHash does not match chain tip (possible tampering).",
          eventCount: totalCount,
          expectedHash: previousHash,
          storedHash: prevStored,
          badEventId: doc.id,
        };
      }

      const expected = computeLedgerHash(cid, typ, aid, millis, data, previousHash);
      if (expected !== storedHash) {
        return {
          valid: false,
          message: "Hash mismatch for ledger event (possible tampering).",
          eventCount: totalCount,
          expectedHash: expected,
          storedHash: storedHash,
          badEventId: doc.id,
        };
      }
      previousHash = expected;
      lastMillis = millis;
      lastDocId = doc.id;
    }

    if (snap.size < VERIFY_PAGE_SIZE) {
      break;
    }
  }

  return { valid: true, eventCount: totalCount };
}

export const verifyCaseEventChain = onCall(async (request) => {
  const uid = requireAuthUid(request);
  const caseId = String(request.data?.caseId ?? "").trim();
  if (!caseId) {
    throw new HttpsError("invalid-argument", "caseId is required.");
  }
  await assertCaseMember(caseId, uid);
  return verifyCaseEventChainInternal(caseId);
});
