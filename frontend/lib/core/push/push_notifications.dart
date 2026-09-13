import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cagnotte_repository.dart';

/// M16 scaffolding: push notifications via Firebase Cloud Messaging (see
/// the plan's M16 section and the README's "Notifications push" guide).
///
/// Every step here fails soft. Until a real Firebase project is created
/// and wired in (`flutterfire configure`, `google-services.json`, etc —
/// none of that exists yet), `Firebase.initializeApp()` throws; we log and
/// return, and the rest of the app is completely unaffected. There is
/// nothing to "turn on" here beyond providing that config — this class
/// already runs (and no-ops) today.
class PushNotifications {
  const PushNotifications();

  Future<void> initialize(WidgetRef ref) async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push notifications disabled: Firebase not configured ($e)');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _register(ref, token);
    }
    messaging.onTokenRefresh.listen((refreshed) => _register(ref, refreshed));
  }

  Future<void> _register(WidgetRef ref, String token) async {
    try {
      await ref
          .read(cagnotteRepositoryProvider)
          .registerDeviceToken(token, _platform);
    } catch (e) {
      debugPrint('Failed to register device token: $e');
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'other',
    };
  }
}

final pushNotificationsProvider = Provider((ref) => const PushNotifications());
