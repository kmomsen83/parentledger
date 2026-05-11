/**
 * RevenueCat → Firestore server-authoritative billing (HTTPS webhook, Functions v2).
 * @see https://www.revenuecat.com/docs/webhooks
 */
import { db } from "./firebase_init";
import { FieldValue } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";

/** Must match Flutter [RevenueCatService.proEntitlementId]. */
export const PARENTLEDGER_PRO_ENTITLEMENT = "ParentLedger Pro";

const PARENT_PRO_FLAGS = {
  messagingFull: true,
  exportsFull: true,
  reportsFull: true,
  aiToolsFull: true,
  timelineHistoryFull: true,
};

const PARENT_FREE_FLAGS = {
  messagingFull: false,
  exportsFull: false,
  reportsFull: false,
  aiToolsFull: false,
  timelineHistoryFull: false,
};

const RC_HANDLED_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "CANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
  "PRODUCT_CHANGE",
  "TRANSFER",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_PAUSED",
]);

function rcLog(
  level: "info" | "warn" | "error",
  message: string,
  data: Record<string, unknown> = {}
): void {
  const line = JSON.stringify({
    component: "revenuecat_webhook",
    level,
    message,
    ts: new Date().toISOString(),
    ...data,
  });
  if (level === "error") {
    console.error(line);
  } else if (level === "warn") {
    console.warn(line);
  } else {
    console.log(line);
  }
}

function getBearerToken(authorizationHeader: string | undefined): string {
  const raw = String(authorizationHeader ?? "").trim();
  if (!raw.toLowerCase().startsWith("bearer ")) {
    return "";
  }
  return raw.slice(7).trim();
}

function parseJsonBody(raw: unknown): Record<string, unknown> | null {
  if (raw == null) {
    return null;
  }
  if (typeof raw === "string") {
    try {
      return JSON.parse(raw) as Record<string, unknown>;
    } catch {
      return null;
    }
  }
  if (typeof raw === "object") {
    return raw as Record<string, unknown>;
  }
  return null;
}

function asEventRecord(body: Record<string, unknown>): Record<string, unknown> | null {
  const ev = body["event"];
  if (ev && typeof ev === "object") {
    return ev as Record<string, unknown>;
  }
  if (body["type"] && body["app_user_id"]) {
    return body;
  }
  return null;
}

function includesProEntitlement(event: Record<string, unknown>): boolean {
  const ids = event["entitlement_ids"] as unknown;
  if (Array.isArray(ids) && ids.includes(PARENTLEDGER_PRO_ENTITLEMENT)) {
    return true;
  }
  if (event["entitlement_id"] === PARENTLEDGER_PRO_ENTITLEMENT) {
    return true;
  }
  const ent = event["entitlements"] as Record<string, unknown> | undefined;
  if (ent?.[PARENTLEDGER_PRO_ENTITLEMENT]) {
    return true;
  }
  return false;
}

function expirationMsFuture(event: Record<string, unknown>): boolean | null {
  const ms = event["expiration_at_ms"];
  if (typeof ms !== "number" || !Number.isFinite(ms)) {
    return null;
  }
  return ms > Date.now();
}

function normalizedRole(data: Record<string, unknown> | undefined): string {
  const r = String(data?.["role"] ?? "parent").trim().toLowerCase();
  return r === "attorney" ? "attorney" : "parent";
}

function isLifetimeAccess(data: Record<string, unknown> | undefined): boolean {
  return String(data?.["accessLevel"] ?? "").trim().toLowerCase() === "lifetime";
}

/**
 * CANCELLATION: inactive immediately (per product spec). EXPIRATION: inactive.
 * BILLING_ISSUE: flag billing_issue while entitlement still in a valid window.
 */
function computeBillingState(
  eventType: string,
  event: Record<string, unknown>
): "active" | "inactive" | "billing_issue" {
  const hasPro = includesProEntitlement(event);
  const future = expirationMsFuture(event);

  if (
    eventType === "EXPIRATION" ||
    eventType === "CANCELLATION" ||
    eventType === "SUBSCRIPTION_PAUSED"
  ) {
    return "inactive";
  }

  if (eventType === "BILLING_ISSUE") {
    if (hasPro && future !== false) {
      return "billing_issue";
    }
    return "inactive";
  }

  if (!hasPro) {
    return "inactive";
  }
  if (future === false) {
    return "inactive";
  }
  if (future === true) {
    return "active";
  }

  const optimisticTypes = new Set([
    "INITIAL_PURCHASE",
    "RENEWAL",
    "UNCANCELLATION",
    "PRODUCT_CHANGE",
    "TRANSFER",
    "NON_RENEWING_PURCHASE",
  ]);
  if (optimisticTypes.has(eventType)) {
    return "active";
  }
  return "inactive";
}

async function applyFirestoreForUser(
  uid: string,
  state: "active" | "inactive" | "billing_issue",
  eventType: string,
  eventId: string
): Promise<void> {
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) {
    rcLog("warn", "user doc missing; skipping billing write", { uid, eventType, eventId });
    return;
  }
  const prev = (snap.data() ?? {}) as Record<string, unknown>;

  if (normalizedRole(prev) === "attorney") {
    rcLog("info", "skip billing mutation for attorney", { uid, eventType, eventId });
    return;
  }

  if (isLifetimeAccess(prev)) {
    rcLog("info", "skip downgrade for lifetime access user", { uid, eventType, eventId });
    return;
  }

  if (state === "active" || state === "billing_issue") {
    const patch: Record<string, unknown> = {
      isPremium: true,
      subscriptionTier: "pro",
      premiumSource: "revenuecat",
      premiumUpdatedAt: FieldValue.serverTimestamp(),
      subscriptionStatus: state === "billing_issue" ? "billing_issue" : "active",
      entitlementId: PARENTLEDGER_PRO_ENTITLEMENT,
      accessLevel: "subscription",
      entitlementFlags: PARENT_PRO_FLAGS,
      rcLastEventType: eventType,
      rcLastEventId: eventId,
    };
    await userRef.set(patch, { merge: true });
    rcLog("info", "billing activated", { uid, eventType, eventId, state });
    return;
  }

  const inactivePatch: Record<string, unknown> = {
    isPremium: false,
    subscriptionTier: "free",
    premiumUpdatedAt: FieldValue.serverTimestamp(),
    subscriptionStatus:
      eventType === "CANCELLATION" ? "cancelled" : eventType === "EXPIRATION" ? "expired" : "none",
    premiumSource: FieldValue.delete(),
    entitlementId: FieldValue.delete(),
    accessLevel: "free",
    entitlementFlags: PARENT_FREE_FLAGS,
    rcLastEventType: eventType,
    rcLastEventId: eventId,
  };
  await userRef.set(inactivePatch, { merge: true });
  rcLog("info", "billing deactivated", { uid, eventType, eventId });
}

export const revenueCatWebhook = onRequest(
  {
    region: "us-central1",
    cors: false,
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }

    const expectedSecret =
      process.env.REVENUECAT_WEBHOOK_BEARER?.trim() ?? "parentledger_super_secret_2026";
    const token = getBearerToken(req.get("authorization"));
    if (!token || token !== expectedSecret) {
      rcLog("warn", "unauthorized webhook attempt", {
        hasAuthHeader: Boolean(req.get("authorization")),
      });
      res.status(401).json({ error: "unauthorized" });
      return;
    }

    const body = parseJsonBody(req.body);
    if (!body) {
      res.status(400).json({ error: "invalid_json" });
      return;
    }

    const event = asEventRecord(body);
    if (!event) {
      rcLog("warn", "missing event payload", {});
      res.status(400).json({ error: "missing_event" });
      return;
    }

    const eventType = String(event["type"] ?? "").trim().toUpperCase();
    const appUserId = String(event["app_user_id"] ?? "").trim();
    const eventId = String(event["id"] ?? "").trim() || "unknown";

    if (!appUserId) {
      rcLog("warn", "missing app_user_id", { eventType, eventId });
      res.status(400).json({ error: "missing_app_user_id" });
      return;
    }

    if (eventType && !RC_HANDLED_TYPES.has(eventType)) {
      rcLog("info", "ignored event type", { eventType, appUserId, eventId });
      res.status(200).json({ ok: true, ignored: true, eventType });
      return;
    }

    try {
      const billing = computeBillingState(eventType, event);
      await applyFirestoreForUser(appUserId, billing, eventType, eventId);
      res.status(200).json({ ok: true, uid: appUserId, eventType, billing });
    } catch (e) {
      rcLog("error", "webhook handler failed", {
        appUserId,
        eventType,
        eventId,
        err: e instanceof Error ? e.message : String(e),
      });
      res.status(500).json({ error: "internal" });
    }
  }
);
