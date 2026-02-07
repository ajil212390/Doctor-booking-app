import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // Dev Tunnel URL provided by the user
    return 'https://5h44kl7q-8003.inc1.devtunnels.ms/api/';
  }
              
  // Auth Endpoints
  static const String login = 'auth/login/';
  static const String register = 'auth/register/';
  static const String doctorRegister = 'auth/register/doctor/';
  static const String tokenRefresh = 'auth/token/refresh/';

  // User Endpoints
  static const String userProfile = 'user/profile/';
  static const String approvedDoctors = 'user/doctors/';
  static String doctorSlots(int doctorId) => 'user/doctors/$doctorId/slots/';
  static const String userAppointments = 'user/appointments/';
  static String userAppointmentDetail(int appointmentId) => 'user/appointments/$appointmentId/';
  static const String userFeedback = 'user/feedback/';
  static const String medicalHistory = 'user/medical-history/';
  static String medicalHistoryDetail(int historyId) => 'user/medical-history/$historyId/';
  static const String healthParams = 'user/health-params/';
  static const String predict = 'user/predict/';
  static const String predictXGBoost = 'user/predict/xgboost/';

  // Doctor Endpoints
  static const String doctorProfile = 'doctor/profile/';
  static const String doctorAvailability = 'doctor/availability/';
  static const String doctorTimeSlots = 'doctor/timeslots/';
  static const String doctorAppointments = 'doctor/appointments/';
  static String doctorAppointmentUpdate(int appointmentId) => 'doctor/appointments/$appointmentId/';
  static const String doctorFeedback = 'doctor/feedback/';
}
