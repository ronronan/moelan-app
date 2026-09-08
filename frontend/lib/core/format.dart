import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

/// Formats integer cents as euros. Money is never represented as a
/// double anywhere else in the app; conversion happens only here, at
/// display time.
String formatCents(int cents) => _currency.format(cents / 100);
