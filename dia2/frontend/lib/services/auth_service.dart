import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  final String _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}${ApiConfig.login}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'X-Tunnel-Skip-Anti-Phishing-Page': '1',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    
    // Check for empty response
    if (response.body.isEmpty) {
      throw 'Server returned empty response (Status: ${response.statusCode})';
    }
    
    // Try to parse JSON
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      throw 'Invalid response from server: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
    }
    
    if (response.statusCode == 200 && data['success'] == true) {
      final responseData = data['data'];
      await _saveSession(responseData['tokens'], responseData['user']);
      return responseData;
    } else {
      throw _parseError(data);
    }
  }

  /// Register a regular user (patient)
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}${ApiConfig.register}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'X-Tunnel-Skip-Anti-Phishing-Page': '1',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'role': role,
      }),
    );
    
    // Check for empty response
    if (response.body.isEmpty) {
      throw 'Server returned empty response (Status: ${response.statusCode})';
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      throw 'Invalid response from server: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
    }

    if (response.statusCode == 201 && data['success'] == true) {
      return data;
    } else {
      throw _parseError(data);
    }
  }

  /// Register a doctor (requires admin approval)
  Future<Map<String, dynamic>> registerDoctor({
    required String email,
    required String password,
    required String passwordConfirm,
    required String firstName,
    required String lastName,
    required String phone,
    required String specialization,
    required String qualification,
    required int experienceYears,
    required String licenseNumber,
    required String city,
    String? hospitalName,
    String? hospitalAddress,
    String? state,
    String? pincode,
    double? consultationFee,
    String? bio,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl}${ApiConfig.doctorRegister}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
        'X-Tunnel-Skip-Anti-Phishing-Page': '1',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'specialization': specialization,
        'qualification': qualification,
        'experience_years': experienceYears,
        'license_number': licenseNumber,
        'city': city,
        if (hospitalName != null) 'hospital_name': hospitalName,
        if (hospitalAddress != null) 'hospital_address': hospitalAddress,
        if (state != null) 'state': state,
        if (pincode != null) 'pincode': pincode,
        if (consultationFee != null) 'consultation_fee': consultationFee,
        if (bio != null) 'bio': bio,
      }),
    );
    
    // Check for empty response
    if (response.body.isEmpty) {
      throw 'Server returned empty response (Status: ${response.statusCode})';
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      throw 'Invalid response from server: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
    }

    if (response.statusCode == 201 && data['success'] == true) {
      return data;
    } else {
      throw _parseError(data);
    }
  }

  String _parseError(dynamic errorData) {
    if (errorData is Map) {
      // First, check for 'errors' object which contains field-specific errors
      if (errorData.containsKey('errors') && errorData['errors'] is Map) {
         final errors = errorData['errors'] as Map;
         final buffer = StringBuffer();
         errors.forEach((key, value) {
           if (value is List) {
             buffer.write('$key: ${value.join(", ")}\n');
           } else {
             buffer.write('$key: $value\n');
           }
         });
         return buffer.toString().trim();
      }

      if (errorData.containsKey('message')) return errorData['message'];
      if (errorData.containsKey('error')) return errorData['error'];
      if (errorData.containsKey('detail')) return errorData['detail'];
      
      // Fallback: show all fields
      final buffer = StringBuffer();
      errorData.forEach((key, value) {
        if (key != 'success') {
          if (value is List) {
            buffer.write('$key: ${value.join(", ")}\n');
          } else {
            buffer.write('$key: $value\n');
          }
        }
      });
      return buffer.toString().trim();
    }
    return 'Action failed';
  }

  Future<void> _saveSession(Map<String, dynamic> tokens, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', tokens['access']);
    await prefs.setString('refresh_token', tokens['refresh'] ?? '');
    await prefs.setString('user_role', user['role']);
    
    // Save any available name field
    final String displayName = user['first_name'] ?? user['username'] ?? user['email']?.split('@')[0] ?? 'Doctor';
    await prefs.setString('user_name', displayName);
    await prefs.setInt('user_id', user['id'] ?? 0);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
