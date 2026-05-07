/**
 * Unified in-app assistant: app help, case-aware analysis, and neutral guidance.
 * Intent is resolved server-side; clients only receive the reply text.
 */
import { GoogleGenerativeAI, SchemaType } from "@google/generative-ai";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { config } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { requireAuthUid } from "./callable_auth";
import { assertCaseMember } from "./case_event_ledger";

const MODEL_ID = "gemini-1.5-pro";
const MAX_QUESTION_CHARS = 2000;
const MAX_CASE_PACK_CHARS = 85_000;
const PRIMARY_THREAD_ID = "primary";

const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 40;

function getGeminiKey(): string {
  const raw = config() as { gemini?: { key?: string } };
  const key = raw.gemini?.key;
  if (!key || typeof key !== "string" || !key.trim()) {
    throw new HttpsError(
      "failed-precondition",
      "Gemini API key is not configured. Set gemini.key via Firebase functions config."
    );
  }
  return key.trim();
}

function clampQuestion(input: unknown): string {
  const s = typeof input === "string" ? input : String(input ?? "");
  const t = s.trim();
  if (!t) {
    throw new HttpsError("invalid-argument", "question is required.");
  }
  if (t.length > MAX_QUESTION_CHARS) {
    throw new HttpsError(
      "invalid-argument",
      `question is too long (max ${MAX_QUESTION_CHARS} characters).`
    );
  }
  return t;
}

function asOptionalCaseId(input: unknown): string | null {
  if (input == null) return null;
  const s = String(input).trim();
  if (!s) return null;
  if (s.length > 128) {
    throw new HttpsError("invalid-argument", "caseId is invalid.");
  }
  return s;
}

function isoFromFirestoreTime(value: unknown): string {
  if (!value || typeof value !== "object") return "?";
  const ts = value as { toDate?: () => Date };
  if (typeof ts.toDate !== "function") return "?";
  try {
    return ts.toDate().toISOString();
  } catch {
    return "?";
  }
}

function eventMillis(value: unknown): number {
  if (!value || typeof value !== "object") return 0;
  const v = value as { seconds?: number; nanoseconds?: number; toMillis?: () => number };
  if (typeof v.toMillis === "function") {
    try {
      return v.toMillis();
    } catch {
      /* empty */
    }
  }
  if (typeof v.seconds === "number") {
    const ns = typeof v.nanoseconds === "number" ? v.nanoseconds : 0;
    return v.seconds * 1000 + Math.floor(ns / 1e6);
  }
  return 0;
}

function trimPack(text: string): string {
  if (text.length <= MAX_CASE_PACK_CHARS) return text;
  return `${text.slice(0, MAX_CASE_PACK_CHARS)}\n\n[Trimmed — case snapshot was very long.]`;
}

async function enforceAssistantRate(uid: string): Promise<void> {
  const db = admin.firestore();
  const now = Date.now();
  const ref = db.collection("rateLimits").doc(`smartAssistant_${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() as Record<string, unknown> | undefined;
    const windowStart = Number(data?.["windowStartMs"] ?? 0);
    const attempts = Number(data?.["attempts"] ?? 0);
    const inWindow = now - windowStart < RATE_WINDOW_MS;
    const nextAttempts = inWindow ? attempts + 1 : 1;
    if (inWindow && attempts >= RATE_MAX) {
      throw new HttpsError("resource-exhausted", "Too many assistant requests. Try again shortly.");
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

function parseJsonReply(text: string): string {
  const trimmed = text.trim();
  try {
    const o = JSON.parse(trimmed) as { reply?: unknown };
    const r = typeof o.reply === "string" ? o.reply.trim() : "";
    if (r) return r;
  } catch {
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        const o = JSON.parse(trimmed.slice(start, end + 1)) as { reply?: unknown };
        const r = typeof o.reply === "string" ? o.reply.trim() : "";
        if (r) return r;
      } catch {
        // fall through
      }
    }
  }
  throw new HttpsError("internal", "Assistant: could not parse model response.");
}

async function loadCaseSnapshot(caseId: string, uid: string): Promise<string> {
  await assertCaseMember(caseId, uid);
  const db = admin.firestore();

  const msgSnap = await db
    .collection("cases")
    .doc(caseId)
    .collection("conversations")
    .doc(PRIMARY_THREAD_ID)
    .collection("messages")
    .orderBy("createdAt", "desc")
    .limit(80)
    .get();

  const msgLines: string[] = [];
  const msgDocs = [...msgSnap.docs].reverse();
  for (const d of msgDocs) {
    const m = d.data() as Record<string, unknown>;
    const body = String(m["text"] ?? "").trim().replace(/\s+/g, " ");
    if (!body) continue;
    const sender = String(m["senderId"] ?? "");
    const flag = m["legalFlag"] != null ? ` flag=${String(m["legalFlag"])}` : "";
    const t = isoFromFirestoreTime(m["createdAt"]);
    msgLines.push(`[${t}] sender=${sender}${flag} — ${body}`);
  }

  const evSnap = await db
    .collection("case_events")
    .where("caseId", "==", caseId)
    .limit(200)
    .get();

  type EvRow = { createdMs: number; line: string };
  const evRows: EvRow[] = [];
  for (const d of evSnap.docs) {
    const m = d.data() as Record<string, unknown>;
    const type = String(m["type"] ?? "");
    const createdAt = m["createdAt"] ?? m["timestamp"];
    const t = isoFromFirestoreTime(createdAt);
    const ms = eventMillis(createdAt);
    const title = String(m["title"] ?? "").trim();
    const desc = String(m["description"] ?? "").trim();
    const actor = String(m["actorId"] ?? m["createdBy"] ?? "");

    let line = `[${t}] type=${type} actor=${actor}`;
    if (title) line += ` — ${title}`;
    if (desc) line += ` — ${desc}`;

    const meta = (m["metadata"] ?? m["data"]) as Record<string, unknown> | undefined;
    if (meta && typeof meta === "object") {
      const keys = ["expenseAmount", "status", "checkInLabel", "locationLabel"].filter((k) => meta[k] != null);
      if (keys.length) {
        line += ` (meta: ${keys.map((k) => `${k}=${String(meta[k])}`).join(", ")})`;
      }
    }
    evRows.push({ createdMs: ms, line });
  }

  evRows.sort((a, b) => a.createdMs - b.createdMs);
  const timelineSlice = evRows.map((r) => r.line);
  const lastEv = timelineSlice.length > 60 ? timelineSlice.slice(timelineSlice.length - 60) : timelineSlice;

  const parts: string[] = [];
  parts.push("=== MESSAGE LOG (primary thread, oldest → newest within window) ===");
  parts.push(msgLines.length ? msgLines.join("\n") : "(No messages in this window.)");
  parts.push("");
  parts.push("=== TIMELINE / LEDGER (recent subset, chronological) ===");
  parts.push(lastEv.length ? lastEv.join("\n") : "(No timeline events in this window.)");

  return trimPack(parts.join("\n"));
}

export const smartAssistant = onCall(async (request) => {
  const uid = requireAuthUid(request);
  await enforceAssistantRate(uid);

  const question = clampQuestion(request.data?.question);
  const caseId = asOptionalCaseId(request.data?.caseId);

  let casePack = "";
  if (caseId) {
    try {
      casePack = await loadCaseSnapshot(caseId, uid);
    } catch (e) {
      if (e instanceof HttpsError) {
        throw e;
      }
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Assistant: failed to load case data: ${msg}`);
    }
  } else {
    casePack = "(No case linked in this session — only general app help or non-record-specific guidance is possible.)";
  }

  const genAI = new GoogleGenerativeAI(getGeminiKey());
  const model = genAI.getGenerativeModel({
    model: MODEL_ID,
    generationConfig: {
      temperature: 0.25,
      maxOutputTokens: 2048,
      responseMimeType: "application/json",
      responseSchema: {
        type: SchemaType.OBJECT,
        properties: {
          reply: { type: SchemaType.STRING },
        },
        required: ["reply"],
      },
    },
  });

  const system = [
    "You are ParentLedger's in-app assistant. Follow exactly one response style per answer (do not name or label these modes in the reply):",
    "",
    "1) APP HELP — User asks how to use the app (exporting, invites, messages, timeline, profile, subscription, etc.).",
    "   Give short numbered steps. Reference real areas of the app: Messages (case message thread with export options), Timeline, Expenses, Exchanges / check-ins, Profile & invites, Help & support, Case insights / compliance views where relevant.",
    "   Do not invent features that are not typical co-parent custody record apps.",
    "",
    "2) CASE INTELLIGENCE — User asks about their case records: messages, exchanges, timeline, violations, flags, patterns.",
    "   Use ONLY the CASE DATA block as the source of truth. If the block says no data, say so.",
    "   Structure the answer with these Markdown sections in this order:",
    "   ## Summary",
    "   ## Key findings",
    "   ## Flags and issues",
    "   Use bullet lists under Key findings and Flags and issues when helpful. Be factual; no legal conclusions.",
    "",
    "3) GUIDANCE — User asks what they should do, how to respond, or for practical next steps.",
    "   Be neutral and practical. Prefer phrases like: \"Based on your records...\" and \"You may want to consider...\".",
    "   Do not give legal advice or claim what a court will do. Suggest documentation and calm communication when appropriate.",
    "   If CASE DATA is provided, ground suggestions in it; otherwise keep guidance general.",
    "",
    "Routing rules (pick one style; if unclear, prefer CASE INTELLIGENCE when CASE DATA is rich, else APP HELP for how-to questions):",
    "- How-to / where in the app → APP HELP",
    "- Analyzing their thread or timeline → CASE INTELLIGENCE",
    "- \"What should I do\" / strategy → GUIDANCE",
    "",
    "Always include a brief reminder that you are not a lawyer and this is not legal advice when the topic touches disputes, custody, or court.",
    "",
    `CASE DATA:\n${casePack}`,
    "",
    `USER QUESTION:\n${question}`,
    "",
    'Return JSON shaped as {"reply":"markdown string only — your full answer"}',
  ].join("\n");

  let raw: string;
  try {
    const res = await model.generateContent(system);
    raw = res.response.text();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new HttpsError("internal", `Assistant request failed: ${msg}`);
  }

  const reply = parseJsonReply(raw);
  if (!reply.trim()) {
    throw new HttpsError("internal", "Assistant returned an empty reply.");
  }

  return { text: reply.trim() };
});
