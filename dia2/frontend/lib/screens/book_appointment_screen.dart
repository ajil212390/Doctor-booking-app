import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../services/doctor_service.dart';
import '../theme/app_theme.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  late Future<Map<String, dynamic>> _slotsFuture;
  bool _isBooking = false;
  late Map<String, dynamic> _doctor;
  
  DateTime _selectedDate = DateTime.now();
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? _selectedSlotId;
  Map<String, List<dynamic>> _groupedSlots = {};
  List<String> _availableDates = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _doctor = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _slotsFuture = DoctorService().getSlots(_doctor['id']);
  }

  void _processSlots(List<dynamic> slots) {
    _groupedSlots = {};
    final now = DateTime.now();
    
    for (var slot in slots) {
      // 1. Skip if slot is already booked (not available)
      if (slot['is_available'] == false) continue;

      String dateStr = slot['date'];
      String timeStr = slot['start_time']; // Format: HH:MM:SS
      
      try {
        final slotDateTime = DateTime.parse('${dateStr}T$timeStr');
        
        // 2. Skip if the slot time has already passed
        if (slotDateTime.isBefore(now)) continue;

        if (!_groupedSlots.containsKey(dateStr)) {
          _groupedSlots[dateStr] = [];
        }
        _groupedSlots[dateStr]!.add(slot);
      } catch (e) {
        // If parsing fails, fall back to adding it anyway or skip
        if (!_groupedSlots.containsKey(dateStr)) {
          _groupedSlots[dateStr] = [];
        }
        _groupedSlots[dateStr]!.add(slot);
      }
    }
    _availableDates = _groupedSlots.keys.toList()..sort();
    
    // Set initial selected date if not set or not available
    if (_availableDates.isNotEmpty && !_availableDates.contains(DateFormat('yyyy-MM-dd').format(_selectedDate))) {
      _selectedDate = DateTime.parse(_availableDates.first);
    }
  }

  void _book() async {
    if (_selectedSlotId == null) return;
    
    setState(() => _isBooking = true);
    try {
      await DoctorService().bookAppointment(
        doctorId: _doctor['id'],
        timeSlotId: _selectedSlotId!,
      );
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      setState(() => _isBooking = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32), side: BorderSide(color: Colors.white.withOpacity(0.1))),
          contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 24),
              Text(
                'BOOKING\nSUCCESSFUL',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your appointment with ${_doctor['full_name']} has been confirmed for ${DateFormat('MMMM d').format(_selectedDate)}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.silver400, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to Doctor Details/List
                    // Note: The dashboard will refresh when it becomes visible if handled, 
                    // or we can use a callback. For now, let's just go back.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text('GO TO DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
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
                colors: [Color(0xFF2A2A2A), Color(0xFF0A0A0A)],
              ),
            ),
          ),

          SafeArea(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _slotsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white70));
                }
                
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final data = snapshot.data!;
                final slots = data['time_slots'] as List<dynamic>? ?? [];
                _processSlots(slots);

                if (slots.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _slotsFuture = DoctorService().getSlots(_doctor['id']);
                    });
                    await _slotsFuture;
                  },
                  color: Colors.white,
                  backgroundColor: const Color(0xFF1A1A1A),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 80), // Spacer for header/back button
                              _buildHeader(),
                              const SizedBox(height: 40),
                              _buildDateSelection(),
                              const SizedBox(height: 40),
                              _buildTimeSlotSelection(),
                              const SizedBox(height: 140), // Spacer for fixed button
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        left: 24,
                        right: 24,
                        child: _buildConfirmButton(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Back Button
          Positioned(
            top: 52,
            left: 24,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              ),
            ),
          ),


        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFF94A3B8)],
          ).createShader(bounds),
          child: Text(
            _doctor['full_name'] ?? 'Specialist',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ),
        Text(
          _doctor['specialization'] ?? 'Endocrinology Specialist',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Text(
              (_doctor['average_rating'] ?? _doctor['rating'])?.toStringAsFixed(1) ?? '4.5',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_doctor['review_count'] ?? '12'} reviews)',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSelection() {
    final now = DateTime.now();
    final canGoPrev = DateTime(_displayMonth.year, _displayMonth.month).isAfter(DateTime(now.year, now.month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Date',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                _buildCircleNavButton(
                  Icons.chevron_left, 
                  canGoPrev ? () {
                    setState(() {
                      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
                    });
                  } : () {},
                  enabled: canGoPrev,
                ),
                const SizedBox(width: 8),
                _buildCircleNavButton(
                  Icons.chevron_right, 
                  () {
                    setState(() {
                      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              // Month/Year label
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  DateFormat('MMMM yyyy').format(_displayMonth),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildCalendarGrid(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final daysInMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
    final today = DateTime.now();
    
    final weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((d) => Text(
            d, 
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          )).toList(),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: daysInMonth + (firstWeekday - 1),
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) {
              return const SizedBox();
            }
            final day = index - (firstWeekday - 1) + 1;
            final date = DateTime(_displayMonth.year, _displayMonth.month, day);
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final isAvailable = _availableDates.contains(dateKey);
            final isSelected = DateFormat('yyyy-MM-dd').format(_selectedDate) == dateKey;
            final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
            
            return GestureDetector(
              onTap: (isAvailable && !isPast) ? () {
                setState(() {
                  _selectedDate = date;
                  _selectedSlotId = null;
                });
              } : null,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                  border: isSelected ? Border.all(color: Colors.white.withOpacity(0.4)) : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isPast 
                        ? Colors.white.withOpacity(0.05) 
                        : isAvailable 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.1),
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final slots = _groupedSlots[dateKey] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select a Time Slot',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        if (slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No available slots for this date.',
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 14),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final bool isSelected = _selectedSlotId == slot['id'];
              
              return GestureDetector(
                onTap: () => setState(() => _selectedSlotId = slot['id']),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        DateFormat('hh:mm a').format(DateFormat('HH:mm:ss').parse(slot['start_time'])),
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    final bool canConfirm = _selectedSlotId != null && !_isBooking;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: GestureDetector(
          onTap: canConfirm ? _book : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: canConfirm 
                  ? [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)]
                  : [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: canConfirm ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05)
              ),
              boxShadow: canConfirm ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 0),
                )
              ] : [],
            ),
            child: Center(
              child: _isBooking 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFCBD5E1)],
                    ).createShader(bounds),
                    child: const Text(
                      'Confirm Booking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleNavButton(IconData icon, VoidCallback onTap, {bool enabled = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(enabled ? 0.04 : 0.02),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(enabled ? 0.1 : 0.05)),
        ),
        child: Icon(icon, size: 16, color: enabled ? Colors.white : Colors.white.withOpacity(0.2)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _slotsFuture = DoctorService().getSlots(_doctor['id']);
        });
        await _slotsFuture;
      },
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Icon(Icons.calendar_today_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                ),
                const SizedBox(height: 32),
                Text(
                  'No Slots Available',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24, 
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please check back later',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildErrorState(String error) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _slotsFuture = DoctorService().getSlots(_doctor['id']);
        });
        await _slotsFuture;
      },
      color: Colors.white,
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load slots',
                    style: GoogleFonts.plusJakartaSans(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _slotsFuture = DoctorService().getSlots(_doctor['id']);
                    }),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

