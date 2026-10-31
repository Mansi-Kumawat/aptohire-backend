export function isLocalSyntheticDirectOptedIn(appEnv: string | undefined, optIn: string | undefined): boolean {
  return appEnv === "local" && optIn === "true";
}

export function isFictionalTestAccountEmail(email: string | null | undefined): boolean {
  if (typeof email !== "string") return false;
  const normalized = email.trim().toLowerCase();
  const separator = normalized.lastIndexOf("@");
  return separator > 0 && !normalized.slice(0, separator).includes("@") && normalized.slice(separator + 1).endsWith(".test");
}

export function isLocalSyntheticProfileDirectAllowed(input: {
  agentMode: string;
  killSwitch: unknown;
  sourceAutoApprove: boolean;
  appEnv: string | undefined;
  optIn: string | undefined;
  email: string | null | undefined;
}): boolean {
  return input.agentMode === "direct" && input.killSwitch !== true && input.killSwitch !== "true" &&
    input.sourceAutoApprove === false && isLocalSyntheticDirectOptedIn(input.appEnv, input.optIn) &&
    isFictionalTestAccountEmail(input.email);
}
