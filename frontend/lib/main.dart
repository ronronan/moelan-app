import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `DateFormat` with an explicit locale throws unless that locale's symbols
  // have been loaded first. Every date the app shows is French ("12 mars",
  // not "Mar 12"), so this has to happen before the first frame.
  await initializeDateFormatting('fr_FR');
  runApp(const ProviderScope(child: MoelanApp()));
}
