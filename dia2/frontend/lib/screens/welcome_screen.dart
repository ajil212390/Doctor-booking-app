import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.background,
          ),



          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Illustration
                  _buildIllustration(),

                  const Spacer(flex: 2),

                  // Text Section
                  Column(
                    children: [
                      Text(
                        'DIAPREDICT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: AppColors.silver500,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 16),
                      Text(
                        'Predict your\nhealth future.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 48,
                          height: 1.1,
                          color: AppColors.textOnBackground,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 16),
                      Text(
                        'Advanced diabetes risk assessment powered by clinical data and intelligent insights.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: AppColors.silver400,
                          height: 1.4,
                        ),
                      ).animate().fadeIn(delay: 600.ms),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // Footer Buttons
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/register'),
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: AppColors.metallicGradient,
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'GET STARTED',
                              style: GoogleFonts.inter(
                                color: AppColors.textOnSurface,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 800.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.inter(color: AppColors.black, fontSize: 13), // Darker text for contrast
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: GoogleFonts.inter(
                                  color: AppColors.textOnBackground,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.textOnBackground.withOpacity(0.2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 1.seconds),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bottom Indicator
                  Container(
                    width: 120,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Rotated Square
          Transform.rotate(
            angle: 0.2, // ~12 degrees
            child: Container(
              width: 180,
              height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -0.2,
                    child: const Icon(
                      Icons.insights,
                      size: 72,
                      color: AppColors.textOnSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Secondary Square (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: Transform.rotate(
              angle: -0.1,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    color: AppColors.silver200,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // Circle (Bottom Left)
          Positioned(
            bottom: 10,
            left: 10,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(
                    Icons.query_stats,
                    color: AppColors.silver300,
                    size: 28,
                  ),
                ),
              ),
            ).animate().shimmer(duration: 3.seconds, delay: 1.seconds),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1.seconds).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}
