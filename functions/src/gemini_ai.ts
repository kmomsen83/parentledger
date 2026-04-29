/**
 * Gemini-backed AI callables — API key from legacy runtime config:
 * `firebase functions:config:set gemini.key="YOUR_KEY"`
 */
import { GoogleGenerativeAI, SchemaType } from "@google/generative-ai";
import { config } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { requireAuthUid } from "./callable_auth";

const MODEL_ID = "gemini-1.5-pro";
const MAX_INPUT_CHARS = 100_000;

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

function clampText(input: unknown, label: string): string {
  const s = typeof input === "string" ? input : String(input ?? "");
  const t = s.trim();
  if (!t) {
    throw new HttpsError("invalid-argument", `${label} is required.`);
  }
  if (t.length > MAX_INPUT_CHARS) {
    throw new HttpsError(
      "invalid-argument",
      `${label} is too long (max ${MAX_INPUT_CHARS} characters).`
    );
  }
  return t;
}

/** Accepts a single string or an array of lines (Flutter sends `List<String>`). */
function normalizeMessagesField(input: unknown, label: string): string {
  if (Array.isArray(input)) {
    const lines = input
      .map((x) => (typeof x === "string" ? x : String(x ?? "")).trim())
      .filter((s) => s.length > 0);
    const joined = lines.join("\n");
    if (!joined) {
      throw new HttpsError(
        "invalid-argument",
        `${label} must contain at least one non-empty message line.`
      );
    }
    if (joined.length > MAX_INPUT_CHARS) {
      throw new HttpsError(
        "invalid-argument",
        `${label} is too long (max ${MAX_INPUT_CHARS} characters).`
      );
    }
    return joined;
  }
  return clampText(input, label);
}

function parseJsonObject<T>(text: string, context: string): T {
  const trimmed = text.trim();
  try {
    return JSON.parse(trimmed) as T;
  } catch {
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(trimmed.slice(start, end + 1)) as T;
      } catch {
        // fall through
      }
    }
    throw new HttpsError("internal", `${context}: could not parse model JSON.`);
  }
}

export const generateCourtSummary = onCall(async (request) => {
  const uid = requireAuthUid(request);
  void uid;
  const messages = normalizeMessagesField(request.data?.messages, "messages");

  const genAI = new GoogleGenerativeAI(getGeminiKey());
  const model = genAI.getGenerativeModel({
    model: MODEL_ID,
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 768,
      responseMimeType: "application/json",
      responseSchema: {
        type: SchemaType.OBJECT,
        properties: {
          summary: { type: SchemaType.STRING },
        },
        required: ["summary"],
      },
    },
  });

  const prompt =
    "Summarize this co-parenting conversation for court. Be factual, neutral, chronological. No opinions.\n" +
    "Output at most 5 bullet points (each starting with '- '). No paragraphs beyond those bullets.\n\n" +
    "CONVERSATION:\n" +
    messages;

  let text: string;
  try {
    const res = await model.generateContent(prompt);
    text = res.response.text();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new HttpsError("internal", `Court summary generation failed: ${msg}`);
  }

  const parsed = parseJsonObject<{ summary?: string }>(text, "Court summary");
  const summary = typeof parsed.summary === "string" ? parsed.summary.trim() : "";
  if (!summary) {
    throw new HttpsError("internal", "Court summary: empty summary in model output.");
  }
  return { summary };
});

export const analyzeFairness = onCall(async (request) => {
  const uid = requireAuthUid(request);
  void uid;
  const proposal = clampText(request.data?.proposal, "proposal");

  const genAI = new GoogleGenerativeAI(getGeminiKey());
  const model = genAI.getGenerativeModel({
    model: MODEL_ID,
    generationConfig: {
      temperature: 0.15,
      maxOutputTokens: 512,
      responseMimeType: "application/json",
      responseSchema: {
        type: SchemaType.OBJECT,
        properties: {
          score: { type: SchemaType.NUMBER },
          result: { type: SchemaType.STRING, enum: ["fair", "unfair", "balanced"] },
          reasoning: { type: SchemaType.STRING },
        },
        required: ["score", "result", "reasoning"],
      },
    },
  });

  const prompt =
    "Analyze this custody or scheduling proposal for fairness.\n" +
    "Return JSON with:\n" +
    "- score: number from 0 (very unfair) to 100 (very fair)\n" +
    "- result: exactly one of: fair | unfair | balanced\n" +
    "- reasoning: exactly one concise sentence (no second sentence)\n\n" +
    "PROPOSAL:\n" +
    proposal;

  let text: string;
  try {
    const res = await model.generateContent(prompt);
    text = res.response.text();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new HttpsError("internal", `Fairness analysis failed: ${msg}`);
  }

  const parsed = parseJsonObject<{
    score?: unknown;
    result?: string;
    reasoning?: string;
  }>(text, "Fairness analysis");

  const scoreNum = typeof parsed.score === "number" ? parsed.score : Number(parsed.score);
  if (!Number.isFinite(scoreNum) || scoreNum < 0 || scoreNum > 100) {
    throw new HttpsError("internal", "Fairness analysis: invalid score.");
  }

  const resultRaw = (parsed.result ?? "").toString().trim().toLowerCase();
  if (resultRaw !== "fair" && resultRaw !== "unfair" && resultRaw !== "balanced") {
    throw new HttpsError("internal", "Fairness analysis: invalid result label.");
  }

  const reasoning = typeof parsed.reasoning === "string" ? parsed.reasoning.trim() : "";
  if (!reasoning) {
    throw new HttpsError("internal", "Fairness analysis: empty reasoning.");
  }

  return {
    score: scoreNum,
    result: resultRaw,
    reasoning,
  };
});

/** Single-message tone / flag for legal logging (no client-side keyword rules). */
export const classifyCoParentMessage = onCall(async (request) => {
  const uid = requireAuthUid(request);
  void uid;
  const text = clampText(request.data?.text, "text");

  const genAI = new GoogleGenerativeAI(getGeminiKey());
  const model = genAI.getGenerativeModel({
    model: MODEL_ID,
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 1024,
      responseMimeType: "application/json",
      responseSchema: {
        type: SchemaType.OBJECT,
        properties: {
          legalFlag: {
            type: SchemaType.STRING,
            enum: ["none", "hostile", "non-compliant"],
          },
          warnBeforeSend: { type: SchemaType.BOOLEAN },
          neutralRewrite: { type: SchemaType.STRING },
        },
        required: ["legalFlag", "warnBeforeSend", "neutralRewrite"],
      },
    },
  });

  const prompt =
    "You review a single co-parent message for a court-grade communication log.\n" +
    "Return JSON only:\n" +
    "- legalFlag: none | hostile | non-compliant\n" +
    "  (hostile = personal attacks, insults, threats; non-compliant = refusal to follow schedule/court/order language without personal attack; none = neither.)\n" +
    "- warnBeforeSend: true if the sender should pause before sending due to escalation risk.\n" +
    "- neutralRewrite: one short calm, factual alternative the sender could use instead; use empty string if warnBeforeSend is false.\n\n" +
    "MESSAGE:\n" +
    text;

  let rawText: string;
  try {
    const res = await model.generateContent(prompt);
    rawText = res.response.text();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new HttpsError("internal", `Message classification failed: ${msg}`);
  }

  const parsed = parseJsonObject<{
    legalFlag?: string;
    warnBeforeSend?: unknown;
    neutralRewrite?: string;
  }>(rawText, "Message classification");

  const flagRaw = (parsed.legalFlag ?? "none").toString().trim().toLowerCase();
  if (flagRaw !== "none" && flagRaw !== "hostile" && flagRaw !== "non-compliant") {
    throw new HttpsError("internal", "Classification: invalid legalFlag.");
  }

  const warn =
    parsed.warnBeforeSend === true ||
    parsed.warnBeforeSend === "true" ||
    parsed.warnBeforeSend === 1;

  const neutral =
    typeof parsed.neutralRewrite === "string" ? parsed.neutralRewrite.trim() : "";

  const legalFlagOut = flagRaw === "none" ? null : flagRaw;

  return {
    legalFlag: legalFlagOut,
    warnBeforeSend: warn,
    neutralRewrite: neutral.length > 0 ? neutral : null,
  };
});

type ViolationRow = { type: string; description: string };

export const detectViolations = onCall(async (request) => {
  const uid = requireAuthUid(request);
  void uid;
  const messages = normalizeMessagesField(request.data?.messages, "messages");

  const genAI = new GoogleGenerativeAI(getGeminiKey());
  const model = genAI.getGenerativeModel({
    model: MODEL_ID,
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 8192,
      responseMimeType: "application/json",
      responseSchema: {
        type: SchemaType.OBJECT,
        properties: {
          violations: {
            type: SchemaType.ARRAY,
            items: {
              type: SchemaType.OBJECT,
              properties: {
                type: { type: SchemaType.STRING },
                description: { type: SchemaType.STRING },
              },
              required: ["type", "description"],
            },
          },
        },
        required: ["violations"],
      },
    },
  });

  const prompt =
    "Analyze the conversation and identify:\n" +
    "- missed obligations\n" +
    "- lateness\n" +
    "- aggression\n" +
    "- non-compliance\n\n" +
    "Return JSON object with key violations: array of { type, description }.\n" +
    "Use concise type labels. If none found, return an empty violations array.\n\n" +
    "CONVERSATION:\n" +
    messages;

  let text: string;
  try {
    const res = await model.generateContent(prompt);
    text = res.response.text();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new HttpsError("internal", `Violation detection failed: ${msg}`);
  }

  const parsed = parseJsonObject<{ violations?: unknown }>(text, "Violation detection");
  const rawList = parsed.violations;
  if (!Array.isArray(rawList)) {
    throw new HttpsError("internal", "Violation detection: violations must be an array.");
  }

  const violations: ViolationRow[] = [];
  for (const row of rawList) {
    if (!row || typeof row !== "object") {
      continue;
    }
    const o = row as Record<string, unknown>;
    const type = typeof o.type === "string" ? o.type.trim() : "";
    const description = typeof o.description === "string" ? o.description.trim() : "";
    if (type && description) {
      violations.push({ type, description });
    }
  }

  return { violations };
});

export const detectCompliance = onCall(async (request) => {
  const uid = requireAuthUid(request);
  void uid;
  const messages = normalizeMessagesField(request.data?.messages, "messages");

  const genAI = new GoogleGenerativeAI(getGeminiKey());
  const model = genAI.getGenerativeModel({
    model: MODEL_ID,
    generationConfig: {
      temperature: 0.12,
      maxOutputTokens: 768,
      responseMimeType: "application/json",
      responseSchema: {
        type: SchemaType.OBJECT,
        properties: {
          riskLevel: { type: SchemaType.STRING, enum: ["low", "medium", "high"] },
          issues: {
            type: SchemaType.ARRAY,
            items: { type: SchemaType.STRING },
          },
        },
        required: ["riskLevel", "issues"],
      },
    },
  });

  const prompt =
    "Review this co-parenting message thread for compliance and communication risk.\n" +
    "Return JSON:\n" +
    "- riskLevel: low | medium | high (overall risk)\n" +
    "- issues: at most 3 short human-readable issue strings (empty array if none; never more than 3)\n\n" +
    "CONVERSATION:\n" +
    messages;

  let text: string;
  try {
    const res = await model.generateContent(prompt);
    text = res.response.text();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new HttpsError("internal", `Compliance scan failed: ${msg}`);
  }

  const parsed = parseJsonObject<{ riskLevel?: string; issues?: unknown }>(
    text,
    "Compliance detection"
  );
  const risk = (parsed.riskLevel ?? "").toString().trim().toLowerCase();
  if (risk !== "low" && risk !== "medium" && risk !== "high") {
    throw new HttpsError("internal", "Compliance: invalid riskLevel.");
  }
  const rawIssues = parsed.issues;
  const issues: string[] = [];
  if (Array.isArray(rawIssues)) {
    for (const row of rawIssues) {
      const s = typeof row === "string" ? row.trim() : String(row ?? "").trim();
      if (s) {
        issues.push(s);
      }
    }
  }

  return { riskLevel: risk, issues };
});
