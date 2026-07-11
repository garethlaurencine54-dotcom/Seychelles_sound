import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LinkAuthResult {
  final bool success;
  final String? error;
  LinkAuthResult({required this.success, this.error});
}

class LinkAuthService {
  static const String backendUrl = "https://seyinfo.seychellesxstream.com";
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "link_session_token";

  Future<String?> getSavedToken() => _storage.read(key: _tokenKey);

  Future<void> _saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> logout() => _storage.delete(key: _tokenKey);

  /// First-time pairing: Link ID + new password + confirmation.
  Future<LinkAuthResult> setupPassword(String linkId, String password, String confirmPassword) async {
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/api/v1/link/setup-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "link_id": linkId,
          "password": password,
          "confirm_password": confirmPassword,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data["token"] != null) {
        await _saveToken(data["token"]);
        return LinkAuthResult(success: true);
      }
      return LinkAuthResult(success: false, error: data["error"] ?? "Setup failed.");
    } catch (e) {
      return LinkAuthResult(success: false, error: "Network error: $e");
    }
  }

  /// Returning user: Link ID + existing password.
  Future<LinkAuthResult> login(String linkId, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$backendUrl/api/v1/link/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"link_id": linkId, "password": password}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["token"] != null) {
        await _saveToken(data["token"]);
        return LinkAuthResult(success: true);
      }
      if (data["error"] == "no_password_set") {
        return LinkAuthResult(success: false, error: "no_password_set");
      }
      return LinkAuthResult(success: false, error: data["error"] ?? "Login failed.");
    } catch (e) {
      return LinkAuthResult(success: false, error: "Network error: $e");
    }
  }
}
