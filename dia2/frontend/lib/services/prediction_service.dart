import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class PredictionService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Standard diabetes prediction (Pima dataset based)
  Future<Map<String, dynamic>> predict(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final response = await http.post(
      Uri.parse('${_baseUrl}${ApiConfig.predict}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'X-Tunnel-Skip-Anti-Phishing-Page': '1',
      },
      body: jsonEncode(data),
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData['data'];
    } else {
      throw Exception(responseData['message'] ?? 'Failed to get prediction');
    }
  }

  /// XGBoost model prediction (more comprehensive)
  Future<Map<String, dynamic>> predictXGBoost(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final response = await http.post(
      Uri.parse('${_baseUrl}${ApiConfig.predictXGBoost}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'X-Tunnel-Skip-Anti-Phishing-Page': '1',
      },
      body: jsonEncode(data),
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData['data'];
    } else {
      throw Exception(responseData['message'] ?? 'Failed to get prediction');
    }
  }

  /// Get standard prediction history
  Future<List<dynamic>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final response = await http.get(
      Uri.parse('${_baseUrl}${ApiConfig.predict}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData['data'] ?? [];
    } else {
      throw Exception(responseData['message'] ?? 'Failed to fetch history');
    }
  }

  /// Get XGBoost prediction history
  Future<List<dynamic>> getXGBoostHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final response = await http.get(
      Uri.parse('${_baseUrl}${ApiConfig.predictXGBoost}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData['success'] == true) {
      return responseData['data'] ?? [];
    } else {
      throw Exception(responseData['message'] ?? 'Failed to fetch history');
    }
  }
}
