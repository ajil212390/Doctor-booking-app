import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/prediction_service.dart';
import '../theme/app_theme.dart';

class PredictionHistoryScreen extends StatefulWidget {
  const PredictionHistoryScreen({super.key});

  @override
  State<PredictionHistoryScreen> createState() => _PredictionHistoryScreenState();
}

class _PredictionHistoryScreenState extends State<PredictionHistoryScreen> {
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = PredictionService().getXGBoostHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = PredictionService().getXGBoostHistory();
    });
    await _historyFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textOnBackground, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Prediction History',
          style: TextStyle(color: AppColors.textOnBackground, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.surface,
        backgroundColor: AppColors.background,
        child: FutureBuilder<List<dynamic>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.surface));
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.silver400)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refresh,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple, foregroundColor: Colors.white),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final history = snapshot.data!;
            if (history.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                   SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                   Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 64, color: AppColors.textOnSurface.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        const Text('No saved predictions found.', style: TextStyle(color: AppColors.silver400, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final riskLevel = item['risk_level'] as String? ?? 'UNKNOWN';
                final probabilityScore = (item['probability_score'] as num?)?.toDouble() ?? 0.0;
                final predictionResult = item['prediction_result'] as bool? ?? false;
                final createdAt = item['created_at']?.toString().split('T')[0] ?? 'Unknown';
                
                Color levelColor = Colors.greenAccent;
                if (riskLevel == 'HIGH') levelColor = Colors.redAccent;
                if (riskLevel == 'MEDIUM') levelColor = Colors.orangeAccent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: levelColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: levelColor.withOpacity(0.2)),
                        ),
                        child: Icon(
                          predictionResult ? Icons.warning_amber_rounded : Icons.health_and_safety_outlined,
                          color: levelColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  predictionResult ? 'DIABETIC' : 'NON-DIABETIC',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: levelColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  createdAt,
                                  style: const TextStyle(color: AppColors.silver500, fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Probability Score: ${(probabilityScore * 100).toStringAsFixed(1)}%',
                              style: TextStyle(color: AppColors.textOnSurface.withOpacity(0.7), fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    riskLevel,
                                    style: const TextStyle(fontSize: 10, color: AppColors.textOnSurface, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: (index * 50).ms, duration: 500.ms).slideY(begin: 0.1, end: 0);
              },
            );
          },
        ),
      ),
    );
  }
}
