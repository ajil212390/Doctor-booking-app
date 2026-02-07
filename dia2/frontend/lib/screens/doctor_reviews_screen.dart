import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/doctor_service.dart';
import '../theme/app_theme.dart';

class DoctorReviewsScreen extends StatefulWidget {
  const DoctorReviewsScreen({super.key});

  @override
  State<DoctorReviewsScreen> createState() => _DoctorReviewsScreenState();
}

class _DoctorReviewsScreenState extends State<DoctorReviewsScreen> {
  List<dynamic> _feedback = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    try {
      final feedback = await DoctorService().getDoctorFeedback();
      setState(() {
        _feedback = feedback;
        _isLoading = false;
      });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ALL FEEDBACK',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.5,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
              else if (_feedback.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Colors.white.withOpacity(0.1), size: 64),
                        const SizedBox(height: 16),
                        const Text('No feedback entries found', style: TextStyle(color: AppColors.silver500)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _feedback.length,
                    itemBuilder: (context, index) => _buildFeedbackCard(_feedback[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(dynamic f) {
    final patientName = f['patient_name'] ?? 'Verified User';
    final comment = f['feedback_text'] ?? '';
    final dateStr = f['created_at'] != null 
        ? DateFormat('MMMM d, yyyy').format(DateTime.parse(f['created_at']))
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.verified, color: const Color(0xFF10B981).withOpacity(0.5), size: 14),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: const TextStyle(color: AppColors.silver500, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Text(
              comment,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
