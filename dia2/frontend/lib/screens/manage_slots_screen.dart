import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../theme/app_theme.dart';

class ManageSlotsScreen extends StatefulWidget {
  const ManageSlotsScreen({super.key});

  @override
  State<ManageSlotsScreen> createState() => _ManageSlotsScreenState();
}

class _ManageSlotsScreenState extends State<ManageSlotsScreen> {
  DateTime selectedDate = DateTime.now();
  final List<String> weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  
  List<dynamic> _slots = [];
  bool _isLoading = false;
  String _startTime = '09:00';
  String _endTime = '10:00';
  DateTime _viewDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final ScrollController _scrollController = ScrollController();

  List<DateTime> get _visibleDates {
    final int daysInMonth = DateTime(_viewDate.year, _viewDate.month + 1, 0).day;
    return List.generate(daysInMonth, (index) => DateTime(_viewDate.year, _viewDate.month, index + 1));
  }

  String _getMonth(int month) {
    const m = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return m[month - 1];
  }

  void _changeMonth(int months) {
    setState(() {
      _viewDate = DateTime(_viewDate.year, _viewDate.month + months, 1);
      final now = DateTime.now();
      if (_viewDate.year == now.year && _viewDate.month == now.month) {
        selectedDate = now;
      } else {
        selectedDate = _viewDate;
      }
    });
    _scrollToSelected();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final index = selectedDate.day - 1;
        _scrollController.animateTo(
          index * 72.0, // 60 width + 12 separator
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }



  String _formatTimeTo24h(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      if (parts.length != 2) return timeStr;
      
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = timeParts[1];
      final isPm = parts[1].toUpperCase() == 'PM';
      
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      
      return '${hour.toString().padLeft(2, '0')}:$minute';
    } catch (e) {
      return timeStr;
    }
  }

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _slots = [
      {
        'id': '01',
        'date': '${today.year}-${today.month}-${today.day}',
        'label': 'MORNING',
        'start_time': '09:00',
        'end_time': '12:30',
        'accentColor': const Color(0xFF10B981),
      },
    ];
    _fetchSlots();
    _scrollToSelected();
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.doctorTimeSlots}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend could return 'results' (paginated) or a direct list
        final List<dynamic> fetched = data is List ? data : (data['results'] ?? data['data'] ?? []);
        
        setState(() {
          _slots = fetched.map((slot) {
            // Trim backend time (HH:MM:SS) to HH:MM for UI
            String startTime = slot['start_time'] ?? '09:00';
            String endTime = slot['end_time'] ?? '10:00';
            
            if (startTime.length > 5) startTime = startTime.substring(0, 5);
            if (endTime.length > 5) endTime = endTime.substring(0, 5);
            
            slot['start_time'] = startTime;
            slot['end_time'] = endTime;
            
            slot['label'] = (int.tryParse(startTime.split(':')[0]) ?? 0) >= 12 ? 'AFTERNOON' : 'MORNING';
            slot['accentColor'] = slot['label'] == 'AFTERNOON' ? const Color(0xFF64748B) : const Color(0xFF10B981);
            return slot;
          }).toList();
        });
      }
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNewSlot({Function? onUpdate}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    
    // Show loading on button
    if (onUpdate != null) onUpdate(() => _isLoading = true);
    setState(() => _isLoading = true);

    try {
      final startTime24 = _formatTimeTo24h(_startTime);
      final endTime24 = _formatTimeTo24h(_endTime);
      
      // Some Django backends are very strict and require HH:MM:SS
      final startTimeStrict = startTime24.length == 5 ? '$startTime24:00' : startTime24;
      final endTimeStrict = endTime24.length == 5 ? '$endTime24:00' : endTime24;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.doctorTimeSlots}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': dateStr,
          'start_time': startTimeStrict,
          'end_time': endTimeStrict,
          'is_available': true,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        Navigator.pop(context);
        _fetchSlots(); // Refresh list from backend
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot saved to cloud!', style: TextStyle(color: Colors.white)),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Server rejected: ${response.body}');
      }
    } catch (e) {
      String errorMsg = e.toString().contains('Server rejected') 
          ? e.toString().split('Server rejected: ').last 
          : e.toString();
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $errorMsg', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (onUpdate != null) onUpdate(() => _isLoading = false);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeSlot(String id) async {
    // Optimistic UI update
    setState(() {
      _slots.removeWhere((slot) => slot['id'].toString() == id.toString());
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    final url = '${ApiConfig.baseUrl}${ApiConfig.doctorTimeSlots}$id/';

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slot removed from cloud'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final String formatted = picked.format(context);
        if (isStart) {
          _startTime = formatted;
          // Auto-adjust end time to be 1 hour later
          final int nextHour = (picked.hour + 1) % 24;
          final TimeOfDay autoEndTime = TimeOfDay(hour: nextHour, minute: picked.minute);
          _endTime = autoEndTime.format(context);
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  void _updateDate(DateTime date) {
    setState(() {
      selectedDate = date;
    });
  }





  void _handleAddSlot() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0A0A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Slot',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Text('DATE', style: TextStyle(color: AppColors.silver500, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${selectedDate.day} ${_getMonth(selectedDate.month)} ${selectedDate.year}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await _selectTime(context, true);
                          setModalState(() {});
                        },
                        child: _buildTimeInput('Start Time', _startTime),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await _selectTime(context, false);
                          setModalState(() {});
                        },
                        child: _buildTimeInput('End Time', _endTime),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _saveNewSlot(onUpdate: setModalState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('SAVE SLOT', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.5,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildWeekSelector(),
                      const SizedBox(height: 20),
                      _buildWeeklyCalendar(),
                      const SizedBox(height: 40),
                      _buildActiveSlotsHeader(),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        ))
                      else if (_slots.where((slot) => slot['date'] == '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}').isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text('No slots for this date', style: TextStyle(color: Color(0xFF94A3B8))),
                        ))
                      else
                        Column(
                          children: () {
                            final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                            final now = DateTime.now();
                            final daySlots = _slots.where((slot) {
                              if (slot['date'] != dateStr) return false;
                              
                              try {
                                String timeStr = slot['start_time'] ?? '00:00';
                                final slotDateTime = DateTime.parse('${slot['date']}T$timeStr');
                                return slotDateTime.isAfter(now);
                              } catch (e) {
                                return true; // Keep if we can't parse
                              }
                            }).toList();
                            
                            if (daySlots.isEmpty) {
                              return [
                                const Center(child: Padding(
                                  padding: EdgeInsets.all(40.0),
                                  child: Text('No upcoming slots for this date', style: TextStyle(color: Color(0xFF94A3B8))),
                                ))
                              ];
                            }

                            return daySlots.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var slot = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildSessionCard(
                                id: (idx + 1).toString().padLeft(2, '0'),
                                label: slot['label'] ?? 'SESSION',
                                startTime: slot['start_time'] ?? '00:00',
                                endTime: slot['end_time'] ?? '00:00',
                                accentColor: slot['accentColor'] ?? AppColors.silver500,
                                onDelete: () => _removeSlot(slot['id'].toString()),
                              ),
                            );
                          }).toList();
                        }(),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 120), // Bottom space
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    bool canPop = Navigator.canPop(context);
    if (!canPop) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [

        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
          child: const Text(
            'Working\nAvailability',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Precision clinical scheduling',
          style: TextStyle(
            color: Color(0xFF94A3B8), // Brighter silver/grey
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildWeekSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT MONTH',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getMonth(_viewDate.month) + ' ' + _viewDate.year.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.keyboard_arrow_left_rounded, color: Colors.white, size: 24),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildWeeklyCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT DATE',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 85,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _visibleDates.length,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final date = _visibleDates[index];
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final itemDate = DateTime(date.year, date.month, date.day);
              bool isPast = itemDate.isBefore(today);
              
              bool isActive = selectedDate.day == date.day && selectedDate.month == date.month && selectedDate.year == date.year;
              
              return GestureDetector(
                onTap: isPast ? null : () => _updateDate(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Colors.white.withOpacity(0.12) 
                        : (isPast ? Colors.transparent : Colors.white.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive 
                          ? Colors.white.withOpacity(0.3) 
                          : (isPast ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.05)),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekDays[date.weekday % 7],
                        style: TextStyle(
                          color: isPast 
                              ? Colors.white.withOpacity(0.1) 
                              : (isActive ? Colors.white : const Color(0xFF94A3B8)),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: isPast ? Colors.white.withOpacity(0.1) : Colors.white,
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
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildActiveSlotsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'ACTIVE TIME SLOTS',
          style: TextStyle(
            color: AppColors.silver500,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        GestureDetector(
          onTap: _handleAddSlot,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.add, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Add Slot',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard({
    required String id,
    required String label,
    required String startTime,
    required String endTime,
    required Color accentColor,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Slightly lighter than black for contrast
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Session $id',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15, // Slightly larger
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: accentColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
                icon: const Icon(Icons.close, color: AppColors.silver500, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTimeInput('Start', startTime)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeInput('End', endTime)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInput(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF94A3B8), // Brighter label
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17, // Larger time text
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.silver500, size: 18),
            ],
          ),
        ),
      ],
    );
  }

}
