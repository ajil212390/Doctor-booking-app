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
  List<dynamic> _appointments = [];
  bool _isHistoryLoading = true;
  bool _isAppointmentsLoading = true;
  final Set<int> _dismissedReviewIds = {};
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserInfo();
    refresh();
  }

  Future<void> refresh([Map<String, dynamic>? newData]) async {
    if (newData != null) {
      if (mounted) {
        setState(() {
          _latestPrediction = newData;
          _isHistoryLoading = false;
        });
      }
      _fetchAppointments();
      return;
    }
    await Future.wait([
      Future.sync(() => _loadLatestPrediction()),
      Future.sync(() => _fetchAppointments()),
    ]);
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

  void checkPendingReviews() async {
    if (_role == 'DOCTOR') return;
    
    try {
      final appointments = await DoctorService().getUserAppointments();
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      final pendingReview = appointments.firstWhere(
        (apt) {
          final id = apt['id'] as int?;
          if (id == null || _dismissedReviewIds.contains(id)) return false;
          
          // Backend check: already submitted
          if (apt['review_submitted'] == true) return false;
          
          // Frontend check: permanently dismissed
          final isDismissed = prefs.getBool('review_dismissed_$id') ?? false;
          if (isDismissed) return false;
          
          final status = apt['status']?.toString().toUpperCase() ?? 'PENDING';
          final isCompleted = status == 'COMPLETED';
          
          // Time expiry logic
          bool isExpired = false;
          try {
            final slot = apt['slot_details'] ?? {};
            final dateStr = (apt['date'] ?? slot['date'])?.toString() ?? '';
            final timeStr = (apt['end_time'] ?? slot['end_time'] ?? '23:59')?.toString() ?? '23:59';
            
            if (dateStr.isNotEmpty) {
              final cleanDate = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr.split(' ')[0];
              final appointmentEnd = DateTime.parse('${cleanDate} $timeStr');
              isExpired = now.isAfter(appointmentEnd);
            }
          } catch (_) {}

          // Rule: Show only if doctor marked COMPLETED AND the time is over
          return isCompleted && isExpired;
        },
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
    final int appointmentId = appointment['id'];
    double currentRating = 5.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share your experience with $doctorName.',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.silver400, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: StarRating(
                      rating: currentRating,
                      onRatingChanged: (rating) => setDialogState(() => currentRating = rating),
                    ),
                  ),
                  const SizedBox(height: 24),
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
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  _dismissedReviewIds.add(appointmentId);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('review_dismissed_$appointmentId', true);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('LATER', style: TextStyle(color: AppColors.silver500)),
              ),
              TextButton(
                onPressed: () async {
                  final text = reviewController.text.trim();
                  
                  try {
                    await DoctorService().submitFeedback(
                      appointmentId: appointmentId,
                      feedback: text.isEmpty ? "Great consultation!" : text, // Default text if empty
                      rating: currentRating,
                    );
                    _dismissedReviewIds.add(appointmentId);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('review_dismissed_$appointmentId'); // Clear dismissal on success
                    if (mounted) {
                      Navigator.pop(context);
                      AppToast.show(context, 'Success! Feedback shared.', isError: false);
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
      ),
    );
  }


  @override
  void dispose() {
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
        // Sort by created_at DESC to ensure we get the latest
        history.sort((a, b) {
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        
        if (mounted) {
          setState(() {
            _latestPrediction = history.first;
            _isHistoryLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isHistoryLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isHistoryLoading = false);
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
    return RefreshIndicator(
      onRefresh: () => refresh(),
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildRiskAssessmentCard(),
            const SizedBox(height: 24),
            _buildAppointmentsSection(),
            const SizedBox(height: 100), // Padding for bottom nav
          ],
        ),
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
                          value: _getDisplayProbability() / 100,
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
                              '${_getDisplayProbability().toStringAsFixed(0)}%',
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
                          '${(100 - _getDisplayProbability()).toStringAsFixed(0)}/100', 
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

  double _getDisplayProbability() {
    if (_latestPrediction == null) return 0.0;
    final raw = _latestPrediction!['probability'] ?? _latestPrediction!['probability_score'];
    double val = _parseNum(raw);
    // If val is 0.85, it's a fraction, convert to 85.
    // If it's already 85, keep it.
    if (val > 0 && val <= 1.0) return val * 100;
    return val;
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
    
    // Logic for feedback button visibility
    final now = DateTime.now();
    bool isExpired = false;
    try {
      final slot = apt['slot_details'] ?? {};
      final dateStr = (apt['date'] ?? slot['date'])?.toString() ?? '';
      final timeStr = (apt['end_time'] ?? slot['end_time'] ?? '23:59')?.toString() ?? '23:59';
      if (dateStr.isNotEmpty) {
        final cleanDate = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr.split(' ')[0];
        final appointmentEnd = DateTime.parse('${cleanDate} $timeStr');
        isExpired = now.isAfter(appointmentEnd);
      }
    } catch (_) {}

    final showFeedbackButton = (isCompleted || (isExpired && status != 'CANCELLED')) && !hasReview;

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
          if (showFeedbackButton || hasReview) ...[
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


}

class StarRating extends StatelessWidget {
  final double rating;
  final Function(double) onRatingChanged;

  const StarRating({super.key, required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => onRatingChanged(index + 1.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: index < rating ? Colors.amber : Colors.white24,
              size: 32,
            ),
          ),
        );
      }),
    );
  }
}
