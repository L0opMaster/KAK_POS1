import 'dart:convert';

/// True if [token] is not a well-formed, unexpired JWT. Any decode failure
/// or missing `exp` claim is treated as expired — the token is unusable
/// either way, and failing safe forces a re-login instead of trusting it.
bool isJwtExpired(final String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) {
      return true;
    }
    final payloadJson =
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final payload = json.decode(payloadJson) as Map<String, dynamic>;
    final exp = payload['exp'];
    if (exp is! int) {
      return true;
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );
    return !DateTime.now().toUtc().isBefore(expiresAt);
  } catch (_) {
    return true;
  }
}
