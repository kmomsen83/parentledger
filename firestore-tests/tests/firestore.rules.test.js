const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  serverTimestamp,
} = require("firebase/firestore");

const PROJECT_ID = "parentledger-rules-test";
const RULES_PATH = path.resolve(__dirname, "../../firestore.rules");

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

test.after(async () => {
  await env.cleanup();
});

test.beforeEach(async () => {
  await env.clearFirestore();
});

async function seedCase({
  caseId,
  ownerId,
  memberIds,
  includeOwnerUser = true,
}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "cases", caseId), {
      ownerId,
      memberIds,
      createdAt: serverTimestamp(),
    });
    for (const uid of memberIds) {
      await setDoc(doc(db, "cases", caseId, "members", uid), {
        userId: uid,
        role: uid === ownerId ? "parent" : "attorney",
        createdAt: serverTimestamp(),
      });
    }
    if (includeOwnerUser) {
      await setDoc(doc(db, "users", ownerId), {
        role: "parent",
        parentType: "mom",
        caseId,
        accessLevel: "free",
        subscriptionTier: "free",
        isPremium: false,
      });
    }
  });
}

test("Unauthorized case access -> FAIL", async () => {
  const caseId = "caseA";
  await seedCase({ caseId, ownerId: "owner1", memberIds: ["owner1"] });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "attacker"), {
      role: "parent",
      parentType: "dad",
      caseId: "caseB",
      accessLevel: "free",
      subscriptionTier: "free",
      isPremium: false,
    });
  });
  const db = env.authenticatedContext("attacker").firestore();
  await assertFails(getDoc(doc(db, "cases", caseId)));
});

test("Unauthorized membership write -> FAIL", async () => {
  const caseId = "caseA";
  await seedCase({ caseId, ownerId: "owner1", memberIds: ["owner1"] });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "attacker"), {
      role: "parent",
      parentType: "guardian",
      caseId: "caseX",
      accessLevel: "free",
      subscriptionTier: "free",
      isPremium: false,
    });
  });
  const db = env.authenticatedContext("attacker").firestore();
  await assertFails(
    updateDoc(doc(db, "cases", caseId), {
      memberIds: ["owner1", "attacker"],
    })
  );
});

test("Valid invite accept (server-side membership result) -> PASS", async () => {
  const caseId = "caseA";
  await seedCase({
    caseId,
    ownerId: "owner1",
    memberIds: ["owner1", "invitee1"],
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "invitee1"), {
      role: "parent",
      parentType: "dad",
      caseId,
      accessLevel: "free",
      subscriptionTier: "free",
      isPremium: false,
    });
  });
  const db = env.authenticatedContext("invitee1").firestore();
  await assertSucceeds(getDoc(doc(db, "cases", caseId)));
  await assertSucceeds(getDoc(doc(db, "cases", caseId, "members", "invitee1")));
});

test("Non-member read -> FAIL", async () => {
  const caseId = "caseA";
  await seedCase({ caseId, ownerId: "owner1", memberIds: ["owner1"] });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "outsider"), {
      role: "parent",
      parentType: "mom",
      caseId: "otherCase",
      accessLevel: "free",
      subscriptionTier: "free",
      isPremium: false,
    });
  });
  const db = env.authenticatedContext("outsider").firestore();
  await assertFails(getDoc(doc(db, "cases", caseId, "members", "owner1")));
});

