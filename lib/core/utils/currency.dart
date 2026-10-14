/// Mirrors frontend/app/lib/currency.ts — every listing carries its own ISO
/// 4217 currency, so prices always show that listing's own symbol.
const _symbols = <String, String>{
  'USD': r'$',
  'BDT': '৳',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'JPY': '¥',
  'CNY': '¥',
  'AED': 'د.إ',
  'SAR': '﷼',
  'PKR': '₨',
  'AUD': r'A$',
  'CAD': r'C$',
  'SGD': r'S$',
  'MYR': 'RM',
};

String currencySymbol(String? currency) {
  final code = (currency == null || currency.isEmpty ? 'USD' : currency).toUpperCase();
  return _symbols[code] ?? code;
}

/// `৳1,250` / `$19.99` — drops `.00` for whole amounts, keeps two decimals
/// otherwise.
String formatPrice(num amount, String? currency) {
  final whole = amount == amount.roundToDouble();
  final fixed = whole ? amount.round().toString() : amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${currencySymbol(currency)}$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}
