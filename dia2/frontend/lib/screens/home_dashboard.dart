import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/prediction_service.dart';
import '../services/doctor_service.dart';
import '../theme/app_theme.dart';
import 'doctor_dashboard.dart';

class HomeDashboard extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onPredictTap;
  
  const HomeDashboard({
    super.key, 
    this.onProfileTap,
    this.onPredictTap,
  });

  @override
  State<HomeDashboard> createState() => HomeDashboardState();
}

class HomeDashboardState extends State<HomeDashboard> {
  String _role = 'DOCTOR';
  String _name = 'Doctor';
  Map<String, dynamic>? _latestPrediction;
  List<dynamic> _doctors = [];
  List<dynamic> _appointments = [];
  bool _isHistoryLoading = true;
  bool _isDoctorsLoading = true;
  bool _isAppointmentsLoading = true;
  
  // Carousel logic
  late PageController _doctorPageController;
  int _currentDoctorPage = 0;
  Timer? _doctorTimer;

  @override
  void initState() {
    super.initState();
    _doctorPageController = PageController(viewportFraction: 0.9);
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserInfo();
    refresh();
  }

  void refresh([Map<String, dynamic>? newData]) {
    if (newData != null) {
      if (mounted) {
        setState(() {
          _latestPrediction = newData;
          _isHistoryLoading = false;
        });
      }
      // If we have manual data, we skip loading list to avoid race conditions with server
      _fetchDoctors();
      _fetchAppointments();
      _checkPendingReviews();
      return;
    }
    _loadLatestPrediction();
    _fetchDoctors();
    _fetchAppointments();
    _checkPendingReviews();
  }

  void _fetchAppointments() async {
    if (_role == 'DOCTOR') {
      if (mounted) setState(() => _isAppointmentsLoading = false);
      return;
    }
    
    if (mounted) setState(() => _isAppointmentsLoading = true);
    try {
      final appointments = await DoctorService().getUserAppointments();
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _isAppointmentsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isAppointmentsLoading = false);
    }
  }

  void _checkPendingReviews() async {
    if (_role == 'DOCTOR') return;
    
    try {
      final appointments = await DoctorService().getUserAppointments();
      // Find a completed appointment that hasn't been reviewed
      // Assuming the backend has a 'is_reviewed' flag or we can just try/check
      final pendingReview = appointments.firstWhere(
        (apt) => apt['status'] == 'COMPLETED' && apt['review_submitted'] != true,
        orElse: () => null,
      );

      if (pendingReview != null && mounted) {
        _showReviewDialog(pendingReview);
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _showReviewDialog(dynamic appointment) {
    final TextEditingController reviewController = TextEditingController();
    final doctorName = appointment['doctor_name'] ?? 'your doctor';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Text(
            'How was your consultation?',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share your experience with $doctorName.',
                style: GoogleFonts.plusJakartaSans(color: AppColors.silver400, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reviewController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter your feedback here...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('LATER', style: TextStyle(color: AppColors.silver500)),
            ),
            TextButton(
              onPressed: () async {
                if (reviewController.text.trim().isEmpty) return;
                
                try {
                  await DoctorService().submitFeedback(
                    appointmentId: appointment['id'],
                    feedback: reviewController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    AppToast.show(context, 'Thank you for your feedback!', isError: false);
                  }
                } catch (e) {
                  if (mounted) {
                    AppToast.show(context, 'Error: $e');
                  }
                }
              },
              child: const Text('SUBMIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _fetchDoctors() async {
    try {
      final doctors = await DoctorService().getApprovedDoctors();
      if (mounted) {
        // Prioritize doctors already consulted (in _appointments)
        final consultedDoctorNames = _appointments
            .map((apt) => apt['doctor_name']?.toString() ?? '')
            .toSet();

        List<dynamic> sortedDoctors = List.from(doctors);
        sortedDoctors.sort((a, b) {
          final aConsulted = consultedDoctorNames.contains(a['full_name']);
          final bConsulted = consultedDoctorNames.contains(b['full_name']);
          if (aConsulted && !bConsulted) return -1;
          if (!aConsulted && bConsulted) return 1;
          return 0;
        });

        setState(() {
          _doctors = sortedDoctors.take(5).toList();
          _isDoctorsLoading = false;
        });
        
        _startDoctorTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _isDoctorsLoading = false);
    }
  }

  void _startDoctorTimer() {
    _doctorTimer?.cancel();
    if (_doctors.isEmpty) return;
    
    _doctorTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_doctors.isEmpty) return;
      _currentDoctorPage = (_currentDoctorPage + 1) % _doctors.length;
      if (_doctorPageController.hasClients) {
        _doctorPageController.animateToPage(
          _currentDoctorPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutBack,
        );
      }
    });
  }

  @override
  void dispose() {
    _doctorTimer?.cancel();
    _doctorPageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _role = prefs.getString('user_role') ?? 'USER';
        _name = prefs.getString('user_name') ?? 'User';
      });
    }
  }

  void _loadLatestPrediction() async {
    try {
      final history = await PredictionService().getXGBoostHistory();
      if (history.isNotEmpty) {
        setState(() {
          _latestPrediction = history.first;
          _isHistoryLoading = false;
        });
      } else {
        setState(() => _isHistoryLoading = false);
      }
    } catch (e) {
      setState(() => _isHistoryLoading = false);
    }
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: AppColors.silver400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.silver500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
      }
    }
  }

  void _showRiskInfo() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Text(
            'RISK ANALYSIS',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'This health score is calculated using our AI model based on your clinical data, including glucose levels, HbA1c, and other health markers. It provides an estimate of your diabetes risk level.',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.silver400,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('GOT IT', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.8),
                radius: 1.5,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF0A0A0A),
                ],
              ),
            ),
          ),
          SafeArea(
            child: _buildDashboardByRole(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardByRole() {
    if (_role == 'ADMIN') return const Center(child: Text('Admin Dashboard'));
    if (_role == 'DOCTOR') return const DoctorDashboard();
    return _buildPatientDashboard();
  }

  Widget _buildPatientDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildRiskAssessmentCard(),
          const SizedBox(height: 24),
          _buildAppointmentsSection(),
          const SizedBox(height: 24),
          _buildHealthActivitySection(),
          const SizedBox(height: 100), // Padding for bottom nav
        ],
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome,',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.silver500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _name.toLowerCase(),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: widget.onProfileTap ?? () => Navigator.pushNamed(context, '/profile'),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3A3A3A), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.person,
              color: Colors.white.withOpacity(0.2),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskAssessmentCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: _latestPrediction == null 
        ? Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk Assessment',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Start your health journey',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.silver400, 
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_outlined, color: AppColors.silver300, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: widget.onPredictTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 15,
                            )
                          ]
                        ),
                        child: const Icon(Icons.add, color: Colors.black, size: 24),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'TAKE YOUR FIRST TEST',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk Assessment',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Next check in 14 days',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.silver400, 
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showRiskInfo,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.info_outline, color: AppColors.silver300, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: _parseNum(_latestPrediction!['probability']) / 100,
                          strokeWidth: 10,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
                            child: Text(
                              '${_parseNum(_latestPrediction!['probability']).toStringAsFixed(0)}%',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          Text(
                            (_latestPrediction!['risk_level'] as String? ?? 'LOW RISK').toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.silver400,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScoreRow('HEALTH SCORE', 
                          '${(100 - _parseNum(_latestPrediction!['probability'])).toStringAsFixed(0)}/100', 
                          Colors.white),
                      const SizedBox(height: 16),
                      _buildScoreRow('LAST UPDATE', 
                          _formatLastUpdate(_latestPrediction!['created_at']), 
                          AppColors.silver400.withOpacity(0.4)),
                    ],
                  ),
                ],
              ),
            ],
          ),
    );
  }

  double _parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Widget _buildScoreRow(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.silver500,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  String _formatLastUpdate(dynamic dateValue) {
    if (dateValue == null) return 'Recently';
    try {
      final date = DateTime.parse(dateValue.toString());
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildAppointmentsSection() {
    if (_role == 'DOCTOR') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_outlined, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  'My Appointments',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            if (_appointments.length > 2)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/my-appointments'),
                child: Text(
                  'View all',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.silver500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isAppointmentsLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white24))
        else if (_appointments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available, color: Colors.white.withOpacity(0.2), size: 24),
                const SizedBox(width: 16),
                const Text('No bookings yet', style: TextStyle(color: AppColors.silver500)),
              ],
            ),
          )
        else
          ..._appointments.take(2).map((apt) => _buildAppointmentCard(apt)),
      ],
    );
  }

  Widget _buildAppointmentCard(dynamic apt) {
    final status = apt['status']?.toString().toUpperCase() ?? 'PENDING';
    final isCompleted = status == 'COMPLETED';
    final hasReview = apt['review_submitted'] == true;
    final doctorName = apt['doctor_name'] ?? 'Specialist';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doctorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '${apt['date'] ?? apt['slot_details']?['date'] ?? 'Today'} • ${apt['start_time'] ?? apt['slot_details']?['start_time'] ?? 'Fixed'}',
                      style: const TextStyle(color: AppColors.silver500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasReview ? null : () => _showReviewDialog(apt),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasReview ? Colors.white10 : Colors.white,
                  foregroundColor: hasReview ? Colors.white24 : Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(hasReview ? Icons.check_circle_outline : Icons.rate_review_outlined, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      hasReview ? 'FEEDBACK SUBMITTED' : 'SHARE FEEDBACK',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.amber;
    if (status == 'COMPLETED') color = const Color(0xFF10B981);
    if (status == 'CANCELLED') color = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }


  Widget _buildHealthActivitySection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
              child: Text(
                'Available Specialists',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, 
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (_doctors.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/doctor-list'),
                child: Text(
                  'View all', 
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.silver500, 
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isDoctorsLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (_doctors.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.person_search_outlined, color: AppColors.silver500.withOpacity(0.5), size: 48),
                const SizedBox(height: 12),
                Text(
                  'No doctors available right now',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.silver500,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _doctorPageController,
              itemCount: _doctors.length,
              itemBuilder: (context, index) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildDoctorDashboardCard(_doctors[index]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDoctorDashboardCard(Map<String, dynamic> doc) {
    final String fullName = doc['full_name'] ?? 'Dr. Unknown';
    final String specialization = doc['qualification'] ?? doc['specialization'] ?? 'Specialist';
    
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
            ),
            child: Icon(
              Icons.person,
              color: Colors.white.withOpacity(0.2),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fullName.replaceAll('Dr. ', ''),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  specialization.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.silver500,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                    context, 
                    '/book-appointment', 
                    arguments: doc,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'BOOK NOW',
                      style: TextStyle(
                        color: Colors.black, 
                        fontSize: 9, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 0.5
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
