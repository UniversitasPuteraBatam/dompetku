import 'dart:convert';
import 'dart:typed_data';

import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/services/app_clock.dart';
import 'package:dompetku/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AuthService profile', () {
    const savedSession = {
      'id': 1,
      'name': 'Indra',
      'email': 'indra@gmail.com',
      'profile_photo': null,
      'token': 'jwt-token',
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode(savedSession),
      });
    });

    test(
      'gets profile with bearer token and refreshes the saved session',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/profile');
          expect(request.headers['authorization'], 'Bearer jwt-token');
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Profil berhasil diambil',
              'data': {
                'id': 1,
                'name': 'Indra Terbaru',
                'email': 'indra@gmail.com',
                'profile_photo': 'https://example.com/profile.png',
              },
            }),
            200,
          );
        });
        final service = AuthService(
          client: client,
          baseUrl: 'http://localhost:3000',
        );

        final user = await service.getProfile();

        expect(user.name, 'Indra Terbaru');
        expect(user.profilePhoto, 'https://example.com/profile.png');
        expect(user.token, 'jwt-token');
        final session = (await _savedSession())!;
        expect(session['name'], 'Indra Terbaru');
        expect(session['profile_photo'], 'https://example.com/profile.png');
        expect(session.containsKey('password'), isFalse);
        client.close();
      },
    );

    test(
      'updates only the name then refreshes the session',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/profile');
          expect(request.headers['content-type'], 'application/json');
          expect(request.headers['authorization'], 'Bearer jwt-token');
          expect(jsonDecode(request.body), {'name': 'Indra Baru'});
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Profil berhasil diperbarui',
              'data': {
                'id': 1,
                'name': 'Indra Baru',
                'email': 'indra@gmail.com',
                'profile_photo': 'https://example.com/profile.png',
              },
            }),
            200,
          );
        });
        final service = AuthService(
          client: client,
          baseUrl: 'http://localhost:3000',
        );

        final user = await service.updateProfile(name: 'Indra Baru');

        expect(user.name, 'Indra Baru');
        expect(user.email, 'indra@gmail.com');
        expect(user.profilePhoto, 'https://example.com/profile.png');
        final session = (await _savedSession())!;
        expect(session['name'], 'Indra Baru');
        expect(session.containsKey('password'), isFalse);
        client.close();
      },
    );

    test(
      'clears the session when profile API responds with HTTP 401',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': 'Token tidak valid'}),
            401,
          ),
        );
        final service = AuthService(client: client);

        await expectLater(
          service.getProfile(),
          throwsA(
            isA<AuthApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
        expect(await _savedSession(), isNull);
        client.close();
      },
    );

    test('uploads the photo as multipart and saves the returned path', () async {
      final photoBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/profile/photo');
        expect(request.headers['authorization'], 'Bearer jwt-token');
        expect(request.headers['content-type'], startsWith('multipart/form-data'));
        expect(utf8.decode(request.bodyBytes, allowMalformed: true),
            contains('name="photo"'));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 1,
              'name': 'Indra',
              'email': 'indra@gmail.com',
              'profile_photo': '/uploads/profile/1-photo.png',
            },
          }),
          200,
        );
      });
      final service = AuthService(
        client: client,
        baseUrl: 'http://localhost:3000',
      );

      final user = await service.uploadProfilePhoto(photoBytes);

      expect(user.profilePhoto, '/uploads/profile/1-photo.png');
      expect(user.token, 'jwt-token');
      final session = (await _savedSession())!;
      expect(session['profile_photo'], '/uploads/profile/1-photo.png');
      client.close();
    });

    test('returns the API message when the photo is rejected', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Ukuran foto maksimal 2 MB'}),
          413,
        ),
      );
      final service = AuthService(client: client);

      await expectLater(
        service.uploadProfilePhoto(Uint8List(4)),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.message, 'message', 'Ukuran foto maksimal 2 MB')
              .having((error) => error.statusCode, 'statusCode', 413),
        ),
      );
      client.close();
    });

    test('deletes the photo on the server', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/profile/photo');
        expect(request.headers['authorization'], 'Bearer jwt-token');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 1,
              'name': 'Indra',
              'email': 'indra@gmail.com',
              'profile_photo': null,
            },
          }),
          200,
        );
      });
      final service = AuthService(client: client);

      final user = await service.deleteProfilePhoto();

      expect(user.profilePhoto, isNull);
      client.close();
    });

    test('resolves uploaded photo paths against the base URL', () {
      final service = AuthService(baseUrl: 'http://192.168.1.10:3000');

      expect(
        service.resolvePhotoUrl('/uploads/profile/1-photo.png'),
        'http://192.168.1.10:3000/uploads/profile/1-photo.png',
      );
      expect(
        service.resolvePhotoUrl('https://example.com/profile.png'),
        'https://example.com/profile.png',
      );
      expect(service.resolvePhotoUrl(null), isNull);
      expect(service.resolvePhotoUrl(''), isNull);
    });

    test('drops the photo that older versions kept on the device', () async {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode(savedSession),
        'profile_photo_1': 'iVBORw0KGgo=',
      });
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 1,
              'name': 'Indra',
              'email': 'indra@gmail.com',
              'profile_photo': null,
            },
          }),
          200,
        ),
      );
      final service = AuthService(client: client);

      await service.getProfile();

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('profile_photo_1'), isFalse);
      client.close();
    });
  });

  group('AuthService.changePassword', () {
    const savedSession = {
      'id': 1,
      'name': 'Indra',
      'email': 'indra@gmail.com',
      'profile_photo': null,
      'token': 'jwt-token',
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode(savedSession),
      });
    });

    test('sends old and new passwords with bearer token only', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/change-password');
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers['authorization'], 'Bearer jwt-token');
        expect(jsonDecode(request.body), {
          'current_password': 'old-password',
          'new_password': 'new-password',
        });
        expect(request.body, isNot(contains('user_id')));
        expect(request.body, isNot(contains('email')));
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Password berhasil diperbarui',
          }),
          200,
        );
      });
      final service = AuthService(client: client);

      await expectLater(
        service.changePassword(
          currentPassword: 'old-password',
          newPassword: 'new-password',
        ),
        completes,
      );
      client.close();
    });

    test(
      'returns API validation message when current password is incorrect',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'message': 'Password lama tidak sesuai',
            }),
            400,
          ),
        );
        final service = AuthService(client: client);

        await expectLater(
          service.changePassword(
            currentPassword: 'wrong-password',
            newPassword: 'new-password',
          ),
          throwsA(
            isA<AuthApiException>()
                .having((error) => error.statusCode, 'statusCode', 400)
                .having(
                  (error) => error.message,
                  'message',
                  'Password lama tidak sesuai',
                ),
          ),
        );
        client.close();
      },
    );
  });

  group('AuthService.deleteTransaction', () {
    const savedSession = {
      'id': 1,
      'name': 'Indra',
      'email': 'indra@gmail.com',
      'profile_photo': null,
      'token': 'jwt-token',
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode(savedSession),
      });
    });

    test('sends DELETE request with bearer token and no user id', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/transactions/42');
        expect(request.headers['authorization'], 'Bearer jwt-token');
        expect(request.url.queryParameters.containsKey('user_id'), isFalse);
        expect(request.body, isEmpty);
        return http.Response(
          jsonEncode({'success': true, 'message': 'Transaksi dihapus'}),
          200,
        );
      });
      final service = AuthService(
        client: client,
        baseUrl: 'http://localhost:3000',
      );

      await expectLater(service.deleteTransaction(id: 42), completes);
      client.close();
    });

    for (final testCase in [
      (statusCode: 400, message: 'Permintaan tidak valid'),
      (statusCode: 404, message: 'Transaksi tidak ditemukan'),
      (statusCode: 401, message: 'Token tidak valid'),
    ]) {
      test('handles HTTP ${testCase.statusCode}', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': testCase.message}),
            testCase.statusCode,
          ),
        );
        final service = AuthService(client: client);

        await expectLater(
          service.deleteTransaction(id: 42),
          throwsA(
            isA<AuthApiException>()
                .having(
                  (error) => error.statusCode,
                  'statusCode',
                  testCase.statusCode,
                )
                .having((error) => error.message, 'message', testCase.message),
          ),
        );
        if (testCase.statusCode == 401) {
          expect(await _savedSession(), isNull);
        }
        client.close();
      });
    }
  });

  group('AuthService.updateTransaction', () {
    const savedSession = {
      'id': 1,
      'name': 'Indra',
      'email': 'indra@gmail.com',
      'profile_photo': null,
      'token': 'jwt-token',
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode(savedSession),
      });
    });

    test('sends selected Jakarta date and time as a PUT payload', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/transactions/42');
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers['authorization'], 'Bearer jwt-token');
        expect(jsonDecode(request.body), {
          'type': 'expense',
          'category': 'Makanan',
          'amount': 35000,
          'description': 'Makan malam',
          'transaction_date': '2026-10-15 22:35:00',
        });
        expect(request.body, isNot(contains('user_id')));
        expect(request.body, isNot(contains('password')));
        return http.Response(
          jsonEncode({'success': true, 'message': 'Transaksi diperbarui'}),
          200,
        );
      });
      final service = AuthService(
        client: client,
        baseUrl: 'http://localhost:3000',
      );

      await expectLater(
        service.updateTransaction(
          id: 42,
          type: 'expense',
          category: 'Makanan',
          amount: 35000,
          description: 'Makan malam',
          transactionDate: DateTime.utc(2026, 10, 15, 22, 35),
        ),
        completes,
      );
      client.close();
    });

    for (final testCase in [
      (statusCode: 400, message: 'Nominal tidak valid'),
      (statusCode: 404, message: 'Transaksi tidak ditemukan'),
      (statusCode: 401, message: 'Token tidak valid'),
    ]) {
      test('handles HTTP ${testCase.statusCode}', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': testCase.message}),
            testCase.statusCode,
          ),
        );
        final service = AuthService(client: client);

        await expectLater(
          service.updateTransaction(
            id: 42,
            type: 'income',
            category: 'Bonus',
            amount: 5000,
            description: '',
            transactionDate: DateTime(2026, 10, 7),
          ),
          throwsA(
            isA<AuthApiException>()
                .having(
                  (error) => error.statusCode,
                  'statusCode',
                  testCase.statusCode,
                )
                .having((error) => error.message, 'message', testCase.message),
          ),
        );
        if (testCase.statusCode == 401) {
          expect(await _savedSession(), isNull);
        }
        client.close();
      });
    }
  });

  group('AuthService.addTransaction', () {
    const savedSession = {
      'id': 1,
      'name': 'Indra',
      'email': 'indra@gmail.com',
      'profile_photo': null,
      'token': 'jwt-token',
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode(savedSession),
      });
    });

    group('AuthService.getTransactions', () {
      const savedSession = {
        'id': 1,
        'name': 'Indra',
        'email': 'indra@gmail.com',
        'profile_photo': null,
        'token': 'jwt-token',
      };

      setUp(() {
        SharedPreferences.setMockInitialValues({
          'auth_session': jsonEncode(savedSession),
        });
      });

      test('loads and parses the authenticated transaction list', () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/transactions');
          expect(request.headers['authorization'], 'Bearer jwt-token');
          expect(request.url.queryParameters.containsKey('user_id'), isFalse);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 4,
                  'type': 'expense',
                  'category': 'Makanan',
                  'amount': '25000',
                  'description': 'Makan siang',
                  'transaction_date': '2026-10-07 12:34:56',
                },
              ],
            }),
            200,
          );
        });
        final service = AuthService(
          client: client,
          baseUrl: 'http://localhost:3000',
        );

        final transactions = await service.getTransactions();

        expect(transactions, hasLength(1));
        expect(transactions.single.category, 'Makanan');
        expect(transactions.single.amount, 25000);
        expect(transactions.single.isIncome, isFalse);
        expect(transactions.single.note, 'Makan siang');
        expect(transactions.single.date, DateTime.utc(2026, 10, 7, 12, 34, 56));
        client.close();
      });

      test('treats API transaction timestamps as calendar dates', () {
        final transaction = TransactionItem.fromApiJson({
          'id': 5,
          'type': 'income',
          'category': 'Gaji',
          'amount': 4000000,
          'description': 'Gaji',
          'transaction_date': '2026-10-07',
        });

        expect(transaction.date, DateTime.utc(2026, 10, 7));
        expect(transaction.date.isUtc, isTrue);
        expect(transaction.hasTime, isFalse);
        expect(transaction.dateLabel, isNot(contains('00:00')));
      });

      test('uses transaction_date time without applying a timezone shift', () {
        final transaction = TransactionItem.fromApiJson({
          'id': 6,
          'type': 'income',
          'category': 'Gaji',
          'amount': 4000000,
          'description': 'Gaji',
          'transaction_date': '2026-10-07 23:36:00',
          'created_at': '2026-10-06T15:51:00.000Z',
        });

        expect(transaction.date, DateTime.utc(2026, 10, 7, 23, 36));
        expect(transaction.hasTime, isTrue);
        expect(transaction.dateLabel, endsWith('23:36'));
      });

      test('shifts ISO UTC transaction_date to the Jakarta day and time', () {
        final transaction = TransactionItem.fromApiJson({
          'id': 7,
          'type': 'expense',
          'category': 'Makanan',
          'amount': 25000,
          'description': 'Sarapan',
          'transaction_date': '2026-10-06T20:00:00.000Z',
        });

        expect(transaction.date, DateTime.utc(2026, 10, 7, 3));
        expect(transaction.hasTime, isTrue);
        expect(transaction.dateLabel, '7 Okt 2026, 03:00');
      });

      test('reads ISO transaction_date with a +07:00 offset as is', () {
        final transaction = TransactionItem.fromApiJson({
          'id': 8,
          'type': 'income',
          'category': 'Gaji',
          'amount': 4000000,
          'description': 'Gaji',
          'transaction_date': '2026-10-07T00:30:00+07:00',
        });

        expect(transaction.date, DateTime.utc(2026, 10, 7, 0, 30));
        expect(transaction.hasTime, isTrue);
      });

      test('rejects an unreadable transaction_date', () {
        expect(
          () => TransactionItem.fromApiJson({
            'id': 9,
            'type': 'income',
            'category': 'Gaji',
            'amount': 4000000,
            'description': 'Gaji',
            'transaction_date': '07/10/2026',
          }),
          throwsFormatException,
        );
      });

      test('returns server error message for HTTP 500', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': 'Database unavailable'}),
            500,
          ),
        );
        final service = AuthService(client: client);

        await expectLater(
          service.getTransactions(),
          throwsA(
            isA<AuthApiException>()
                .having((error) => error.statusCode, 'statusCode', 500)
                .having(
                  (error) => error.message,
                  'message',
                  'Database unavailable',
                ),
          ),
        );
        client.close();
      });

      test('returns validation message for HTTP 400', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': 'Filter tidak valid'}),
            400,
          ),
        );
        final service = AuthService(client: client);

        await expectLater(
          service.getTransactions(),
          throwsA(
            isA<AuthApiException>()
                .having((error) => error.statusCode, 'statusCode', 400)
                .having(
                  (error) => error.message,
                  'message',
                  'Filter tidak valid',
                ),
          ),
        );
        client.close();
      });

      test(
        'clears the session when the list endpoint returns HTTP 401',
        () async {
          final client = MockClient(
            (_) async => http.Response(
              jsonEncode({'success': false, 'message': 'Token tidak valid'}),
              401,
            ),
          );
          final service = AuthService(client: client);

          await expectLater(
            service.getTransactions(),
            throwsA(
              isA<AuthApiException>().having(
                (error) => error.statusCode,
                'statusCode',
                401,
              ),
            ),
          );
          expect(await _savedSession(), isNull);
          client.close();
        },
      );
    });

    test(
      'sends transaction with bearer token and no user credentials',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/transactions');
          expect(request.headers['content-type'], 'application/json');
          expect(request.headers['authorization'], 'Bearer jwt-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {
            'type': 'income',
            'category': 'Freelance',
            'amount': 125000,
            'description': 'Proyek desain',
            'transaction_date': '2026-10-08 00:00:00',
          });
          expect(body.containsKey('user_id'), isFalse);
          expect(body.containsKey('password'), isFalse);
          return http.Response(
            jsonEncode({'success': true, 'message': 'Transaksi berhasil'}),
            201,
          );
        });
        final service = AuthService(
          client: client,
          baseUrl: 'http://localhost:3000',
        );

        await expectLater(
          service.addTransaction(
            type: 'income',
            category: 'Freelance',
            amount: 125000,
            description: 'Proyek desain',
            transactionDate: AppClock.now(
              utcNow: DateTime.utc(2026, 10, 7, 17),
            ),
          ),
          completes,
        );
        client.close();
      },
    );

    test('returns the API validation message for HTTP 400', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Kategori tidak valid'}),
          400,
        ),
      );
      final service = AuthService(client: client);

      await expectLater(
        service.addTransaction(
          type: 'income',
          category: 'Salah',
          amount: 125000,
          description: '',
          transactionDate: DateTime.utc(2026, 10, 7, 9, 5, 44),
        ),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.message,
                'message',
                'Kategori tidak valid',
              ),
        ),
      );
      client.close();
    });

    test('clears invalid session and reports HTTP 401', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Token tidak valid'}),
          401,
        ),
      );
      final service = AuthService(client: client);

      await expectLater(
        service.addTransaction(
          type: 'expense',
          category: 'Makanan',
          amount: 25000,
          description: '',
          transactionDate: DateTime(2026, 10, 7),
        ),
        throwsA(
          isA<AuthApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(await _savedSession(), isNull);
      client.close();
    });
  });

  group('AuthService.login', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sends credentials and saves only the returned session', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/login');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'email': 'indra@gmail.com',
          'password': '123456',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Login berhasil',
            'data': {
              'id': 1,
              'name': 'Indra',
              'email': 'indra@gmail.com',
              'profile_photo': null,
              'token': 'jwt-token',
            },
          }),
          200,
        );
      });
      final service = AuthService(
        client: client,
        baseUrl: 'http://localhost:3000',
      );

      final user = await service.login(
        email: 'indra@gmail.com',
        password: '123456',
      );

      expect(user.id, 1);
      expect(user.name, 'Indra');
      expect(user.email, 'indra@gmail.com');
      expect(user.profilePhoto, isNull);
      expect(user.token, 'jwt-token');
      final savedSession = (await _savedSession())!;
      expect(savedSession, {
        'id': 1,
        'name': 'Indra',
        'email': 'indra@gmail.com',
        'profile_photo': null,
        'token': 'jwt-token',
      });
      expect(savedSession.containsKey('password'), isFalse);

      // The token must never be written to plain SharedPreferences.
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('auth_session'), isFalse);

      await service.logout();
      expect(await _savedSession(), isNull);
      client.close();
    });

    for (final testCase in [
      (statusCode: 400, message: 'Email tidak valid'),
      (statusCode: 401, message: 'Password salah'),
    ]) {
      test('uses the API message for HTTP ${testCase.statusCode}', () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': testCase.message}),
            testCase.statusCode,
          ),
        );
        final service = AuthService(client: client);

        await expectLater(
          service.login(email: 'indra@gmail.com', password: 'bad'),
          throwsA(
            isA<AuthApiException>().having(
              (error) => error.message,
              'message',
              testCase.message,
            ),
          ),
        );
        client.close();
      });
    }
  });

  group('AuthService.register', () {
    test(
      'sends registration fields and accepts a successful response',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/register');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {
            'name': 'Indra',
            'email': 'indra@gmail.com',
            'password': '123456',
          });
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Registrasi berhasil',
              'data': {'id': 1, 'name': 'Indra', 'email': 'indra@gmail.com'},
            }),
            201,
          );
        });
        final service = AuthService(
          client: client,
          baseUrl: 'http://localhost:3000',
        );

        await expectLater(
          service.register(
            name: 'Indra',
            email: 'indra@gmail.com',
            password: '123456',
          ),
          completes,
        );

        client.close();
      },
    );

    test('returns the API message when registration fails', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Email sudah terdaftar'}),
          409,
        ),
      );
      final service = AuthService(client: client);

      await expectLater(
        service.register(
          name: 'Indra',
          email: 'indra@gmail.com',
          password: '123456',
        ),
        throwsA(
          isA<AuthApiException>().having(
            (error) => error.message,
            'message',
            'Email sudah terdaftar',
          ),
        ),
      );

      client.close();
    });
  });

  group('AuthService session storage', () {
    test('moves a session saved by older versions into secure storage', () async {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode({
          'id': 1,
          'name': 'Indra',
          'email': 'indra@gmail.com',
          'profile_photo': null,
          'token': 'jwt-token',
        }),
      });

      final user = await AuthService().getSavedUser();

      expect(user?.token, 'jwt-token');
      expect((await _savedSession())?['token'], 'jwt-token');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('auth_session'), isFalse);
    });

    test('treats an unreadable secure session as logged out', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({'auth_session': 'not-json'});

      expect(await AuthService().getSavedUser(), isNull);
      expect(await _savedSession(), isNull);
    });
  });
}

Future<Map<String, dynamic>?> _savedSession() async {
  final session = await const FlutterSecureStorage().read(key: 'auth_session');
  if (session == null) return null;
  return jsonDecode(session) as Map<String, dynamic>;
}
