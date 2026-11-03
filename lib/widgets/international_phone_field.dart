import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:phone_numbers_parser/metadata.dart';

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

String countryFlag(IsoCode country) => String.fromCharCodes(
    country.name.codeUnits.map((letter) => letter + 0x1F1A5));

String _dialCode(IsoCode country) =>
    PhoneNumber(isoCode: country, nsn: '').countryCode;

class _NationalPhoneFormatter extends TextInputFormatter {
  final IsoCode country;
  _NationalPhoneFormatter(this.country);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Preserve international paste so the existing country detection can read it.
    if (newValue.text.trim().startsWith('+') ||
        newValue.composing.isValid ||
        newValue.selection.extentOffset != newValue.text.length) {
      return newValue;
    }
    try {
      final phone =
          PhoneNumber.parse(newValue.text, destinationCountry: country);
      final formatted = phone.formatNsn(format: NsnFormat.international);
      return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length));
    } catch (_) {
      return newValue;
    }
  }
}

class InternationalPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final IsoCode country;
  final ValueChanged<IsoCode> onCountryChanged;
  final VoidCallback onChanged;
  final String? error;
  final bool split;
  final bool enabled;
  const InternationalPhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    required this.onChanged,
    this.error,
    this.split = false,
    this.enabled = true,
  });

  Future<void> _pickCountry(BuildContext context) async {
    final result = await showModalBottomSheet<IsoCode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _CountryPicker(selected: country),
    );
    if (result != null) onCountryChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final phone = parseBookingPhone(controller.text, country);
    final examples = metadataExamplesByIsoCode[country]!;
    final example = PhoneNumber(
        isoCode: country,
        nsn: examples.mobile.isEmpty ? examples.fixedLine : examples.mobile);
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDCE4F0)));
    final countrySelector = TextButton(
      key: const ValueKey('phoneCountryPicker'),
      onPressed: enabled ? () => _pickCountry(context) : null,
      style:
          split ? TextButton.styleFrom(minimumSize: const Size(0, 56)) : null,
      child: Semantics(
        label: '${_countryNames[country.name]}, +${_dialCode(country)}',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(countryFlag(country), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 5),
          if (split)
            Flexible(child: Text('+${_dialCode(country)}'))
          else
            Text('+${_dialCode(country)}'),
          const Icon(Icons.arrow_drop_down, size: 18),
        ]),
      ),
    );
    final field = TextFormField(
      key: const ValueKey('bookingPhone'),
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [_NationalPhoneFormatter(country)],
      style: const TextStyle(color: Color(0xFF102D59), fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Nomor Telepon',
        hintText: example.formatNsn(format: NsnFormat.international),
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2)),
        errorText: error,
        errorMaxLines: 3,
        helperText: phone == null
            ? null
            : '+${phone.countryCode} ${phone.formatNsn(format: NsnFormat.international)}',
        helperMaxLines: 2,
        prefixIconConstraints: const BoxConstraints(minHeight: 48),
        prefixIcon: split
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 10),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      border:
                          Border(right: BorderSide(color: Color(0xFFDCE4F0)))),
                  child: countrySelector,
                ),
              ),
      ),
      onChanged: (_) => onChanged(),
      validator: (value) => parseBookingPhone(value ?? '', country) == null
          ? 'Nomor telepon tidak valid untuk negara ini'
          : null,
    );
    if (!split) return field;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 122),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDCE4F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: countrySelector,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: field),
    ]);
  }
}

class _CountryPicker extends StatefulWidget {
  final IsoCode selected;
  const _CountryPicker({required this.selected});

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final countries = IsoCode.values
        .where((country) =>
            '${_countryNames[country.name]} ${country.name} +${_dialCode(country)}'
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom) *
            .72,
        child: Column(children: [
          const Text('Pilih negara',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('countrySearch'),
              decoration: const InputDecoration(
                  hintText: 'Cari negara atau kode telepon',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: countries.isEmpty
                ? const Center(child: Text('Negara tidak ditemukan'))
                : ListView.builder(
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      final country = countries[index];
                      return ListTile(
                        leading: Text(countryFlag(country),
                            style: const TextStyle(fontSize: 26)),
                        title:
                            Text(_countryNames[country.name] ?? country.name),
                        subtitle:
                            Text('${country.name} +${_dialCode(country)}'),
                        selected: country == widget.selected,
                        trailing: country == widget.selected
                            ? const Icon(Icons.check, color: Color(0xFF1976D2))
                            : null,
                        onTap: () => Navigator.pop(context, country),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

// ISO region display names; dialing and number formats remain parser metadata.
const _countryNames = <String, String>{
  'AC': 'Ascension Island',
  'AD': 'Andorra',
  'AE': 'United Arab Emirates',
  'AF': 'Afghanistan',
  'AG': 'Antigua & Barbuda',
  'AI': 'Anguilla',
  'AL': 'Albania',
  'AM': 'Armenia',
  'AO': 'Angola',
  'AR': 'Argentina',
  'AS': 'American Samoa',
  'AT': 'Austria',
  'AU': 'Australia',
  'AW': 'Aruba',
  'AX': 'Åland Islands',
  'AZ': 'Azerbaijan',
  'BA': 'Bosnia & Herzegovina',
  'BB': 'Barbados',
  'BD': 'Bangladesh',
  'BE': 'Belgium',
  'BF': 'Burkina Faso',
  'BG': 'Bulgaria',
  'BH': 'Bahrain',
  'BI': 'Burundi',
  'BJ': 'Benin',
  'BL': 'St. Barthélemy',
  'BM': 'Bermuda',
  'BN': 'Brunei',
  'BO': 'Bolivia',
  'BQ': 'Bonaire, Sint Eustatius and Saba',
  'BR': 'Brazil',
  'BS': 'Bahamas',
  'BT': 'Bhutan',
  'BW': 'Botswana',
  'BY': 'Belarus',
  'BZ': 'Belize',
  'CA': 'Canada',
  'CC': 'Cocos (Keeling) Islands',
  'CD': 'Congo (DRC)',
  'CF': 'Central African Republic',
  'CG': 'Congo',
  'CH': 'Switzerland',
  'CI': 'Côte d’Ivoire',
  'CK': 'Cook Islands',
  'CL': 'Chile',
  'CM': 'Cameroon',
  'CN': 'China',
  'CO': 'Colombia',
  'CR': 'Costa Rica',
  'CU': 'Cuba',
  'CV': 'Cabo Verde',
  'CW': 'Curaçao',
  'CX': 'Christmas Island',
  'CY': 'Cyprus',
  'CZ': 'Czechia',
  'DE': 'Germany',
  'DJ': 'Djibouti',
  'DK': 'Denmark',
  'DM': 'Dominica',
  'DO': 'Dominican Republic',
  'DZ': 'Algeria',
  'EC': 'Ecuador',
  'EE': 'Estonia',
  'EG': 'Egypt',
  'EH': 'Western Sahara',
  'ER': 'Eritrea',
  'ES': 'Spain',
  'ET': 'Ethiopia',
  'FI': 'Finland',
  'FJ': 'Fiji',
  'FK': 'Falkland Islands',
  'FM': 'Micronesia',
  'FO': 'Faroe Islands',
  'FR': 'France',
  'GA': 'Gabon',
  'GB': 'United Kingdom',
  'GD': 'Grenada',
  'GE': 'Georgia',
  'GF': 'French Guiana',
  'GG': 'Guernsey',
  'GH': 'Ghana',
  'GI': 'Gibraltar',
  'GL': 'Greenland',
  'GM': 'Gambia',
  'GN': 'Guinea',
  'GP': 'Guadeloupe',
  'GQ': 'Equatorial Guinea',
  'GR': 'Greece',
  'GT': 'Guatemala',
  'GU': 'Guam',
  'GW': 'Guinea-Bissau',
  'GY': 'Guyana',
  'HK': 'Hong Kong SAR',
  'HN': 'Honduras',
  'HR': 'Croatia',
  'HT': 'Haiti',
  'HU': 'Hungary',
  'ID': 'Indonesia',
  'IE': 'Ireland',
  'IL': 'Israel',
  'IM': 'Isle of Man',
  'IN': 'India',
  'IO': 'British Indian Ocean Territory',
  'IQ': 'Iraq',
  'IR': 'Iran',
  'IS': 'Iceland',
  'IT': 'Italy',
  'JE': 'Jersey',
  'JM': 'Jamaica',
  'JO': 'Jordan',
  'JP': 'Japan',
  'KE': 'Kenya',
  'KG': 'Kyrgyzstan',
  'KH': 'Cambodia',
  'KI': 'Kiribati',
  'KM': 'Comoros',
  'KN': 'St. Kitts & Nevis',
  'KP': 'North Korea',
  'KR': 'Korea',
  'KW': 'Kuwait',
  'KY': 'Cayman Islands',
  'KZ': 'Kazakhstan',
  'LA': 'Laos',
  'LB': 'Lebanon',
  'LC': 'St. Lucia',
  'LI': 'Liechtenstein',
  'LK': 'Sri Lanka',
  'LR': 'Liberia',
  'LS': 'Lesotho',
  'LT': 'Lithuania',
  'LU': 'Luxembourg',
  'LV': 'Latvia',
  'LY': 'Libya',
  'MA': 'Morocco',
  'MC': 'Monaco',
  'MD': 'Moldova',
  'ME': 'Montenegro',
  'MF': 'St. Martin',
  'MG': 'Madagascar',
  'MH': 'Marshall Islands',
  'MK': 'North Macedonia',
  'ML': 'Mali',
  'MM': 'Myanmar',
  'MN': 'Mongolia',
  'MO': 'Macao SAR',
  'MP': 'Northern Mariana Islands',
  'MQ': 'Martinique',
  'MR': 'Mauritania',
  'MS': 'Montserrat',
  'MT': 'Malta',
  'MU': 'Mauritius',
  'MV': 'Maldives',
  'MW': 'Malawi',
  'MX': 'Mexico',
  'MY': 'Malaysia',
  'MZ': 'Mozambique',
  'NA': 'Namibia',
  'NC': 'New Caledonia',
  'NE': 'Niger',
  'NF': 'Norfolk Island',
  'NG': 'Nigeria',
  'NI': 'Nicaragua',
  'NL': 'Netherlands',
  'NO': 'Norway',
  'NP': 'Nepal',
  'NR': 'Nauru',
  'NU': 'Niue',
  'NZ': 'New Zealand',
  'OM': 'Oman',
  'PA': 'Panama',
  'PE': 'Peru',
  'PF': 'French Polynesia',
  'PG': 'Papua New Guinea',
  'PH': 'Philippines',
  'PK': 'Pakistan',
  'PL': 'Poland',
  'PM': 'St. Pierre & Miquelon',
  'PR': 'Puerto Rico',
  'PS': 'Palestinian Authority',
  'PT': 'Portugal',
  'PW': 'Palau',
  'PY': 'Paraguay',
  'QA': 'Qatar',
  'RE': 'Réunion',
  'RO': 'Romania',
  'RS': 'Serbia',
  'RU': 'Russia',
  'RW': 'Rwanda',
  'SA': 'Saudi Arabia',
  'SB': 'Solomon Islands',
  'SC': 'Seychelles',
  'SD': 'Sudan',
  'SE': 'Sweden',
  'SG': 'Singapore',
  'SH': 'St Helena, Ascension, Tristan da Cunha',
  'SI': 'Slovenia',
  'SJ': 'Svalbard & Jan Mayen',
  'SK': 'Slovakia',
  'SL': 'Sierra Leone',
  'SM': 'San Marino',
  'SN': 'Senegal',
  'SO': 'Somalia',
  'SR': 'Suriname',
  'SS': 'South Sudan',
  'ST': 'São Tomé & Príncipe',
  'SV': 'El Salvador',
  'SX': 'Sint Maarten',
  'SY': 'Syria',
  'SZ': 'Eswatini',
  'TA': 'Tristan da Cunha',
  'TC': 'Turks & Caicos Islands',
  'TD': 'Chad',
  'TG': 'Togo',
  'TH': 'Thailand',
  'TJ': 'Tajikistan',
  'TK': 'Tokelau',
  'TL': 'Timor-Leste',
  'TM': 'Turkmenistan',
  'TN': 'Tunisia',
  'TO': 'Tonga',
  'TR': 'Türkiye',
  'TT': 'Trinidad & Tobago',
  'TV': 'Tuvalu',
  'TW': 'Taiwan',
  'TZ': 'Tanzania',
  'UA': 'Ukraine',
  'UG': 'Uganda',
  'US': 'United States',
  'UY': 'Uruguay',
  'UZ': 'Uzbekistan',
  'VA': 'Vatican City',
  'VC': 'St. Vincent & Grenadines',
  'VE': 'Venezuela',
  'VG': 'British Virgin Islands',
  'VI': 'U.S. Virgin Islands',
  'VN': 'Vietnam',
  'VU': 'Vanuatu',
  'WF': 'Wallis & Futuna',
  'WS': 'Samoa',
  'XK': 'Kosovo',
  'YE': 'Yemen',
  'YT': 'Mayotte',
  'ZA': 'South Africa',
  'ZM': 'Zambia',
  'ZW': 'Zimbabwe',
};
