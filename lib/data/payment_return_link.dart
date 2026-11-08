/// What the e-wallet return page claims happened. It is an untrusted display hint only:
/// no hint, including [success], ever proves payment. The server decides.
enum PaymentReturnHint { none, success, cancel, error, unknown }

/// Parsed `/payment/return[?result=...]` App Link route name.
class PaymentReturnLink {
  const PaymentReturnLink(this.hint);
  final PaymentReturnHint hint;

  static const path = '/payment/return';

  /// Returns null unless [routeName] is exactly the payment return path.
  /// Any scheme/host in [routeName] is ignored because Flutter hands over path and query only.
  static PaymentReturnLink? parse(String? routeName) {
    if (routeName == null || routeName.isEmpty) return null;
    final Uri uri;
    try {
      uri = Uri.parse(routeName);
    } on FormatException {
      return null;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 2 ||
        segments[0] != 'payment' ||
        segments[1] != 'return') {
      return null;
    }
    final values = uri.queryParametersAll['result'];
    if (values == null || values.isEmpty) {
      return const PaymentReturnLink(PaymentReturnHint.none);
    }
    return PaymentReturnLink(switch (values.first.toLowerCase()) {
      'success' => PaymentReturnHint.success,
      'cancel' => PaymentReturnHint.cancel,
      'error' => PaymentReturnHint.error,
      _ => PaymentReturnHint.unknown,
    });
  }
}
