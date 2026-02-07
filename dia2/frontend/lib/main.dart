import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/prediction_form_screen.dart';
import 'screens/prediction_result_screen.dart';
import 'screens/doctor_list_screen.dart';
import 'screens/book_appointment_screen.dart';
import 'screens/my_appointments_screen.dart';
import 'screens/prediction_history_screen.dart';
import 'screens/manage_slots_screen.dart';
import 'screens/appointment_details_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_screen.dart';
import 'screens/patient_list_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/doctor_reviews_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('access_token');
  final bool isLoggedIn = token != null && token.isNotEmpty;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiaPredict',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: isLoggedIn ? '/dashboard' : '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const MainScreen(),
        '/predict': (context) => const PredictionFormScreen(),
        '/prediction-result': (context) => const PredictionResultScreen(),
        '/doctor-list': (context) => const DoctorListScreen(),
        '/book-appointment': (context) => const BookAppointmentScreen(),
        '/my-appointments': (context) => const MyAppointmentsScreen(),
        '/prediction-history': (context) => const PredictionHistoryScreen(),
        '/manage-slots': (context) => const ManageSlotsScreen(),
        '/appointment-details': (context) => const AppointmentDetailsScreen(),
        '/patient-list': (context) => const PatientListScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/doctor-reviews': (context) => const DoctorReviewsScreen(),
      },
    );
  }
}

