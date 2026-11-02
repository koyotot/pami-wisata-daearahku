import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

PhoneNumber? parseBookingPhone(String input, IsoCode country) {
  if (input.trim().isEmpty) return null;
  try {
    final phone = PhoneNumber.parse(input.trim(),
        destinationCountry: input.trim().startsWith('+') ? null : country);
    return phone.isValid() ? phone : null;
  } catch (_) {
    return null;
  }
}

class InternationalPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final IsoCode country;
  final ValueChanged<IsoCode> onCountryChanged;
  final VoidCallback onChanged;
  final String? error;
  const InternationalPhoneField(
      {super.key,
      required this.controller,
      required this.country,
      required this.onCountryChanged,
      required this.onChanged,
      this.error});

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1976D2), size: 18),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF728099), fontSize: 13),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE4F0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final phone = parseBookingPhone(controller.text, country);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<IsoCode>(
        key: ValueKey(country),
        initialValue: country,
        isExpanded: true,
        decoration: _decoration('Kode negara', Icons.public),
        items: IsoCode.values
            .map((iso) => DropdownMenuItem(
                  value: iso,
                  child: Text(
                      '${iso.name} +${PhoneNumber(isoCode: iso, nsn: '').countryCode}'),
                ))
            .toList(),
        onChanged: (value) {
          if (value != null) onCountryChanged(value);
        },
      ),
      const SizedBox(height: 10),
      TextFormField(
        key: const ValueKey('bookingPhone'),
        controller: controller,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        style: const TextStyle(color: Color(0xFF102D59), fontSize: 14),
        decoration: _decoration('Nomor Telepon', Icons.phone_rounded).copyWith(
          hintText: 'Nomor nasional atau +kode negara',
          errorText: error,
          helperText: phone == null
              ? null
              : '+${phone.countryCode} ${phone.formatNsn(format: NsnFormat.international)}',
          helperMaxLines: 2,
        ),
        onChanged: (_) => onChanged(),
        validator: (value) => parseBookingPhone(value ?? '', country) == null
            ? 'Nomor telepon tidak valid untuk negara ini'
            : null,
      ),
    ]);
  }
}
