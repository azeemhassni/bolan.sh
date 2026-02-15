/// Sanitizes command history before sharing with AI providers.
///
/// Redacts common sensitive patterns: API keys, tokens, passwords,
/// connection strings, and environment variable assignments.
class HistorySanitizer {
  const HistorySanitizer._();

  /// Sanitizes a list of history entries, redacting sensitive content.
  static List<String> sanitize(List<String> entries) {
    return entries.map(_sanitizeEntry).toList();
  }

  static String _sanitizeEntry(String entry) {
    var result = entry;

    // Redact known API key patterns
    result = result.replaceAll(
      RegExp(r'(sk-[a-zA-Z0-9]{20,})'), '[REDACTED_KEY]');
    result = result.replaceAll(
      RegExp(r'(AIza[a-zA-Z0-9_-]{30,})'), '[REDACTED_KEY]');
    result = result.replaceAll(
      RegExp(r'(ghp_[a-zA-Z0-9]{30,})'), '[REDACTED_KEY]');
    result = result.replaceAll(
      RegExp(r'(gho_[a-zA-Z0-9]{30,})'), '[REDACTED_KEY]');
    result = result.replaceAll(
      RegExp(r'(glpat-[a-zA-Z0-9_-]{20,})'), '[REDACTED_KEY]');
    result = result.replaceAll(
      RegExp(r'(xox[bpas]-[a-zA-Z0-9-]{20,})'), '[REDACTED_KEY]');
    result = result.replaceAll(
      RegExp(r'(AKIA[A-Z0-9]{16})'), '[REDACTED_KEY]');

    // Redact Bearer/Authorization tokens
    result = result.replaceAll(
      RegExp(r'(Bearer\s+)[^\s"' "'" r']+', caseSensitive: false),
      r'$1[REDACTED_TOKEN]');
    result = result.replaceAll(
      RegExp(r'(Authorization:\s*)[^\s"' "'" r']+', caseSensitive: false),
      r'$1[REDACTED_TOKEN]');

    // Redact passwords in URLs (user:pass@host)
    result = result.replaceAll(
      RegExp(r'://([^:]+):([^@]+)@'),
      r'://$1:[REDACTED]@');

    // Redact export/set of sensitive env vars
    result = result.replaceAll(
      RegExp(
        r'(export\s+|set\s+)?'
        r'([\w]*(SECRET|KEY|TOKEN|PASSWORD|PASS|CREDENTIAL|AUTH|PRIVATE)[_\w]*)'
        r'\s*=\s*\S+',
        caseSensitive: false,
      ),
      r'$1$2=[REDACTED]');

    // Redact long hex/base64 strings (likely secrets, 32+ chars)
    result = result.replaceAll(
      RegExp(r'(?<=[=\s])[A-Za-z0-9+/]{40,}={0,2}(?=\s|$)'),
      '[REDACTED_VALUE]');

    // Redact --password and --token flag values
    result = result.replaceAll(
      RegExp(r'(--(?:password|token|secret|key|api-key)\s+)\S+',
          caseSensitive: false),
      r'$1[REDACTED]');
    result = result.replaceAll(
      RegExp(r'(--(?:password|token|secret|key|api-key)=)\S+',
          caseSensitive: false),
      r'$1[REDACTED]');

    // Redact -p flag for common tools (mysql, psql)
    result = result.replaceAll(
      RegExp(r'(\s-p\s*)[^\s]+'), r'$1[REDACTED]');

    return result;
  }
}
