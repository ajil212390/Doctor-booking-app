import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Doctor-specific fields
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _licenseController = TextEditingController();
  final _cityController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _hospitalAddressController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _bioController = TextEditingController();
  String _specialization = 'DIABETOLOGIST';
  
  String _selectedRole = 'USER';
  bool _isRoleInitialized = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRoleInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['role'] != null) {
        setState(() {
          _selectedRole = args['role'];
        });
      }
      _isRoleInitialized = true;
    }
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _passwordConfirmController.text) {
      AppToast.show(context, 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_selectedRole == 'DOCTOR') {
        await AuthService().registerDoctor(
          email: _emailController.text,
          password: _passwordController.text,
          passwordConfirm: _passwordConfirmController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          phone: _phoneController.text,
          specialization: _specialization,
          qualification: _qualificationController.text,
          experienceYears: int.tryParse(_experienceController.text) ?? 0,
          licenseNumber: _licenseController.text,
          city: _cityController.text,
          consultationFee: double.tryParse(_consultationFeeController.text),
          hospitalName: _hospitalNameController.text,
          hospitalAddress: _hospitalAddressController.text,
          state: _stateController.text,
          pincode: _pincodeController.text,
          bio: _bioController.text,
        );
        if (mounted) {
          AppToast.show(context, 'Registration submitted! Please wait for admin approval.', isError: false);
          Navigator.pop(context);
        }
      } else {
        final result = await AuthService().register(
          email: _emailController.text,
          password: _passwordController.text,
          passwordConfirm: _passwordConfirmController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          phone: _phoneController.text,
          role: _selectedRole,
        );
        
        if (mounted) {
          AppToast.show(context, 'Registration Successful!', isError: false);
          
          // Automatically log in after registration
          try {
            await AuthService().login(_emailController.text, _passwordController.text);
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
            }
          } catch (e) {
            // If auto-login fails, just go to login screen
            if (mounted) Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) AppToast.show(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [

          
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
                    child: Text(
                      _selectedRole == 'DOCTOR' ? 'Doctor Registration' : 'Create Account',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.1, end: 0),
                  
                  const Text(
                    'Join the DiaPredict health network',
                    style: TextStyle(
                      color: AppColors.silver500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  
                  const SizedBox(height: 32),
                  
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        
                        _buildLabel('FIRST NAME'),
                        _buildTextField(_firstNameController, 'John', validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 16),
                        
                        _buildLabel('LAST NAME'),
                        _buildTextField(_lastNameController, 'Doe', validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 16),
                        
                        _buildLabel('EMAIL'),
                        _buildTextField(_emailController, 'john.doe@example.com', keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                        const SizedBox(height: 16),
                        
                        _buildLabel('PHONE'),
                        _buildTextField(_phoneController, '+1 234 567 8900', keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        
                        _buildLabel('PASSWORD'),
                        _buildTextField(_passwordController, '••••••••', obscureText: _obscurePassword, validator: (v) => v!.length < 6 ? 'Min 6 characters' : null, onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword)),
                        const SizedBox(height: 16),
                        
                        _buildLabel('CONFIRM PASSWORD'),
                        _buildTextField(_passwordConfirmController, '••••••••', obscureText: _obscureConfirmPassword, validator: (v) => v != _passwordController.text ? 'Passwords must match' : null, onToggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                        
                        if (_selectedRole == 'DOCTOR') ...[
                          const SizedBox(height: 32),
                          const Divider(color: AppColors.cardBorder),
                          const SizedBox(height: 24),
                          const Text(
                            'DOCTOR INFORMATION',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 24),
                          
                          const SizedBox(height: 16),
                          
                          _buildLabel('QUALIFICATION'),
                          _buildTextField(_qualificationController, 'e.g., MBBS, MD', validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 16),
                          
                          _buildLabel('YEARS OF EXPERIENCE'),
                          _buildTextField(_experienceController, 'e.g., 5', keyboardType: TextInputType.number, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 16),
                          
                          _buildLabel('MEDICAL LICENSE NUMBER'),
                          _buildTextField(_licenseController, 'License number', validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),
                          const SizedBox(height: 16),
                          
                           
                           if (_selectedRole == 'DOCTOR') ...[
                              const SizedBox(height: 16),
                              _buildLabel('CONSULTATION FEE (₹)'),
                              _buildTextField(_consultationFeeController, 'e.g. 500', keyboardType: TextInputType.number, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null, icon: Icons.currency_rupee),
                           ],

                           const SizedBox(height: 32),
                           const Text(
                             'OFFICE LOCATION',
                             style: TextStyle(color: AppColors.silver500, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
                           ),
                           const SizedBox(height: 24),

                           _buildTextField(_hospitalNameController, 'Hospital/Clinic', icon: Icons.local_hospital_outlined, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),
                           const SizedBox(height: 16),

                           _buildTextField(_hospitalAddressController, 'Address', icon: Icons.location_on_outlined, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),
                           const SizedBox(height: 16),

                           _buildTextField(_cityController, 'City', icon: Icons.location_city, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),
                           const SizedBox(height: 16),

                           _buildTextField(_stateController, 'State', icon: Icons.map_outlined, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),
                           const SizedBox(height: 16),

                           _buildTextField(_pincodeController, 'Pincode', icon: Icons.pin_drop_outlined, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),

                           const SizedBox(height: 32),
                           const Text(
                             'ABOUT',
                             style: TextStyle(color: AppColors.silver500, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
                           ),
                           const SizedBox(height: 24),
                           
                           _buildTextField(_bioController, 'Tell us about yourself...', icon: null, maxLines: 3, validator: (v) => _selectedRole == 'DOCTOR' && v!.isEmpty ? 'Required' : null),


                        ],
                        
                        const SizedBox(height: 32),
                        
                        _isLoading 
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _register, 
                                child: Text(
                                  _selectedRole == 'DOCTOR' ? 'SUBMIT FOR APPROVAL' : 'SIGN UP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 800.ms).slideY(begin: 0.1, end: 0),
                  

                  
                  if (_selectedRole != 'DOCTOR') ...[
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRole = 'DOCTOR';
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Are you a doctor? ',
                                style: TextStyle(color: AppColors.silver500),
                              ),
                              TextSpan(
                                text: 'Register as Doctor',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 800.ms),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.silver500,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool obscureText = false, TextInputType? keyboardType, String? Function(String?)? validator, IconData? icon, int maxLines = 1, VoidCallback? onToggleObscure}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white.withOpacity(0.5)) : null,
        suffixIcon: onToggleObscure != null
            ? GestureDetector(
                onTap: onToggleObscure,
                child: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white.withOpacity(0.3),
                  size: 20,
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }




}
