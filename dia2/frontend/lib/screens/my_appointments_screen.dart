import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../services/doctor_service.dart';
import '../theme/app_theme.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final String _baseUrl = ApiConfig.baseUrl;
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  String _role = 'USER';

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    _role = prefs.getString('user_role') ?? 'USER';

    try {
      final List<dynamic> appointments = (_role == 'DOCTOR') 
          ? await DoctorService().getDoctorAppointments()
          : await DoctorService().getUserAppointments();
          
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_added_outlined, color: Colors.white.withOpacity(0.5), size: 18),
            const SizedBox(width: 8),
            const Text(
              'Bookings',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAppointments,
        color: Colors.white,
        backgroundColor: const Color(0xFF1A1A1A),
        child: _isLoading && _appointments.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _appointments.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                   SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                   Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        const Text('No appointments found.', style: TextStyle(color: AppColors.silver400, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: _appointments.length + 1,
                itemBuilder: (context, index) {
                if (index == _appointments.length) {
                  return const SizedBox(height: 120);
                }
                final appt = _appointments[index];
                final isDoctor = _role == 'DOCTOR';
                final date = appt['date'] ?? appt['slot_details']?['date'] ?? 'N/A';
                final time = appt['start_time'] ?? appt['slot_details']?['start_time'] ?? 'N/A';
                final status = appt['status'];
                final name = isDoctor ? appt['patient_name'] : appt['doctor_name'];
                
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/appointment-details', arguments: appt),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 12, color: AppColors.silver300),
                                    const SizedBox(width: 8),
                                    Text('$date • $time', style: const TextStyle(fontSize: 10, color: AppColors.silver200, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                name ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                              ),
                              Text(
                                isDoctor ? 'Patient' : 'Specialist',
                                style: const TextStyle(color: AppColors.silver400, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _getStatusColor(status).withOpacity(0.2)),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Center(
                            child: Text(
                              name != null && name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (index * 100).ms, duration: 500.ms).slideX(begin: -0.1, end: 0);
              },
            ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.greenAccent;
      case 'pending': return Colors.orangeAccent;
      case 'cancelled': return Colors.redAccent;
      default: return Colors.white60;
    }
  }
}
