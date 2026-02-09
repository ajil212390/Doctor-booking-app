import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class PredictionResultScreen extends StatelessWidget {
  const PredictionResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    
    // Backend returns: prediction, probability, risk_level, risk_level_display
    final prediction = result['prediction'] as String? ?? 'Unknown';
    final probability = (result['probability'] as num?)?.toDouble() ?? 0.0;
    final riskLevel = result['risk_level'] as String? ?? 'UNKNOWN';
    final riskLevelDisplay = result['risk_level_display'] as String? ?? riskLevel;

    // Convert probability to percentage
    final score = probability * 100;

    final dateStr = result['created_at'] as String?;
    final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    final formattedDate = DateFormat('MMMM d, yyyy • h:mm a').format(date);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
          ),
        ),
        title: Text(
          'ASSESSMENT RESULT',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white, 
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 2
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1),
                radius: 1.5,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF0A0A0A),
                ],
              ),
            ),
          ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildGaugeCard(riskLevelDisplay, score),
                const SizedBox(height: 40),
                _buildMetricsSection(result),
                const SizedBox(height: 32),
                _buildInsightCard(riskLevel),
                const SizedBox(height: 48),
                _buildActionButtons(context, riskLevel),
                const SizedBox(height: 40),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildGaugeCard(String riskLevel, double score) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Gauge implementation
          SizedBox(
            height: 140,
            width: 240,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(240, 120),
                  painter: GaugePainter(score / 100),
                ),
                Positioned(
                  bottom: 20,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
                        child: Text(
                          riskLevel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        'RISK PROFILE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Progress bar indicators
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(1),
            ),
            child: Row(
              children: [
                Expanded(child: Container(color: Colors.white.withOpacity(score > 33 ? 0.3 : 0.05))),
                Expanded(child: Container(color: Colors.white.withOpacity(score > 66 ? 0.6 : 0.05))),
                Expanded(child: Container(color: Colors.white.withOpacity(score > 90 ? 1.0 : 0.05))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGaugeLabel('LOW', score <= 33),
                _buildGaugeLabel('MODERATE', score > 33 && score <= 66),
                _buildGaugeLabel('HIGH', score > 66),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeLabel(String text, bool active) {
    return Text(
      text,
      style: TextStyle(
        color: active ? Colors.white : Colors.white.withOpacity(0.2),
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildMetricsSection(Map<String, dynamic> result) {
    // These values would ideally come from the prediction input
    // For now showing placeholders or extracting if available
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'PRIMARY METRICS',
            style: TextStyle(
              color: AppColors.silver500,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        _buildMetricItem('HbA1c Levels', 'Value: ${result['input_hba1c'] ?? "6.2"}% (Pre-diabetic)', Icons.science),
        const SizedBox(height: 12),
        _buildMetricItem('Body Mass Index', 'BMI of ${result['input_bmi'] ?? "27.4"} (Overweight)', Icons.monitor_weight),
      ],
    );
  }

  Widget _buildMetricItem(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: AppColors.silver300, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.info_outline, color: Colors.white.withOpacity(0.2), size: 14),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String riskLevel) {
    String insight = "Low risk detected. Continue your healthy lifestyle and regular checkups.";
    if (riskLevel == 'MEDIUM') {
      insight = "Moderate risk detected. Improving glycemic control through diet and monitored exercise can significantly lower future risks.";
    } else if (riskLevel == 'HIGH') {
      insight = "High risk detected. Immediate medical consultation recommended. Closely monitor glucose levels and follow professional guidance.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.05), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.lightbulb_outline, color: AppColors.silver300, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Professional Insight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  insight,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String riskLevel) {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/dashboard', 
              (route) => false,
            );
          },
          child: Text(
            'RETURN HOME',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class GaugePainter extends CustomPainter {
  final double value; // 0.0 to 1.0

  GaugePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Progress track
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // Gradient for progress
    progressPaint.shader = SweepGradient(
      colors: [
        Colors.white.withOpacity(0.3),
        Colors.white.withOpacity(0.8),
        Colors.white,
      ],
      startAngle: math.pi,
      endAngle: 2 * math.pi,
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius - 6));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      math.pi,
      math.pi * value,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
