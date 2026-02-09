import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/doctor_service.dart';
import '../theme/app_theme.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  String _doctorName = 'Ramen';
  List<dynamic> _appointments = [];
  List<dynamic> _feedback = [];
  bool _isLoading = true;
  bool _isLoadingFeedback = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadDoctorName();
    await _fetchAppointments();
    await _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    try {
      final feedbackList = await DoctorService().getDoctorFeedback();
      
      // Also try to extract feedback from appointments as a fallback
      final List<dynamic> aggregatedFeedback = List.from(feedbackList);
      
      for (var apt in _appointments) {
        // Try multiple keys for feedback text
        final fText = apt['comment'] ?? apt['feedback_text'] ?? apt['feedback'] ?? (apt['review'] is Map ? apt['review']['text'] : null);
        final ratingVal = apt['rating'] ?? (apt['review'] is Map ? apt['review']['rating'] : null);
        
        // If we found either text OR a rating, it's feedback
        if ((fText != null && fText.toString().trim().isNotEmpty) || ratingVal != null) {
          bool exists = aggregatedFeedback.any((f) => f['id'] == apt['id'] || 
                                                     (f['appointment_id'] == apt['id']) ||
                                                     (fText != null && (f['comment'] == fText || f['feedback_text'] == fText)));
          if (!exists) {
            aggregatedFeedback.add({
              'id': apt['id'],
              'patient_name': apt['patient_name'] ?? apt['patient_full_name'] ?? (apt['patient'] is Map ? apt['patient']['full_name'] : 'Patient'),
              'comment': fText ?? 'Rating only',
              'rating': ratingVal ?? 5.0,
              'created_at': apt['updated_at'] ?? apt['date'] ?? apt['created_at'],
            });
          }
        }
      }

      if (mounted) {
        // Sort by date DESC
        aggregatedFeedback.sort((a, b) {
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        
        setState(() {
          _feedback = aggregatedFeedback;
          _isLoadingFeedback = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFeedback = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
      _isLoadingFeedback = true;
    });
    await _fetchAppointments();
    await _fetchFeedback();
  }

  Future<void> _fetchAppointments() async {
    try {
      final appointments = await DoctorService().getDoctorAppointments();
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDoctorName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'Ramen';
    setState(() {
      _doctorName = name.startsWith('Dr.') ? name : 'Dr. $name';
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.5,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.white,
            backgroundColor: const Color(0xFF1A1A1A),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildDailyForecastCard(),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 32),
                  _buildFeedbackSection(),
                  const SizedBox(height: 120), // Bottom nav space
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
              child: Text(
                _doctorName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'DIAPREDICT',
              style: TextStyle(
                color: AppColors.silver400,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
              ),
              child: Icon(
                Icons.person,
                color: Colors.white.withOpacity(0.2),
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyForecastCard() {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final todaysAppointments = _appointments.where((apt) {
      final slot = apt['slot_details'] ?? {};
      final rawDate = (apt['date'] ?? slot['date'])?.toString() ?? '';
      final cleanDate = rawDate.contains('T') ? rawDate.split('T')[0] : rawDate.split(' ')[0];
      
      if (cleanDate != todayStr) return false;

      // Filter out completed appointments if they should be "removed"
      if (apt['status'] == 'COMPLETED') return false;

      // Filter out past appointments for today
      try {
        String timeStr = apt['start_time'] ?? slot['start_time'] ?? '00:00';
        final appointmentDateTime = DateTime.parse('${cleanDate}T$timeStr');
        // Give a 1 hour grace period or just strict future
        return appointmentDateTime.isAfter(now.subtract(const Duration(hours: 1)));
      } catch (e) {
        return true;
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TODAY',
                    style: TextStyle(
                      color: AppColors.silver500,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
                    child: Text(
                      '${todaysAppointments.length} Appointments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_outlined, color: AppColors.silver200, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (todaysAppointments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.event_available_outlined, color: AppColors.silver500.withOpacity(0.5), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'No appointments today',
                    style: TextStyle(
                      color: AppColors.silver500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ...todaysAppointments.take(3).map((appointment) {
              final slot = appointment['slot_details'] ?? {};
              final startTime = appointment['start_time'] ?? slot['start_time'] ?? '09:00';
              final patientName = appointment['patient_name'] ?? 
                                 appointment['patient_full_name'] ?? 
                                 'Patient';
              final notes = appointment['notes'] ?? 'General Checkup';
              
              // Simple time parsing for AM/PM
              final cleanTime = startTime.contains('T') ? startTime.split('T')[1] : startTime;
              final parts = cleanTime.split(':');
              int hour = int.tryParse(parts[0]) ?? 9;
              final minute = parts.length > 1 ? parts[1] : '00';
              String period = hour >= 12 ? 'PM' : 'AM';
              if (hour > 12) hour -= 12;
              if (hour == 0) hour = 12;
              String formattedTime = '${hour.toString().padLeft(2, '0')}:${minute.substring(0, 2)}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context, 
                    '/appointment-details',
                    arguments: appointment,
                  ),
                  child: _buildAppointmentItem(formattedTime, period, patientName, notes, false),
                ),
              );
            }).toList(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAppointmentItem(String time, String period, String name, String type, bool last) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                time,
                style: const TextStyle(color: AppColors.silver500, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                period,
                style: const TextStyle(color: AppColors.silver200, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: const TextStyle(color: AppColors.silver500, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.silver500, size: 18),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/manage-slots'),
            child: _buildGlassButton(Icons.event_available, 'Availability'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/patient-list'),
            child: _buildGlassButton(Icons.list_alt, 'View Schedule'),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined, color: AppColors.silver500, size: 14),
                const SizedBox(width: 8),
                const Text(
                  'PATIENT FEEDBACK',
                  style: TextStyle(
                    color: AppColors.silver500,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            if (_feedback.length > 3)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/doctor-reviews'),
                child: const Text('View all', style: TextStyle(color: AppColors.silver300, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingFeedback)
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        else if (_feedback.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.white.withOpacity(0.1), size: 32),
                const SizedBox(height: 12),
                const Text(
                  'No feedback yet',
                  style: TextStyle(color: AppColors.silver500, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ..._feedback.take(3).map((f) => _buildFeedbackCard(f)).toList(),
      ],
    );
  }

  Widget _buildFeedbackCard(dynamic f) {
    final patientName = f['patient_name'] ?? f['user_name'] ?? 'Verified User';
    final comment = f['comment'] ?? f['feedback_text'] ?? '';
    final dateStr = f['created_at'] != null 
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(f['created_at']))
        : 'Recently';

    return GestureDetector(
      onTap: () {
        if (f['appointment_details'] != null) {
          Navigator.pushNamed(context, '/appointment-details', arguments: f['appointment_details']);
        } else if (f['appointment'] != null && f['appointment'] is Map) {
          Navigator.pushNamed(context, '/appointment-details', arguments: f['appointment']);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final rating = (f['rating'] as num?)?.toDouble() ?? 5.0;
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: index < rating ? Colors.amber : Colors.white10,
                      size: 10,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              dateStr,
              style: const TextStyle(color: AppColors.silver500, fontSize: 9),
            ),
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
