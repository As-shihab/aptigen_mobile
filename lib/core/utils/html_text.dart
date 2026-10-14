/// Listing descriptions are rich-text HTML from the seller's editor. The app
/// has no HTML renderer, so this flattens it into readable plain text —
/// block tags become line breaks, list items become bullets, entities decode.
String htmlToPlainText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  var text = html
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(
        RegExp(r'</\s*(p|div|h[1-6]|ul|ol|li|blockquote|tr)\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };
  entities.forEach((k, v) => text = text.replaceAll(k, v));
  text = text.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.tryParse(m[1]!) ?? 32),
  );
  return text
      .split('\n')
      .map((l) => l.trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
