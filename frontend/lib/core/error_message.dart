import 'package:dio/dio.dart';

/// Turns whatever blew up into something a treasurer can act on.
///
/// Before this existed, every screen rendered `Erreur : $err`, which for a
/// Dio failure means a paragraph of stack-shaped text naming the internal
/// host and port. That tells the person nothing they can use, and tells a
/// bystander more about the deployment than they should see.
///
/// The backend attaches a machine-readable `code` to the few 403s the UI has
/// to branch on (`AppError::code` on the Rust side); those get a specific
/// sentence. Everything else is mapped from its HTTP status, and the last
/// resort is deliberately vague rather than raw.
String humanizeError(Object error) {
  if (error is! DioException) return 'Une erreur inattendue est survenue.';

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Le serveur met trop de temps à répondre. Réessayez dans un instant.';
    case DioExceptionType.connectionError:
      return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
    case DioExceptionType.cancel:
      return 'Requête annulée.';
    case DioExceptionType.badCertificate:
      return 'La connexion au serveur n\'a pas pu être sécurisée.';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
    default:
      break;
  }

  final response = error.response;
  final data = response?.data;
  final code = data is Map && data['code'] is String
      ? data['code'] as String
      : null;

  switch (code) {
    case 'no_organization':
      return "Ce compte n'appartient à aucun espace.";
    case 'org_pending':
      return 'Cet espace attend encore la validation d\'un administrateur.';
  }

  switch (response?.statusCode) {
    case 400:
      return _serverMessage(data) ?? 'La demande a été refusée.';
    case 401:
      return 'Votre session a expiré. Reconnectez-vous.';
    case 403:
      return "Vous n'avez pas les droits pour cette action.";
    case 404:
      return "Cet élément n'existe pas, ou plus.";
    case 409:
      return 'Cette valeur est déjà utilisée.';
    case 500:
    case 502:
    case 503:
      return 'Le serveur a rencontré un problème. Réessayez dans un instant.';
  }
  return 'Une erreur inattendue est survenue.';
}

/// A 400 is the one case where the backend's own wording is worth showing:
/// it names the rule that was broken ("amount_cents must be positive"), which
/// is more useful than a generic sentence. Kept short so an unexpected blob
/// can't take over the screen.
String? _serverMessage(Object? data) {
  if (data is Map && data['error'] is String) {
    final message = (data['error'] as String).trim();
    if (message.isNotEmpty && message.length <= 120) return message;
  }
  return null;
}

/// True when the failure is worth offering a "retry" button for — a timeout
/// or a dropped connection might work on the second try; a 403 never will.
bool isRetryable(Object error) {
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    default:
      final status = error.response?.statusCode ?? 0;
      return status >= 500;
  }
}

/// The machine-readable slug the backend attaches to the 403s the UI routes
/// on, or null for every other failure.
String? errorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) return data['code'] as String;
  }
  return null;
}
