import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/prediction_service.dart';
import '../theme/app_theme.dart';

class PredictionFormScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onPredictionCompleted;
  const PredictionFormScreen({super.key, this.onPredictionCompleted});

  @override
  State<PredictionFormScreen> createState() => _PredictionFormScreenState();
}

class _PredictionFormScreenState extends State<PredictionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _bmiController = TextEditingController();
  final _hbA1cController = TextEditingController();
  final _glucoseController = TextEditingController();
  
  String _gender = 'Male';
  int _hypertension = 0;
  int _heartDisease = 0;
  String _smokingHistory = 'never';
  
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final result = await PredictionService().predictXGBoost({
        'gender': _gender,
        'age': double.parse(_ageController.text),
        'hypertension': _hypertension,
        'heart_disease': _heartDisease,
        'smoking_history': _smokingHistory,
        'bmi': double.parse(_bmiController.text),
        'hba1c_level': double.parse(_hbA1cController.text),
        'blood_glucose_level': double.parse(_glucoseController.text),
      });
      if (mounted) {
        if (widget.onPredictionCompleted != null) {
          widget.onPredictionCompleted!(result);
        }
        Navigator.pushNamed(context, '/prediction-result', arguments: result);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(
            'RISK ASSESSMENT',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textOnSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Provide your clinical details such as glucose levels, blood pressure (hypertension), and HbA1c to receive an AI-powered assessment of your diabetes risk.',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.silver400,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('GOT IT', style: TextStyle(color: AppColors.textOnSurface)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.background,
          ),
          
          SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10), // Minimal spacer since SafeArea handles the top
                    Text(
                      'Clinical Data',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.textOnBackground,
                        letterSpacing: -1,
                      ),
                    ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                    const SizedBox(height: 8),
                    Text(
                      'Enter patient metrics for AI-powered risk analysis.',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.silver500, 
                        fontSize: 14,
                        height: 1.5
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 40),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('GENDER'),
                        _buildDropdownGender(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('AGE'),
                        _buildTextField(_ageController, 'e.g. 45', keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _buildSwitchCard(
                'Hypertension',
                'History of high blood pressure',
                Icons.monitor_heart,
                _hypertension == 1,
                (val) => setState(() => _hypertension = val ? 1 : 0),
              ),
              const SizedBox(height: 12),
              _buildSwitchCard(
                'Heart Disease',
                'Any cardiovascular conditions',
                Icons.favorite,
                _heartDisease == 1,
                (val) => setState(() => _heartDisease = val ? 1 : 0),
              ),
              const SizedBox(height: 24),
              
              _buildLabel('SMOKING HISTORY'),
              _buildDropdownSmoking(),
              const SizedBox(height: 16),
              
              _buildLabel('BODY MASS INDEX (BMI)'),
              _buildTextField(_bmiController, '24.5', suffix: 'kg/m²', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('HBA1C LEVEL'),
                        _buildTextField(_hbA1cController, '5.7', suffix: '%', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('BLOOD GLUCOSE'),
                        _buildTextField(_glucoseController, '140', suffix: 'mg/dL', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              
              _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.surface))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.analytics_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('RUN RISK ANALYSIS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 120), // Padding for bottom nav
                ],
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
        ),
      ],
    ),
  );
}

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.silver500,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {String? suffix, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (v) => v!.isEmpty ? 'Required' : null,
      style: const TextStyle(color: AppColors.textOnSurface, fontSize: 14),
      decoration: InputDecoration(
        hintStyle: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.2)),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: AppColors.silver500, fontSize: 12),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildSwitchCard(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textOnSurface, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textOnSurface)),
                Text(subtitle, style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.textOnSurface,
            activeTrackColor: AppColors.silver400,
            inactiveThumbColor: AppColors.textOnSurface.withValues(alpha: 0.6),
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownGender() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textOnSurface),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (val) => setState(() => _gender = val!),
        ),
      ),
    );
  }

  Widget _buildDropdownSmoking() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _smokingHistory,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textOnSurface),
          items: const [
            DropdownMenuItem(value: 'never', child: Text('Never')),
            DropdownMenuItem(value: 'former', child: Text('Former')),
            DropdownMenuItem(value: 'current', child: Text('Current')),
            DropdownMenuItem(value: 'ever', child: Text('Ever')),
            DropdownMenuItem(value: 'not current', child: Text('Not Current')),
            DropdownMenuItem(value: 'No Info', child: Text('No Info')),
          ],
          onChanged: (val) => setState(() => _smokingHistory = val!),
        ),
      ),
    );
  }
}
