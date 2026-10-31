export function isAgentModeConfigurable(
  mode: string,
  appEnv: string | undefined,
  syntheticOptIn: string | undefined,
  n8nConfigured = false,
): boolean {
  if (mode === "mock") return true;
  if (mode === "direct") return appEnv === "local" && syntheticOptIn === "true";
  return mode === "n8n" && n8nConfigured && appEnv === "local";
}
