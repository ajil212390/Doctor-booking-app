import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/doctor_service.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final ScrollController _calendarScrollController = ScrollController();
  final List<String> _weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  void _scrollToSelectedDate() {
    if (_calendarScrollController.hasClients) {
      final index = _selectedDate.day - 1;
      _calendarScrollController.jumpTo(index * 72.0);
    }
  }

  Future<void> _fetchAppointments() async {
    try {
      final appointments = await DoctorService().getDoctorAppointments();
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<DateTime> get _visibleDates {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return List.generate(daysInMonth, (index) => DateTime(now.year, now.month, index + 1));
  }

  List<dynamic> get _filteredAppointments {
    // Filter to show only appointments for the selected date
    final selectedStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    
    return _appointments.where((apt) {
      final slot = apt['slot_details'] ?? {};
      final rawDate = (apt['date'] ?? slot['date'])?.toString() ?? '';
      
      // Clean the date (handle ISO format like 2026-02-05T00:00:00Z)
      final cleanDate = rawDate.contains('T') ? rawDate.split('T')[0] : rawDate.split(' ')[0];
      
      return cleanDate == selectedStr;
    }).toList();
  }

  String _getAvailableDates() {
    if (_appointments.isEmpty) return "None";
    final dates = _appointments.map((a) {
      final d = a['date'] ?? (a['slot_details'] ?? {})['date'] ?? 'No Date';
      return d.toString().split('T')[0].split(' ')[0];
    }).toSet().toList();
    return dates.join(", ");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchAppointments,
                  color: AppColors.surface,
                  backgroundColor: AppColors.background,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildDatePicker(),
                        const SizedBox(height: 32),
                        if (_isLoading && _appointments.isEmpty)
                          const Center(child: Padding(
                            padding: EdgeInsets.only(top: 100),
                            child: CircularProgressIndicator(color: AppColors.surface),
                          ))
                        else if (_filteredAppointments.isEmpty)
                          Center(child: Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Column(
                              children: [
                                Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textOnSurface.withOpacity(0.1)),
                                const SizedBox(height: 12),
                                Text(
                                  'No appointments for ${DateFormat('MMM d').format(_selectedDate)}',
                                  style: const TextStyle(color: AppColors.silver500),
                                ),
                              ],
                            ),
                          ))
                        else
                          ..._filteredAppointments.map((apt) => _buildPatientCard(apt)),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return const SizedBox.shrink(); 
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && 
                   _selectedDate.month == now.month && 
                   _selectedDate.day == now.day;
    
    final headerTitle = isToday ? "Today's\nSchedule" : "Schedule";
    final dateText = DateFormat('EEEE, MMMM d').format(_selectedDate);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          headerTitle,
          style: const TextStyle(
            color: AppColors.textOnBackground,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          dateText,
          style: const TextStyle(
            color: AppColors.silver500,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildDatePicker() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _calendarScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _visibleDates.length,
        itemBuilder: (context, index) {
          final date = _visibleDates[index];
          final now = DateTime.now();
          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
          final isSelected = date.year == _selectedDate.year && 
                            date.month == _selectedDate.month && 
                            date.day == _selectedDate.day;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.surface 
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                      ? AppColors.border 
                      : isToday 
                          ? AppColors.border.withValues(alpha: 0.5)
                          : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekDays[date.weekday % 7],
                    style: TextStyle(
                      color: isSelected ? AppColors.textOnSurface : AppColors.silver500,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: AppColors.textOnSurface,
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedAppointments() {
    List<Widget> items = [];
    final filtered = _filteredAppointments;
    
    // Debug: Show count
    items.add(
      Text(
        'Showing ${filtered.length} appointments',
        style: TextStyle(color: AppColors.textOnBackground.withValues(alpha: 0.3), fontSize: 12),
      ),
    );
    items.add(const SizedBox(height: 16));
    
    // Show all appointments
    for (var apt in filtered) {
      try {
        items.add(_buildPatientCard(apt));
      } catch (e) {
        items.add(
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.red.withValues(alpha: 0.2),
            child: Text('Error rendering card: $e', style: const TextStyle(color: Colors.red)),
          ),
        );
      }
    }

    return items;
  }

  Widget _buildMiniCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT DATE',
          style: TextStyle(
            color: AppColors.silver500,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 85,
          child: ListView.separated(
            controller: _calendarScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _visibleDates.length,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final date = _visibleDates[index];
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final itemDate = DateTime(date.year, date.month, date.day);
              
              bool isActive = _selectedDate.day == date.day && 
                             _selectedDate.month == date.month && 
                             _selectedDate.year == date.year;
              
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? AppColors.surface 
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive 
                          ? AppColors.border 
                          : AppColors.border.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekDays[date.weekday % 7],
                        style: TextStyle(
                          color: isActive ? AppColors.textOnSurface : AppColors.silver400,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: AppColors.textOnSurface,
                          fontSize: 20,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderButton(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.textOnSurface.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textOnSurface.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, color: AppColors.silver200, size: 20),
    );
  }

  Widget _buildPatientCard(dynamic apt) {
    // Attempt to get data from root or slot_details
    final slot = apt['slot_details'] ?? {};
    final startTime = apt['start_time'] ?? slot['start_time'] ?? '09:00';
    final endTime = apt['end_time'] ?? slot['end_time'] ?? '10:00';
    
    // Safe name mapping - handle case where patient is an ID (int) not an object
    String patientName = 'Patient';
    final patientField = apt['patient'];
    final userField = apt['user'];
    
    if (apt['patient_name'] != null) {
      patientName = apt['patient_name'].toString();
    } else if (apt['patient_full_name'] != null) {
      patientName = apt['patient_full_name'].toString();
    } else if (apt['user_full_name'] != null) {
      patientName = apt['user_full_name'].toString();
    } else if (patientField is Map) {
      patientName = patientField['full_name'] ?? 
                   patientField['name'] ?? 
                   (patientField['first_name'] != null ? "${patientField['first_name']} ${patientField['last_name'] ?? ''}" : 'Patient');
    } else if (userField is Map) {
      patientName = userField['full_name'] ?? 
                   userField['name'] ?? 
                   (userField['first_name'] != null ? "${userField['first_name']} ${userField['last_name'] ?? ''}" : 'Patient');
    } else if (patientField is String) {
      patientName = patientField;
    }
                       
    final riskLevel = (apt['risk_level'] ?? 'Low Risk').toString().toUpperCase();
    final riskScore = apt['risk_score'] ?? '0.00';
    final description = apt['notes'] ?? slot['label'] ?? 'Consultation';
    
    // Time formatting helper - with safety
    String formatTime(String? timeStr) {
      try {
        if (timeStr == null || timeStr.isEmpty) return '09:00 AM';
        // Extract just the HH:MM part if it's a full timestamp
        String cleanTime = timeStr;
        if (timeStr.contains('T')) {
          cleanTime = timeStr.split('T')[1].substring(0, 5);
        } else if (timeStr.contains(' ')) {
          cleanTime = timeStr.split(' ')[0];
        }
        final parts = cleanTime.split(':');
        int h = int.tryParse(parts[0]) ?? 9;
        final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
        final p = h >= 12 ? 'PM' : 'AM';
        h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        return '${h.toString().padLeft(2, '0')}:$m $p';
      } catch (e) {
        return '09:00 AM';
      }
    }

    final displayTimeRange = "${formatTime(startTime)} - ${formatTime(endTime)}";
    final fTime = formatTime(startTime).split(' ')[0];
    final period = formatTime(startTime).split(' ')[1];

    Color riskColor;
    if (riskLevel.contains('HIGH')) {
      riskColor = Colors.redAccent;
    } else if (riskLevel.contains('MODERATE')) {
      riskColor = Colors.amberAccent;
    } else {
      riskColor = Colors.greenAccent;
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, 
        '/appointment-details',
        arguments: apt,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Time box
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fTime,
                    style: const TextStyle(color: AppColors.textOnSurface, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    period,
                    style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.4), fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            // Patient info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          patientName,
                          style: const TextStyle(color: AppColors.textOnSurface, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (apt['status'] != 'COMPLETED')
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32), side: const BorderSide(color: AppColors.border)),
                                  contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 40),
                                      ),
                                      const SizedBox(height: 24),
                                      const Text(
                                        'Finish Consultation?',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.textOnSurface, fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'This will mark the session as completed and move it to your records.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.textOnSurface, fontSize: 13, height: 1.5),
                                      ),
                                      const SizedBox(height: 32),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              ),
                                              child: const Text('NOT YET', style: TextStyle(color: AppColors.silver500, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              ),
                                              child: const Text('COMPLETE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );

                            if (confirm == true) {
                              try {
                                await DoctorService().completeAppointment(apt['id']);
                                if (mounted) {
                                  AppToast.show(context, 'Consultation completed successfully', isError: false);
                                  // Navigate to details after completion as requested
                                  Navigator.pushNamed(context, '/appointment-details', arguments: apt);
                                  _fetchAppointments();
                                }
                              } catch (e) {
                                if (mounted) {
                                  AppToast.show(context, 'Error: $e');
                                }
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Color(0xFF10B981), size: 18),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                          child: const Text('DONE', style: TextStyle(color: AppColors.textOnSurface, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: riskColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          riskLevel,
                          style: TextStyle(color: riskColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Score: $riskScore',
                        style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: riskColor,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: riskColor.withValues(alpha: 0.5), blurRadius: 6)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_filled, color: AppColors.textOnSurface.withValues(alpha: 0.2), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        displayTimeRange,
                        style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: AppColors.textOnSurface.withValues(alpha: 0.4), fontSize: 13, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}
