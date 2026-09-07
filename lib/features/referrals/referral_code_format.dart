/// Vista previa del código de vendedor externo (`NOMBRE.B2B`).
/// La unicidad (PEDRO2.B2B, …) la resuelve el servidor al crear.
abstract final class ReferralCodeFormat {
  static const suffix = '.B2B';

  static const _accentFrom = 'ÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇÝ';
  static const _accentTo = 'AAAAAAEEEEIIIIOOOOOUUUUNCY';

  static String stemFromName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty ? '' : parts.first;
    final stripped = _stripAccents(first.toUpperCase())
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (stripped.length < 2) return 'VENDEDOR';
    if (stripped.length > 16) return stripped.substring(0, 16);
    return stripped;
  }

  static String previewCode(String fullName) => '${stemFromName(fullName)}$suffix';

  static String _stripAccents(String input) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final i = _accentFrom.indexOf(ch);
      buf.write(i >= 0 ? _accentTo[i] : ch);
    }
    return buf.toString();
  }
}
