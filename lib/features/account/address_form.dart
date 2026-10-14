import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../market/models/market_extras.dart';

// Shared by the saved addresses screen and the checkout delivery step, so a
// buyer sees the same fields and validation in both places — port of
// frontend/app/me/profile/_components/addressForm.tsx.

class AddressDraft {
  final label = TextEditingController();
  final fullName = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final area = TextEditingController();
  final postcode = TextEditingController();

  AddressDraft([BuyerAddress? a]) {
    if (a != null) fill(a);
  }

  void fill(BuyerAddress a) {
    label.text = a.label ?? '';
    fullName.text = a.fullName;
    phone.text = a.phone;
    address.text = a.address;
    city.text = a.city;
    area.text = a.area ?? '';
    postcode.text = a.postcode ?? '';
  }

  void clear() {
    for (final c in _all) {
      c.clear();
    }
  }

  List<TextEditingController> get _all => [label, fullName, phone, address, city, area, postcode];

  AddressInput toInput({bool isDefault = false}) => AddressInput(
        label: label.text,
        fullName: fullName.text,
        phone: phone.text,
        address: address.text,
        city: city.text,
        area: area.text,
        postcode: postcode.text,
        isDefault: isDefault,
      );

  /// Inline `shipping` body for a one-off checkout address.
  Map<String, dynamic> toShipping() {
    final json = toInput().toJson()
      ..remove('label')
      ..remove('is_default');
    json.removeWhere((_, v) => v == null);
    return json;
  }

  String get oneLine => [address.text, area.text, city.text, postcode.text]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');

  /// Field key → message. Empty when valid.
  Map<String, String> validate() {
    final e = <String, String>{};
    if (fullName.text.trim().isEmpty) e['full_name'] = "Enter the recipient's name";
    final ph = phone.text.trim();
    final digits = ph.replaceAll(RegExp(r'\D'), '');
    if (ph.isEmpty) {
      e['phone'] = 'Enter a phone number';
    } else if (!RegExp(r'^[+\d\s()-]+$').hasMatch(ph) || digits.length < 7 || digits.length > 15) {
      e['phone'] = 'Enter a valid phone number';
    }
    if (address.text.trim().isEmpty) e['address'] = 'Enter a street address';
    if (city.text.trim().isEmpty) e['city'] = 'Enter a city';
    final pc = postcode.text.trim();
    if (pc.isNotEmpty && !RegExp(r'^[A-Za-z0-9\s-]{3,10}$').hasMatch(pc)) e['postcode'] = 'Enter a valid postcode';
    return e;
  }

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

/// The address inputs. Errors come from [AddressDraft.validate].
class AddressFields extends StatelessWidget {
  final AddressDraft draft;
  final Map<String, String> errors;
  final bool showLabel;
  final ValueChanged<String>? onEdited;
  const AddressFields({super.key, required this.draft, this.errors = const {}, this.showLabel = true, this.onEdited});

  @override
  Widget build(BuildContext context) {
    Widget field(
      String key,
      String label,
      TextEditingController c, {
      bool optional = false,
      String? hint,
      TextInputType? keyboard,
      int maxLength = 120,
      List<String>? autofill,
      TextCapitalization caps = TextCapitalization.sentences,
    }) =>
        _Field(
          label: label,
          optional: optional,
          error: errors[key],
          child: TextField(
            controller: c,
            keyboardType: keyboard,
            textCapitalization: caps,
            autofillHints: autofill,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
            onChanged: (_) => onEdited?.call(key),
            style: TextStyle(fontSize: 14, color: Palette.of(context).text),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              enabledBorder: errors[key] == null
                  ? null
                  : OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.danger),
                    ),
            ),
          ),
        );

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLabel) field('label', 'Label', draft.label, optional: true, hint: 'Home, office', maxLength: 40),
          field('full_name', 'Full name', draft.fullName,
              autofill: const [AutofillHints.name], caps: TextCapitalization.words),
          field('phone', 'Phone', draft.phone,
              hint: '01XXXXXXXXX',
              keyboard: TextInputType.phone,
              maxLength: 20,
              autofill: const [AutofillHints.telephoneNumber],
              caps: TextCapitalization.none),
          field('address', 'Address', draft.address,
              hint: 'House, road, block', maxLength: 255, autofill: const [AutofillHints.streetAddressLine1]),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field('city', 'City', draft.city,
                    maxLength: 80, autofill: const [AutofillHints.addressCity], caps: TextCapitalization.words),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: field('area', 'Area', draft.area, optional: true, maxLength: 80, caps: TextCapitalization.words),
              ),
            ],
          ),
          field('postcode', 'Postcode', draft.postcode,
              optional: true,
              keyboard: TextInputType.text,
              maxLength: 10,
              autofill: const [AutofillHints.postalCode],
              caps: TextCapitalization.characters),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final bool optional;
  final String? error;
  final Widget child;
  const _Field({required this.label, required this.optional, required this.error, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (optional) TextSpan(text: ' (optional)', style: TextStyle(color: p.textTertiary)),
            ]),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.textSecondary),
          ),
          const SizedBox(height: 6),
          child,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
