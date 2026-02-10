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
      if (slot['is_available'] == false) continue;

      String dateStr = slot['date'];
      String timeStr = slot['start_time']; 
      
      try {
        final slotDateTime = DateTime.parse('${dateStr}T$timeStr');
        
        if (slotDateTime.isBefore(now)) continue;

        if (!_groupedSlots.containsKey(dateStr)) {
          _groupedSlots[dateStr] = [];
        }
        _groupedSlots[dateStr]!.add(slot);
      } catch (e) {
        if (!_groupedSlots.containsKey(dateStr)) {
          _groupedSlots[dateStr] = [];
        }
        _groupedSlots[dateStr]!.add(slot);
      }
    }
    _availableDates = _groupedSlots.keys.toList()..sort();
    
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
        // Handle error (e.g. show toast)
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32), side: const BorderSide(color: AppColors.border)),
          contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.check_circle, color: AppColors.textOnSurface, size: 56),
              ),
              const SizedBox(height: 24),
              Text(
                'BOOKING\nSUCCESSFUL',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  color: AppColors.textOnSurface,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your appointment has been confirmed.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textOnSurface, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).pop(); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _slotsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.textOnSurface));
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
                  color: AppColors.textOnSurface,
                  backgroundColor: AppColors.surface,
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 80), 
                              _buildHeader(),
                              const SizedBox(height: 40),
                              _buildDateSelection(),
                              const SizedBox(height: 40),
                              _buildTimeSlotSelection(),
                              const SizedBox(height: 140), 
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

          Positioned(
            top: 52,
            left: 24,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textOnSurface, size: 20),
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
        Text(
          _doctor['full_name'] ?? 'Specialist',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            color: AppColors.textOnBackground,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        Text(
          _doctor['specialization'] ?? 'Specialist',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            color: AppColors.textOnBackground.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Date',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            color: AppColors.textOnBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.border),
          ),
          child: _buildCalendarGrid(),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; 
    
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
            final date = DateTime(_selectedDate.year, _selectedDate.month, day);
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final isAvailable = _availableDates.contains(dateKey);
            final isSelected = DateFormat('yyyy-MM-dd').format(_selectedDate) == dateKey;
            
            return GestureDetector(
              onTap: isAvailable ? () {
                setState(() {
                  _selectedDate = date;
                  _selectedSlotId = null;
                });
              } : null,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.surfaceLight : Colors.transparent,
                  border: isSelected ? Border.all(color: AppColors.border) : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isAvailable ? AppColors.textOnSurface : AppColors.textOnSurface.withOpacity(0.1),
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
            color: AppColors.textOnBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        if (slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No available slots for this date.',
              style: TextStyle(color: AppColors.textOnBackground.withOpacity(0.3), fontSize: 14),
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
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surfaceLight : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.border : AppColors.border.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    DateFormat('hh:mm a').format(DateFormat('HH:mm:ss').parse(slot['start_time'])),
                    style: TextStyle(
                      color: isSelected ? AppColors.textOnSurface : AppColors.textOnSurface.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    
    return GestureDetector(
      onTap: canConfirm ? _book : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: canConfirm ? AppColors.purple : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: canConfirm ? AppColors.purple : AppColors.border,
          ),
        ),
        child: Center(
          child: _isBooking 
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2))
            : Text(
                'Confirm Booking',
                style: TextStyle(
                  color: canConfirm ? Colors.white : AppColors.textOnSurface.withOpacity(0.4),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
        ),
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
      color: AppColors.textOnSurface,
      backgroundColor: AppColors.surface,
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
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(Icons.calendar_today_rounded, size: 64, color: AppColors.textOnSurface.withOpacity(0.2)),
                ),
                const SizedBox(height: 32),
                const Text(
                  'No Slots Available',
                  style: TextStyle(fontSize: 24, color: AppColors.textOnBackground, fontWeight: FontWeight.bold),
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
      color: AppColors.textOnSurface,
      backgroundColor: AppColors.surface,
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
                  const Text(
                    'Failed to load slots',
                    style: TextStyle(fontSize: 24, color: AppColors.textOnSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _slotsFuture = DoctorService().getSlots(_doctor['id']);
                    }),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple, foregroundColor: Colors.white),
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
