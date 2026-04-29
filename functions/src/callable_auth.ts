import { HttpsError } from "firebase-functions/v2/https";

export function requireAuthUid(request: { auth?: { uid: string } }): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return uid;
}
