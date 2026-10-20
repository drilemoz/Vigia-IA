/// Shared by persistence and exports; never include FormatException.source.
class DiagnosticRedactor {
  static String field(String key, Object? value) {
    if (RegExp(
      r'password|passwd|senha|token|authorization|api.?key|credential|userinfo|username',
      caseSensitive: false,
    ).hasMatch(key)) {
      return '[omitido]';
    }
    return text(value?.toString() ?? 'null');
  }

  static String text(String value) {
    var safe = value.replaceAllMapped(
      RegExp(
        r'(FormatException:[^\n]*)(?:\n(?!#|\s*at |\s*$)[^\n]*)+',
        multiLine: true,
      ),
      (match) => '${match.group(1)}\n[entrada omitida]',
    );
    safe = safe.replaceAll(
      RegExp(r'''(?:rtsps?|https?|wss?)://[^\s"<>]+''', caseSensitive: false),
      '[endereço omitido]',
    );
    safe = safe.replaceAllMapped(
      RegExp(
        r'''((?:password|passwd|senha|token|authorization|api[_-]?key|credential|userinfo|username)["']?\s*[=:]\s*)(?:"[^"]*"|'[^']*'|[^\s,;}]+)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[omitido]',
    );
    return safe;
  }
}
