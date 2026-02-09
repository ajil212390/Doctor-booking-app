import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class DoctorService {
  final String _baseUrl = ApiConfig.baseUrl;

  Future<List<dynamic>> getApprovedDoctors() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('${_baseUrl}${ApiConfig.approvedDoctors}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      // Backend returns list directly for ListAPIView
      return responseData is List ? responseData : (responseData['results'] ?? []);
    } else {
      throw Exception(responseData['message'] ?? 'Failed to fetch doctors');
    }
  }

  Future<Map<String, dynamic>> getSlots(int doctorId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('${_baseUrl}${ApiConfig.doctorSlots(doctorId)}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData['success'] == true) {
      // Returns {doctor: {...}, time_slots: [...]}
      return responseData['data'];
    } else {
      throw Exception(responseData['message'] ?? 'Failed to fetch slots');
    }
  }

  Future<void> bookAppointment({
    required int doctorId,
    required int timeSlotId,
    String? notes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.post(
      Uri.parse('${_baseUrl}${ApiConfig.userAppointments}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'X-Tunnel-Skip-Anti-Phishing-Page': '1',
      },
      body: jsonEncode({
        'doctor': doctorId,
        'time_slot': timeSlotId,
        if (notes != null) 'notes': notes,
      }),
    );

    if (response.body.isEmpty) throw 'Empty response from server';
    final responseData = jsonDecode(response.body);
    if (response.statusCode != 201 && responseData['success'] != true) {
      throw Exception(responseData['message'] ?? 'Booking failed');
    }
  }
  Future<List<dynamic>> getDoctorAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('${_baseUrl}${ApiConfig.doctorAppointments}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      // Backend returns list directly or in 'results'
      return responseData is List ? responseData : (responseData['results'] ?? responseData['data'] ?? []);
    } else {
      throw Exception(responseData['message'] ?? 'Failed to fetch appointments');
    }
  }

  /// Fetch the logged-in doctor's profile
  Future<Map<String, dynamic>> getDoctorProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('${_baseUrl}${ApiConfig.doctorProfile}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      // Handle both wrapped and direct response
      if (responseData is Map<String, dynamic>) {
        return responseData['data'] ?? responseData;
      }
      return responseData;
    } else {
      throw Exception(responseData['message'] ?? 'Failed to fetch doctor profile');
    }
  }
  /// Fetch the logged-in user's booked appointments
  Future<List<dynamic>> getUserAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('${_baseUrl}${ApiConfig.userAppointments}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData is List) return responseData;
        if (responseData is Map) {
          return responseData['results'] ?? responseData['data'] ?? responseData['appointments'] ?? [];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Mark an appointment as completed (Doctor only)
  Future<void> completeAppointment(int appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.patch(
      Uri.parse('${_baseUrl}${ApiConfig.doctorAppointmentUpdate(appointmentId)}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': 'COMPLETED'}),
    );

    if (response.statusCode != 200) {
      final responseData = jsonDecode(response.body);
      throw Exception(responseData['message'] ?? 'Failed to complete appointment');
    }
  }

  /// Submit feedback for an appointment (Patient only)
  Future<void> submitFeedback({required int appointmentId, required String feedback, double rating = 5.0}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    // Using POST to userFeedback endpoint instead of PATCH to appointment
    final response = await http.post(
      Uri.parse('${_baseUrl}${ApiConfig.userFeedback}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
        'X-Tunnel-Skip-Anti-Phishing-Page': '1',
      },
      body: jsonEncode({
        'appointment': appointmentId,
        'feedback_text': feedback,
        'rating': rating.toInt(),
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String errorMsg = 'Failed to submit feedback';
    try {
      if (response.body.isNotEmpty) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        errorMsg = responseData['message'] ?? responseData['detail'] ?? responseData.toString();
      }
    } catch (e) {
      errorMsg = 'Server error: ${response.statusCode}';
    }
    throw Exception(errorMsg);
  }

  /// Fetch feedback for the logged-in doctor
  Future<List<dynamic>> getDoctorFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('${_baseUrl}${ApiConfig.doctorFeedback}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (responseData is List) return responseData;
      return responseData['results'] ?? 
             responseData['data'] ?? 
             responseData['feedback'] ?? 
             responseData['reviews'] ?? 
             responseData['feedback_entries'] ?? [];
    } else {
      throw Exception(responseData['message'] ?? 'Failed to fetch feedback');
    }
  }

}
