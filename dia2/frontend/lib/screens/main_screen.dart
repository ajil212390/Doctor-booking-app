import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_dashboard.dart';
import 'prediction_form_screen.dart';
import 'doctor_list_screen.dart';
import 'profile_screen.dart';
import 'prediction_history_screen.dart';
import 'manage_slots_screen.dart';
import 'patient_list_screen.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isBottomNavVisible = true;
  String _role = 'DOCTOR';
  final GlobalKey<HomeDashboardState> _homeKey = GlobalKey<HomeDashboardState>();

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final String newRole = prefs.getString('user_role') ?? 'DOCTOR';
    if (newRole != _role) {
      setState(() {
        _role = newRole;
        _screens = null;
      });
    }
  }

  List<Widget>? _screens;
  List<Widget> get _currentScreens {
    if (_screens != null) return _screens!;
    
    if (_role == 'DOCTOR') {
      _screens = [
        HomeDashboard(key: _homeKey),
        const ManageSlotsScreen(),
        const PatientListScreen(),
        const ProfileScreen(),
      ];
    } else {
      _screens = [
        HomeDashboard(
          key: _homeKey,
          onProfileTap: () => setState(() => _currentIndex = 3),
          onPredictTap: () => setState(() => _currentIndex = 1),
        ),
        PredictionFormScreen(
          onPredictionCompleted: (data) {
          _homeKey.currentState?.refresh(data);
          setState(() => _currentIndex = 0);
        },
        ),
        const DoctorListScreen(),
        const ProfileScreen(),
      ];
    }
    return _screens!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _currentScreens,
          ),
          
          // Animated Bottom Nav
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.fastOutSlowIn,
            bottom: !_isBottomNavVisible ? -120 : 0,
            left: 0,
            right: 0,
            child: _buildGlassBottomNav(),
          ),
          
          // iPhone Indicator
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.only(top: 16, bottom: 40, left: 24, right: 24),
          decoration: BoxDecoration(
            color: const Color(0xCC0A0A0A),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _role == 'DOCTOR' 
              ? [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, 'HOME'),
                  _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month, 'CHART'),
                  _buildNavItem(2, Icons.people_outline, Icons.people, 'PATIENTS'),
                  _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'SETTINGS'),
                ]
              : [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, 'HOME'),
                  _buildNavItem(1, Icons.query_stats_outlined, Icons.query_stats, 'PREDICT'),
                  _buildNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month, 'DOCTORS'),
                  _buildNavItem(3, Icons.person_outline, Icons.person, 'PROFILE'),
                ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (isActive && index == 0) {
          _homeKey.currentState?.refresh();
        }
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? filledIcon : outlineIcon,
            color: isActive ? Colors.white : const Color(0xFF64748B),
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

