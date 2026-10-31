export type AccessGrantState = {
  status: string;
  expires_at: string | null;
  granted_scope: unknown;
};

/** A reveal is allowed only while every requested scope remains in an unexpired accepted grant. */
export function isAccessGrantActive(grant: AccessGrantState | null | undefined, requiredScopes: readonly string[], now = Date.now()): boolean {
  if (!grant || grant.status !== "accepted" || !grant.expires_at) return false;
  const expiresAt = new Date(grant.expires_at).getTime();
  if (!Number.isFinite(expiresAt) || expiresAt <= now) return false;
  const grantedScope = grant.granted_scope;
  if (!Array.isArray(grantedScope) || !grantedScope.every((scope) => typeof scope === "string")) return false;
  return requiredScopes.every((scope) => grantedScope.includes(scope));
}
