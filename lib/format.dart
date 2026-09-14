/// ---------------------------------------------------------------------------
/// Number formatting
/// ---------------------------------------------------------------------------
/// Hand-rolled on purpose: the app ships no `intl` dependency and this is the
/// only formatting it needs. Adding a package for four commas would be a poor
/// trade on an offline-first, ad-supported app.
library;

/// Inserts thousands separators: `5675` becomes `"5,675"`.
///
/// The stat tiles lead with a four- or five-digit model count, and an unbroken
/// run of digits is genuinely hard to read at a glance — which is the entire
/// purpose of those tiles.
String groupDigits(int value) {
  final digits = value.abs().toString();
  if (digits.length <= 3) return digits.isEmpty ? '0' : '$value';

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
