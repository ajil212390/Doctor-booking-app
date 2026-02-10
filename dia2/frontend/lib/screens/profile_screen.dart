import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'User';
  String _email = 'user@example.com';
  String _role = 'USER';
  String? _profilePicture;
  bool _isLoading = true;
  bool _isUploading = false;
  
  // Doctor-specific fields
  Map<String, dynamic>? _doctorProfile;

  // Medical History
  List<dynamic> _medicalHistory = [];
  bool _isHistoryLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _name = prefs.getString('user_name') ?? 'User';
        _role = prefs.getString('user_role') ?? 'USER';
        _email = prefs.getString('user_email') ?? 'user@example.com';
      });
    }
    
    // If user is a doctor, fetch doctor profile
    if (_role.toUpperCase() == 'DOCTOR') {
      try {
        final profile = await DoctorService().getDoctorProfile();
        if (mounted) {
          setState(() {
            _doctorProfile = profile;
            _profilePicture = profile['profile_picture'];
            // Update name from doctor profile
            final user = profile['user'];
            if (user != null) {
              _name = user['full_name'] ?? _name;
              _email = user['email'] ?? _email;
            }
          });
        }
      } catch (e) {
      }
    } else {
      // Fetch normal user profile to get DP
      try {
        final profile = await DoctorService().getUserProfile();
        if (mounted) {
          setState(() {
            _profilePicture = profile['profile_picture'];
            _name = profile['full_name'] ?? _name;
            _email = profile['email'] ?? _email;
          });
        }
      } catch (e) {
      }

      // Fetch medical history for regular users
      setState(() => _isHistoryLoading = true);
      try {
        final results = await Future.wait([
          DoctorService().getMedicalHistory(),
          DoctorService().getUserAppointments(),
        ]);
        
        final history = results[0];
        final appointments = results[1];
        
        if (mounted) {
          setState(() {
            // Combine dedicated history with COMPLETED appointments
            final List<dynamic> combinedHistory = List.from(history);
            
            for (var apt in appointments) {
              final status = (apt['status'] ?? '').toString().toUpperCase();
              final id = apt['id'];
              
              // If it's COMPLETED or CANCELLED, it's part of "History"
              if (status == 'COMPLETED' || status == 'CANCELLED') {
                bool alreadyExists = combinedHistory.any((h) => h['id'] == id || h['appointment_id'] == id);
                if (!alreadyExists) {
                  combinedHistory.add({
                    'id': id,
                    'doctor_name': apt['doctor_name'] ?? (apt['doctor'] is Map ? apt['doctor']['full_name'] : 'Doctor'),
                    'date': apt['date'] ?? (apt['slot_details'] != null ? apt['slot_details']['date'] : 'Recent'),
                    'diagnosis': status == 'COMPLETED' ? 'Consultation Completed' : 'Appointment Cancelled',
                    'notes': apt['notes'] ?? apt['comment'] ?? 'General Visit',
                    'appointment_id': id,
                  });
                }
              }
            }
            
            _medicalHistory = combinedHistory;
            _isHistoryLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isHistoryLoading = false);
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    if (mounted) setState(() => _isUploading = true);

    try {
      Map<String, dynamic> updatedProfile;
      if (_role.toUpperCase() == 'DOCTOR') {
        updatedProfile = await DoctorService().updateDoctorProfileWithImage(image.path);
      } else {
        updatedProfile = await DoctorService().updateUserProfileWithImage(image.path);
      }

      if (mounted) {
        setState(() {
          _profilePicture = updatedProfile['profile_picture'];
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20 * anim1.value, sigmaY: 20 * anim1.value),
          child: ScaleTransition(
            scale: anim1,
            child: Opacity(
              opacity: anim1.value,
              child: AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(color: AppColors.border),
                ),
                title: Text(
                  'EDIT PROFILE',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textOnSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditField('FULL NAME', nameController, Icons.person_outline),
                    const SizedBox(height: 20),
                    _buildEditField('EMAIL ADDRESS', emailController, Icons.email_outlined),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                   ElevatedButton(
                    onPressed: () async {
                      try {
                        // Call backend to update
                        await DoctorService().updateUserProfile(
                          fullName: nameController.text,
                          email: emailController.text,
                        );

                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('user_name', nameController.text);
                        await prefs.setString('user_email', emailController.text);
                        
                        if (mounted) {
                          setState(() {
                            _name = nameController.text;
                            _email = emailController.text;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated successfully')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('SAVE CHANGES'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.silver500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textOnSurface, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.textOnSurface.withValues(alpha: 0.3), size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _handleLogout() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10 * anim1.value, sigmaY: 10 * anim1.value),
          child: ScaleTransition(
            scale: anim1,
            child: Opacity(
              opacity: anim1.value,
              child: AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                  side: const BorderSide(color: AppColors.border),
                ),
                title: Text('LOGOUT', style: GoogleFonts.plusJakartaSans(color: AppColors.textOnSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                content: const Text('Are you sure you want to end your session?', style: TextStyle(color: AppColors.silver500)),
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
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await AuthService().logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _role.toUpperCase() == 'DOCTOR';
    
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.background,
          ),

          SafeArea(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.surface))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  color: AppColors.surface,
                  backgroundColor: AppColors.background,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                      const SizedBox(height: 20),
                      // Header
                        Text(
                          isDoctor ? 'Doctor Profile' : 'Account Profile',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.textOnBackground,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 48),

                      // Avatar Section
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border, width: 3),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 64,
                                  backgroundColor: AppColors.surface,
                                  backgroundImage: _profilePicture != null
                                      ? NetworkImage(
                                          _profilePicture!.startsWith('http')
                                              ? _profilePicture!
                                              : '${ApiConfig.baseUrl.replaceAll('/api/', '')}$_profilePicture',
                                        )
                                      : null,
                                  child: _isUploading 
                                    ? const CircularProgressIndicator(color: AppColors.textOnSurface)
                                    : (_profilePicture == null
                                      ? Text(
                                          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 48,
                                            color: AppColors.textOnSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : null),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.textOnSurface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.edit, color: AppColors.surface, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

                      const SizedBox(height: 32),

                      // User Identity
                      Text(
                        _name.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textOnBackground,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _email,
                        style: const TextStyle(
                          color: AppColors.silver500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _role.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textOnSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      _buildProfileCard(Icons.person_outline, 'Personal Information', 'Identity and health data', onTap: _showEditProfileDialog),
                      const SizedBox(height: 16),

                      // Doctor-specific information
                      if (isDoctor && _doctorProfile != null) ...[
                        _buildSectionTitle('PROFESSIONAL INFO'),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.school_outlined,
                          title: 'Qualification',
                          value: _doctorProfile!['qualification'] ?? 'Not specified',
                        ),
                        _buildInfoCard(
                          icon: Icons.work_history_outlined,
                          title: 'Experience',
                          value: '${_doctorProfile!['experience_years'] ?? 0} years',
                        ),
                        _buildInfoCard(
                          icon: Icons.badge_outlined,
                          title: 'License Number',
                          value: _doctorProfile!['license_number'] ?? 'Not specified',
                        ),
                        _buildInfoCard(
                          icon: Icons.attach_money,
                          title: 'Consultation Fee',
                          value: '₹${_doctorProfile!['consultation_fee'] ?? '0'}',
                        ),
                        
                        const SizedBox(height: 32),
                        _buildSectionTitle('OFFICE LOCATION'),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.local_hospital_outlined,
                          title: 'Hospital/Clinic',
                          value: _doctorProfile!['hospital_name'] ?? 'Not specified',
                        ),
                        _buildInfoCard(
                          icon: Icons.location_on_outlined,
                          title: 'Address',
                          value: _doctorProfile!['hospital_address'] ?? 'Not specified',
                        ),
                        _buildInfoCard(
                          icon: Icons.location_city_outlined,
                          title: 'City',
                          value: _doctorProfile!['city'] ?? 'Not specified',
                        ),
                        _buildInfoCard(
                          icon: Icons.map_outlined,
                          title: 'State',
                          value: _doctorProfile!['state'] ?? 'Not specified',
                        ),
                        _buildInfoCard(
                          icon: Icons.pin_drop_outlined,
                          title: 'Pincode',
                          value: _doctorProfile!['pincode'] ?? 'Not specified',
                        ),
                        
                        if (_doctorProfile!['bio'] != null && _doctorProfile!['bio'].toString().isNotEmpty) ...[
                          const SizedBox(height: 32),
                          _buildSectionTitle('ABOUT'),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              _doctorProfile!['bio'],
                              style: const TextStyle(
                                color: AppColors.textOnSurface,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                        ],
                        
                        const SizedBox(height: 32),
                        _buildSectionTitle('ACCOUNT STATUS'),
                        const SizedBox(height: 16),
                        _buildStatusCard(),
                      ] else ...[
                        // Regular user options
                        const SizedBox(height: 32),
                        _buildSectionTitle('MEDICAL HISTORY'),
                        const SizedBox(height: 16),
                        if (_isHistoryLoading)
                          const Center(child: CircularProgressIndicator(color: AppColors.surface, strokeWidth: 2))
                        else if (_medicalHistory.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.history_outlined, size: 32, color: AppColors.textOnSurface.withValues(alpha: 0.1)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No past medical history found.',
                                  style: TextStyle(color: AppColors.silver500, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._medicalHistory.map((history) => _buildHistoryItem(history)).toList(),
                      ],
                      
                      const SizedBox(height: 48),

                      // Logout
                      GestureDetector(
                        onTap: _handleLogout,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'LOGOUT SESSION',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.silver500,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
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
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.silver500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textOnSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.02, end: 0);
  }

  Widget _buildStatusCard() {
    final status = _doctorProfile?['approval_status'] ?? 'pending';
    final statusDisplay = _doctorProfile?['approval_status_display'] ?? 'Pending Approval';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status.toString().toLowerCase()) {
      case 'approved':
        statusColor = Colors.greenAccent;
        statusIcon = Icons.verified;
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.amberAccent;
        statusIcon = Icons.pending;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusDisplay,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_doctorProfile?['approval_date'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Since ${_doctorProfile!['approval_date'].toString().split('T')[0]}',
                      style: const TextStyle(
                        color: AppColors.silver500,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildProfileCard(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(icon, color: AppColors.textOnSurface, size: 24),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textOnSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.silver500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textOnSurface.withValues(alpha: 0.2), size: 20),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildHistoryItem(dynamic history) {
    final doctorName = history['doctor_name'] ?? 'Doctor';
    final date = history['date'] ?? 'No date';
    final notes = history['notes'] ?? 'General Consultation';
    final diagnosis = history['diagnosis'] ?? 'Checkup';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.description_outlined, color: AppColors.textOnSurface, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      doctorName,
                      style: const TextStyle(color: AppColors.textOnSurface, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      date,
                      style: const TextStyle(color: AppColors.silver500, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  diagnosis,
                  style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: const TextStyle(color: AppColors.silver500, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.02, end: 0);
  }
}
