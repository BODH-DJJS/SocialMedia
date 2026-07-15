import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String _username = '';
  String _role = '';
  bool _isLoading = false;

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get role => _role;
  bool get isLoading => _isLoading;

  final ApiService _apiService = ApiService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '450712868870-mf4vklm9g84jcbk5nf02r70ks5rubm1g.apps.googleusercontent.com',
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _username = prefs.getString('username') ?? '';
    _role = prefs.getString('role') ?? '';
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.postData({
        'action': 'login',
        'username': username,
        'password': password,
      });

      if (response['success'] == true) {
        _isLoggedIn = true;
        _username = response['username'] ?? username;
        _role = response['role'] ?? 'User';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', _username);
        await prefs.setString('role', _role);

        _isLoading = false;
        notifyListeners();
        return null; // No error
      } else {
        _isLoading = false;
        notifyListeners();
        return response['message'] ?? 'Login failed';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'Network error: $e';
    }
  }

  Future<String?> googleLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('Starting Google Sign-In...');
      final account = await _googleSignIn.signIn();
      if (account == null) {
        print('Sign-in aborted by user (account is null)');
        _isLoading = false;
        notifyListeners();
        return 'Sign-in aborted by user';
      }
      print('Google Sign-In success! Email: ${account.email}, Name: ${account.displayName}');

      final payload = {
        'action': 'login',
        'email': account.email,
        'displayName': account.displayName,
      };
      print('Sending payload to Apps Script: $payload');

      final response = await _apiService.postData(payload);
      print('Apps Script Response: $response');

      if (response['success'] == true) {
        _isLoggedIn = true;
        _username = account.email; // Use email as identifier in Flutter
        _role = response['role'] ?? 'User';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', _username);
        await prefs.setString('role', _role);

        _isLoading = false;
        notifyListeners();
        print('Login complete, navigating to dashboard...');
        return null;
      } else {
        await _googleSignIn.signOut();
        _isLoading = false;
        notifyListeners();
        print('Apps script rejected login: ${response['message']}');
        return response['message'] ?? 'Login failed';
      }
    } catch (e) {
      print('Google Sign-In Exception thrown: $e');
      _isLoading = false;
      notifyListeners();
      return 'Google Sign-In Error: $e';
    }
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _username = '';
    _role = '';
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
