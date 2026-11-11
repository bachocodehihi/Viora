import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../l10n/language.dart';

class SignUpProvider extends ChangeNotifier {
  String? _email;
  String? _username;
  DateTime? _birthday;
  String? _gender;
  String? _password;
  File? _avatarFile;

  bool _isLoading = false;

  String? get email => _email;
  String? get username => _username;
  DateTime? get birthday => _birthday;
  String? get gender => _gender;
  String? get password => _password;
  File? get avatarFile => _avatarFile;
  bool get isLoading => _isLoading;

  void setEmail(String value) {
    _email = value;
    notifyListeners();
  }

  void setUsername(String value) {
    _username = value;
    notifyListeners();
  }

  void setBirthday(DateTime value) {
    _birthday = value;
    notifyListeners();
  }

  void setGender(String value) {
    _gender = value;
    notifyListeners();
  }

  void setPassword(String value) {
    _password = value;
    notifyListeners();
  }

  void setAvatarFile(File? file) {
    _avatarFile = file;
    notifyListeners();
  }

  void reset() {
    _email = null;
    _username = null;
    _birthday = null;
    _gender = null;
    _password = null;
    _avatarFile = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> submitRegistration() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_email == null || _username == null || _birthday == null || _gender == null || _password == null) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Missing registration information, please check again!',
          'code': 'MISSING_FIELDS'
        };
      }

      final bodyData = {
        'email': _email!.trim(),
        'username': _username!.trim(),
        'password': _password!,
        'birthday': _birthday!.toIso8601String(),
        'gender': _gender!,
        'language': LanguageManager.localeNotifier.value.languageCode,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 15));

      _isLoading = false;
      notifyListeners();

      Map<String, dynamic> responseData = {};
      try {
        responseData = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Account registered successfully!',
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Sign up failed',
          'code': responseData['code'] ?? 'SIGN_UP_FAILED',
        };
      }
    } on SocketException {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Cannot connect to server. Please check your network connection!',
        'code': 'NETWORK_ERROR'
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again later!',
        'code': 'UNKNOWN_ERROR'
      };
    }
  }
}
