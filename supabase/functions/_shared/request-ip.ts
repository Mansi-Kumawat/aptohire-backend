/** Extract the client address from gateway-provided forwarding headers, preferring Cloudflare's overwritten client header. */
export function requestClientIp(request: Request): string | undefined {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const candidate = [
    request.headers.get("cf-connecting-ip")?.trim(),
    request.headers.get("x-real-ip")?.trim(),
    forwarded,
  ].find((value) => value && isIpLiteral(value));
  return candidate;
}

function isIpLiteral(value: string): boolean {
  if (value.length > 45 || /[\r\n\s]/.test(value)) return false;
  const octets = value.split(".");
  if (octets.length === 4 && octets.every((part) => /^\d{1,3}$/.test(part) && Number(part) <= 255)) return true;
  // Accept normal, compressed, and IPv4-mapped IPv6 literals; reject hostnames and ports.
  return value.includes(":") && /^[0-9a-fA-F:.]+$/.test(value) && (value.match(/:/g)?.length ?? 0) >= 2;
}
