import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:ui';

class AppointmentDetailsScreen extends StatelessWidget {
  const AppointmentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appointment = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final name = appointment['doctor_name'] ?? appointment['patient_name'] ?? appointment['patient_full_name'] ?? 'Guest';
    final role = appointment['specialization'] ?? 'Specialist';
    
    // Support both nested and flat structures
    final slot = appointment['slot_details'] ?? {};
    final date = slot['date'] ?? appointment['appointment_date'] ?? appointment['date'] ?? 'Upcoming';
    final time = slot['start_time'] ?? appointment['start_time'] ?? 'Scheduled';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [

          
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildHeader(context),
                const SizedBox(height: 40),
                _buildDoctorInfo(name, role, date, time),
                const SizedBox(height: 48),
                _buildChecklistSection(),
                const SizedBox(height: 40),
                _buildHealthAnalysisSection(appointment),
                const SizedBox(height: 40),
                _buildFeedbackSection(appointment),
                const SizedBox(height: 140), // Space for bottom buttons
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
          
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.textOnSurface, size: 24),
          ),
        ),
        Text(
          'DETAILS',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.silver300, 
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 2
          ),
        ),
        Container(width: 44), // Spacer
      ],
    );
  }

  Widget _buildDoctorInfo(String name, String role, String date, String time) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: CircleAvatar(
            radius: 56,
            backgroundColor: AppColors.surface,
            child: Icon(
              Icons.person,
              color: AppColors.textOnSurface.withValues(alpha: 0.1),
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textOnBackground,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.silver500,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoItem(Icons.calendar_today, date),
              Container(
                height: 24,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: AppColors.border,
              ),
              _buildInfoItem(Icons.access_time, time),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.silver400, size: 16),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textOnSurface,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(Icons.chat_bubble_outline, 'Message'),
        _buildActionButton(Icons.videocam_outlined, 'Consult'),
        _buildActionButton(Icons.description_outlined, 'Records'),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textOnSurface, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.silver400, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildChecklistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APPOINTMENT STATUS',
          style: TextStyle(color: AppColors.textOnBackground, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
        ),
        const SizedBox(height: 24),
        _buildChecklistItem('Booking Confirmed', 'Completed', true),
        _buildChecklistItem('Clinical Review', 'Pending', false),
      ],
    );
  }

  Widget _buildChecklistItem(String title, String status, bool completed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: completed ? const Color(0xFF10B981).withValues(alpha: 0.1) : AppColors.textOnBackground.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check : Icons.more_horiz,
              color: completed ? const Color(0xFF10B981) : AppColors.silver600,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: completed ? AppColors.textOnBackground : AppColors.silver500,
                fontSize: 15,
                fontWeight: completed ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: completed ? const Color(0xFF10B981) : AppColors.silver600,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthAnalysisSection(Map<String, dynamic> apt) {
    final riskLevel = (apt['risk_level'] ?? 'Normal').toString().toUpperCase();
    final riskScore = apt['risk_score'] ?? '12.5';
    Color riskColor = Colors.greenAccent;
    if (riskLevel.contains('HIGH')) riskColor = Colors.redAccent;
    else if (riskLevel.contains('MODERATE')) riskColor = Colors.amberAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HEALTH ANALYSIS',
          style: TextStyle(color: AppColors.textOnBackground, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIABETES RISK: $riskLevel',
                        style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score: $riskScore',
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textOnSurface, fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.analytics_outlined, color: riskColor, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.75,
                  backgroundColor: AppColors.textOnBackground.withValues(alpha: 0.05),
                  color: riskColor,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackSection(Map<String, dynamic> apt) {
    final feedback = apt['comment'] ?? apt['feedback_text'] ?? apt['notes'] ?? 'No feedback provided yet.';
    final isActualFeedback = apt['comment'] != null || apt['feedback_text'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isActualFeedback ? 'PATIENT FEEDBACK' : 'CONSULTATION NOTES',
          style: const TextStyle(color: AppColors.textOnBackground, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(isActualFeedback ? Icons.chat_bubble_outline : Icons.note_alt_outlined, 
                           color: AppColors.silver400, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        isActualFeedback ? 'Patient Message' : 'Notes from Visit',
                        style: const TextStyle(color: AppColors.silver300, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (isActualFeedback)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final rating = (apt['rating'] as num?)?.toDouble() ?? 5.0;
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: index < rating ? Colors.amber : Colors.white10,
                          size: 14,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                feedback,
                style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.5), fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background.withValues(alpha: 0), AppColors.background.withValues(alpha: 0.9), AppColors.background],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textOnSurface,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
