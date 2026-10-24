import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/dummy_transactions.dart';
import 'app_clock.dart';

class AuthService {
  AuthService({
    http.Client? client,
    String? baseUrl,
    FlutterSecureStorage? secureStorage,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? _defaultBaseUrl,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final String _baseUrl;

  /// Holds the session, including the JWT, encrypted by the platform
  /// (Keystore on Android, Keychain on iOS).
  final FlutterSecureStorage _secureStorage;

  static const _sessionKey = 'auth_session';
  static String _legacyProfilePhotoKey(int userId) => 'profile_photo_$userId';
  static const _invalidSessionMessage =
      'Sesi login tidak valid. Silakan login kembali.';

  // Set per environment with --dart-define=API_BASE_URL=https://api.example.com
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get _defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.endsWith('/')
          ? _configuredBaseUrl.substring(0, _configuredBaseUrl.length - 1)
          : _configuredBaseUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    throw AuthApiException(
      _responseMessage(response.body, 'Registrasi gagal. Silakan coba lagi.'),
    );
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    // A 401 here means wrong credentials, not an expired session.
    if (response.statusCode != 200) {
      final fallbackMessage = switch (response.statusCode) {
        400 => 'Permintaan login tidak valid. Periksa email dan password.',
        401 => 'Email atau password salah.',
        _ => 'Login gagal. Silakan coba lagi.',
      };
      throw AuthApiException(_responseMessage(response.body, fallbackMessage));
    }

    late final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        throw const AuthApiException('Respons login dari server tidak valid.');
      }
      body = decoded;
    } on FormatException {
      throw const AuthApiException('Respons login dari server tidak valid.');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const AuthApiException('Respons login dari server tidak valid.');
    }

    final user = AuthUser.fromJson(data);
    await _saveSession(user);
    return user;
  }

  Future<AuthUser?> getSavedUser() async {
    final savedSession =
        await _secureStorage.read(key: _sessionKey) ??
        await _migrateLegacySession();
    if (savedSession == null) return null;

    try {
      final decoded = jsonDecode(savedSession);
      if (decoded is Map<String, dynamic>) {
        return AuthUser.fromJson(decoded);
      }
    } on FormatException {
      // An unreadable saved session is treated as expired.
    } on AuthApiException {
      // An incomplete saved session is treated as expired.
    }
    await _secureStorage.delete(key: _sessionKey);
    return null;
  }

  /// Older versions kept the session in plain SharedPreferences. It is moved
  /// to secure storage once so signed-in users stay signed in.
  Future<String?> _migrateLegacySession() async {
    final preferences = await SharedPreferences.getInstance();
    final legacySession = preferences.getString(_sessionKey);
    if (legacySession == null) return null;

    await _secureStorage.write(key: _sessionKey, value: legacySession);
    await preferences.remove(_sessionKey);
    return legacySession;
  }

  Future<AuthUser> getProfile() async {
    final user = await _requireSavedUser();
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/profile'),
      headers: _authHeaders(user),
    );
    if (response.statusCode != 200) {
      await _throwResponseError(response, switch (response.statusCode) {
        404 => 'User tidak ditemukan.',
        >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
        _ => 'Profil gagal dimuat. Silakan coba lagi.',
      });
    }

    final updatedUser = _profileUserFromResponse(response.body, user.token);
    await _saveSession(updatedUser);
    return updatedUser;
  }

  /// Updates the name only; the photo goes through [uploadProfilePhoto] and
  /// [deleteProfilePhoto].
  Future<AuthUser> updateProfile({required String name}) async {
    final user = await _requireSavedUser();
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/profile'),
      headers: _authHeaders(user, json: true),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode != 200) {
      await _throwResponseError(response, switch (response.statusCode) {
        400 => 'Data profil tidak valid. Periksa kembali nama.',
        404 => 'User tidak ditemukan.',
        >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
        _ => 'Profil gagal diperbarui. Silakan coba lagi.',
      });
    }

    final updatedUser = _profileUserFromResponse(response.body, user.token);
    await _saveSession(updatedUser);
    return updatedUser;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await _requireSavedUser();
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/change-password'),
      headers: _authHeaders(user, json: true),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      await _throwResponseError(response, switch (response.statusCode) {
        400 => 'Password tidak valid. Periksa password lama dan password baru.',
        404 => 'User tidak ditemukan.',
        >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
        _ => 'Password gagal diperbarui. Silakan coba lagi.',
      });
    }
  }

  AuthUser _profileUserFromResponse(String responseBody, String token) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['data'] is! Map<String, dynamic>) {
        throw const AuthApiException('Respons profil dari server tidak valid.');
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final id = data['id'];
      final name = data['name'];
      final email = data['email'];
      final profilePhoto = data['profile_photo'];
      if (id is! num ||
          name is! String ||
          email is! String ||
          (profilePhoto != null && profilePhoto is! String)) {
        throw const AuthApiException('Respons profil dari server tidak valid.');
      }

      return AuthUser(
        id: id.toInt(),
        name: name,
        email: email,
        profilePhoto: profilePhoto as String?,
        token: token,
      );
    } on FormatException {
      throw const AuthApiException('Respons profil dari server tidak valid.');
    }
  }

  Future<void> _saveSession(AuthUser user) async {
    try {
      await _secureStorage.write(
        key: _sessionKey,
        value: jsonEncode(user.toJson()),
      );
    } on PlatformException {
      throw const AuthApiException('Sesi login gagal disimpan.');
    }
    // Older versions kept the photo only on the device; it now lives on the
    // server, so the local copy is dropped.
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyProfilePhotoKey(user.id));
  }

  Future<AuthUser> uploadProfilePhoto(Uint8List photoBytes) async {
    final user = await _requireSavedUser();
    final request =
        http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/profile/photo'))
          ..headers.addAll(_authHeaders(user))
          ..files.add(
            http.MultipartFile.fromBytes(
              'photo',
              photoBytes,
              filename: 'profile-photo',
            ),
          );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode != 200) {
      await _throwResponseError(response, switch (response.statusCode) {
        400 => 'Foto harus berformat JPG, PNG, atau WebP.',
        404 => 'User tidak ditemukan.',
        413 => 'Ukuran foto maksimal 2 MB.',
        >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
        _ => 'Foto profil gagal diunggah. Silakan coba lagi.',
      });
    }

    final updatedUser = _profileUserFromResponse(response.body, user.token);
    await _saveSession(updatedUser);
    return updatedUser;
  }

  Future<AuthUser> deleteProfilePhoto() async {
    final user = await _requireSavedUser();
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/profile/photo'),
      headers: _authHeaders(user),
    );
    if (response.statusCode != 200) {
      await _throwResponseError(response, switch (response.statusCode) {
        404 => 'User tidak ditemukan.',
        >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
        _ => 'Foto profil gagal dihapus. Silakan coba lagi.',
      });
    }

    final updatedUser = _profileUserFromResponse(response.body, user.token);
    await _saveSession(updatedUser);
    return updatedUser;
  }

  /// The API stores uploaded photos as paths like `/uploads/profile/1-x.png`;
  /// they are resolved against the current base URL so a server address
  /// change does not break them.
  String? resolvePhotoUrl(String? profilePhoto) {
    if (profilePhoto == null || profilePhoto.isEmpty) return null;
    if (profilePhoto.startsWith('/')) return '$_baseUrl$profilePhoto';
    return profilePhoto;
  }

  Future<void> addTransaction({
    required String type,
    required String category,
    required int amount,
    required String description,
    required DateTime transactionDate,
  }) async {
    final user = await _requireSavedUser();
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/transactions'),
      headers: _authHeaders(user, json: true),
      body: jsonEncode(
        _transactionRequestBody(
          type: type,
          category: category,
          amount: amount,
          description: description,
          transactionDate: transactionDate,
        ),
      ),
    );
    if (response.statusCode == 201) return;

    await _throwResponseError(response, switch (response.statusCode) {
      400 => 'Data transaksi tidak valid. Periksa kembali isian.',
      _ => 'Transaksi gagal ditambahkan. Silakan coba lagi.',
    });
  }

  Future<List<TransactionItem>> getTransactions() async {
    final user = await _requireSavedUser();
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/transactions'),
      headers: _authHeaders(user),
    );
    if (response.statusCode != 200) {
      await _throwResponseError(response, switch (response.statusCode) {
        400 => 'Permintaan riwayat transaksi tidak valid.',
        >= 500 => 'Server sedang bermasalah. Coba lagi nanti.',
        _ => 'Riwayat transaksi gagal dimuat. Silakan coba lagi.',
      });
    }

    try {
      final decoded = jsonDecode(response.body);
      final rows = _transactionRows(decoded);
      return rows
          .map((row) => TransactionItem.fromApiJson(row))
          .toList(growable: false);
    } on FormatException catch (error) {
      throw AuthApiException(error.message);
    }
  }

  Future<void> updateTransaction({
    required int id,
    required String type,
    required String category,
    required int amount,
    required String description,
    required DateTime transactionDate,
  }) async {
    final user = await _requireSavedUser();
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/transactions/$id'),
      headers: _authHeaders(user, json: true),
      body: jsonEncode(
        _transactionRequestBody(
          type: type,
          category: category,
          amount: amount,
          description: description,
          transactionDate: transactionDate,
        ),
      ),
    );
    if (response.statusCode == 200) return;

    await _throwResponseError(response, switch (response.statusCode) {
      400 => 'Data transaksi tidak valid. Periksa kembali isian.',
      404 => 'Transaksi tidak ditemukan.',
      _ => 'Transaksi gagal diperbarui. Silakan coba lagi.',
    });
  }

  Future<void> deleteTransaction({required int id}) async {
    final user = await _requireSavedUser();
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/transactions/$id'),
      headers: _authHeaders(user),
    );
    if (response.statusCode == 200) return;

    await _throwResponseError(response, switch (response.statusCode) {
      400 => 'Permintaan hapus transaksi tidak valid.',
      404 => 'Transaksi tidak ditemukan.',
      _ => 'Transaksi gagal dihapus. Silakan coba lagi.',
    });
  }

  List<Map<String, dynamic>> _transactionRows(dynamic decoded) {
    dynamic rows = decoded;
    if (decoded is Map<String, dynamic>) {
      if (decoded['success'] == false) {
        throw const FormatException('Server gagal mengirim riwayat transaksi.');
      }
      rows = decoded['data'] ?? decoded['transactions'];
      if (rows is Map<String, dynamic>) {
        rows = rows['transactions'] ?? rows['data'];
      }
    }
    if (rows is! List) {
      throw const FormatException('Format riwayat transaksi tidak valid.');
    }
    return rows
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw const FormatException(
              'Data transaksi dari server tidak valid.',
            );
          }
          return row;
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _transactionRequestBody({
    required String type,
    required String category,
    required int amount,
    required String description,
    required DateTime transactionDate,
  }) {
    return {
      'type': type,
      'category': category,
      'amount': amount,
      'description': description,
      'transaction_date': AppClock.timestampString(transactionDate),
    };
  }

  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } on PlatformException {
      throw const AuthApiException('Sesi gagal dihapus.');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }

  Future<AuthUser> _requireSavedUser() async {
    final user = await getSavedUser();
    if (user == null) {
      throw const AuthApiException(_invalidSessionMessage, statusCode: 401);
    }
    return user;
  }

  Map<String, String> _authHeaders(AuthUser user, {bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    'Authorization': 'Bearer ${user.token}',
  };

  /// Throws the API error for [response]. A 401 also clears the saved session
  /// so screens can send the user back to Login.
  Future<Never> _throwResponseError(
    http.Response response,
    String fallbackMessage,
  ) async {
    if (response.statusCode == 401) {
      final message = _responseMessage(response.body, _invalidSessionMessage);
      await logout();
      throw AuthApiException(message, statusCode: 401);
    }
    throw AuthApiException(
      _responseMessage(response.body, fallbackMessage),
      statusCode: response.statusCode,
    );
  }

  String _responseMessage(String responseBody, String fallback) {
    try {
      final body = jsonDecode(responseBody);
      if (body is Map<String, dynamic> &&
          body['message'] is String &&
          (body['message'] as String).isNotEmpty) {
        return body['message'] as String;
      }
    } on FormatException {
      // Use the status-specific message for non-JSON responses.
    }
    return fallback;
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.profilePhoto,
  });

  final int id;
  final String name;
  final String email;
  final String? profilePhoto;
  final String token;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final email = json['email'];
    final token = json['token'];
    final profilePhoto = json['profile_photo'];
    if (id is! num ||
        name is! String ||
        email is! String ||
        token is! String ||
        token.isEmpty ||
        (profilePhoto != null && profilePhoto is! String)) {
      throw const AuthApiException('Respons login dari server tidak valid.');
    }
    return AuthUser(
      id: id.toInt(),
      name: name,
      email: email,
      profilePhoto: profilePhoto as String?,
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'profile_photo': profilePhoto,
    'token': token,
  };
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}
