/// Presentation only; Laravel remains the authority for prices and booking dates.
String visitMoney(int amount, String currency) {
  if (amount == 0) return 'Gratis';
  final digits = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
  return currency == 'IDR' ? 'Rp$digits' : '$currency $digits';
}

const visitMonths = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String visitMonth(DateTime date) =>
    '${visitMonths[date.month - 1]} ${date.year}';
String visitDateLabel(DateTime date) => '${date.day} ${visitMonth(date)}';
