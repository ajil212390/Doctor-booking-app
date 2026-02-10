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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textOnBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ALL FEEDBACK',
          style: TextStyle(color: AppColors.textOnBackground, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchFeedback,
        color: AppColors.textOnSurface,
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if (_isLoading && _feedback.isEmpty)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.textOnSurface)))
              else if (_feedback.isEmpty)
                Expanded(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, color: AppColors.textOnSurface.withValues(alpha: 0.1), size: 64),
                            const SizedBox(height: 16),
                            const Text('No feedback entries found', style: TextStyle(color: AppColors.silver500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
    final patientName = f['patient_name'] ?? f['user_name'] ?? 'Verified User';
    final comment = f['comment'] ?? f['feedback_text'] ?? '';
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(color: AppColors.textOnSurface, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.verified, color: const Color(0xFF10B981).withValues(alpha: 0.5), size: 14),
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
              style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.8), fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
