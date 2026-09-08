import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oidc/oidc.dart';

import 'auth/auth_providers.dart';
import 'config.dart';

final apiClientProvider = Provider<Dio>((ref) {
  final manager = ref.watch(oidcManagerProvider);
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = manager.currentUser?.token.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          try {
            await manager.refreshToken();
          } on OidcException {
            // Refresh failed; let the original 401 propagate so the UI can
            // route back to the login screen.
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
