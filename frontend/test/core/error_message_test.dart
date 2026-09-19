import 'package:app/core/error_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _response(int status, {Object? body}) {
  final options = RequestOptions(path: '/api/players');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  group('humanizeError', () {
    test('never leaks the raw exception text to the screen', () {
      final message = humanizeError(_response(500));
      expect(message, isNot(contains('DioException')));
      expect(message, isNot(contains('/api/players')));
    });

    test('translates the backend error codes the UI routes on', () {
      expect(
        humanizeError(_response(403, body: {'code': 'no_organization'})),
        contains('aucun espace'),
      );
      expect(
        humanizeError(_response(403, body: {'code': 'org_pending'})),
        contains('validation'),
      );
    });

    test('surfaces the backend wording on a 400, which names the rule', () {
      expect(
        humanizeError(
          _response(400, body: {'error': 'amount_cents must be positive'}),
        ),
        'amount_cents must be positive',
      );
    });

    test('falls back to a generic sentence when the 400 body is unusable', () {
      expect(
        humanizeError(_response(400, body: {'error': 'x' * 500})),
        'La demande a été refusée.',
      );
    });

    test('maps a lost connection to something actionable', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/players'),
        type: DioExceptionType.connectionError,
      );
      expect(humanizeError(error), contains('connexion'));
    });

    test('handles a non-Dio failure without throwing', () {
      expect(humanizeError(StateError('boom')), isNotEmpty);
    });
  });

  group('isRetryable', () {
    test('offers a retry for timeouts and server faults', () {
      expect(
        isRetryable(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        isTrue,
      );
      expect(isRetryable(_response(503)), isTrue);
    });

    test('does not offer a retry for a refusal that will never change', () {
      expect(isRetryable(_response(403)), isFalse);
      expect(isRetryable(_response(404)), isFalse);
    });
  });

  group('errorCode', () {
    test('extracts the slug the dashboard branches on', () {
      expect(
        errorCode(_response(403, body: {'code': 'org_pending'})),
        'org_pending',
      );
      expect(errorCode(_response(403)), isNull);
      expect(errorCode(StateError('boom')), isNull);
    });
  });
}
