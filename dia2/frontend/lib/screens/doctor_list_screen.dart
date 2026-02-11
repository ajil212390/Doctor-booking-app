import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/doctor_service.dart';
import '../services/location_service.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  List<Map<String, dynamic>> _allDoctors = []; // original unfiltered list
  List<Map<String, dynamic>> _doctors = [];    // filtered/sorted list for display
  bool _isLoading = true;
  String? _error;
  bool _locationEnabled = false;
  String _sortMode = 'distance'; // 'distance' or 'name'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get doctors from API
      final doctors = await DoctorService().getApprovedDoctors();
      
      // Try to get user location
      Map<String, double>? userLocation = await _locationService.getSavedLocation();
      
      if (userLocation == null) {
        final position = await _locationService.getCurrentLocation();
        if (position != null) {
          userLocation = {'lat': position.latitude, 'lon': position.longitude};
        }
      }

      if (userLocation != null) {
        // Sort by distance
        _allDoctors = _locationService.sortDoctorsByDistance(doctors, userLocation);
        _locationEnabled = true;
      } else {
        // No location, just convert to list
        _allDoctors = doctors.map((d) => {
          ...Map<String, dynamic>.from(d),
          'distance': null,
          'distance_display': 'Location unavailable',
        }).toList();
        _locationEnabled = false;
      }

      _filterAndSortDoctors();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getDoctorName(Map<String, dynamic> doc) {
    return (doc['full_name'] ?? doc['name'] ?? doc['user']?['name'] ?? '').toString().toLowerCase();
  }

  void _filterAndSortDoctors() {
    // Filter by search query
    List<Map<String, dynamic>> filtered = _allDoctors;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = _allDoctors.where((doc) {
        final name = _getDoctorName(doc);
        final qualification = (doc['qualification'] ?? doc['specialization'] ?? '').toString().toLowerCase();
        final city = (doc['city'] ?? '').toString().toLowerCase();
        return name.contains(query) || qualification.contains(query) || city.contains(query);
      }).toList();
    }

    // Sort
    if (_sortMode == 'name') {
      filtered.sort((a, b) {
        final nameA = _getDoctorName(a);
        final nameB = _getDoctorName(b);
        return nameA.compareTo(nameB);
      });
    } else {
      filtered.sort((a, b) {
        final distA = a['distance'] as double?;
        final distB = b['distance'] as double?;
        if (distA == null && distB == null) return 0;
        if (distA == null) return 1;
        if (distB == null) return -1;
        return distA.compareTo(distB);
      });
    }

    setState(() {
      _doctors = filtered;
    });
  }

  void _toggleSortMode() {
    _sortMode = _sortMode == 'distance' ? 'name' : 'distance';
    _filterAndSortDoctors();
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
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF0A0A0A),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: _isLoading && _doctors.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.white70))
              : _error != null && _doctors.isEmpty
                ? _buildErrorState(_error!)
                : RefreshIndicator(
                    onRefresh: _loadDoctors,
                    color: Colors.white,
                    backgroundColor: const Color(0xFF1A1A1A),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        _buildHeader(_allDoctors.length),
                        if (_doctors.isEmpty)
                          SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final doc = _doctors[index];
                                  return _buildDoctorCard(context, doc, index);
                                },
                                childCount: _doctors.length,
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
          ),
          

        ],
      ),
    );
  }

  Widget _buildHeader(int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: ShaderMask(
                shaderCallback: (bounds) => AppColors.silverGradient.createShader(bounds),
                child: Text(
                  'Medical\nSpecialists',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name, specialization, city...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _filterAndSortDoctors();
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.3),
                            size: 18,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _filterAndSortDoctors();
                },
              ),
            ),
            const SizedBox(height: 16),
            // Sort, Location and Count chips
            Row(
              children: [
                // Active count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                  ),
                  child: Text(
                    '$count ACTIVE',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Location Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _locationEnabled 
                        ? Colors.greenAccent.withOpacity(0.1) 
                        : Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _locationEnabled 
                          ? Colors.greenAccent.withOpacity(0.3) 
                          : Colors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _locationEnabled ? Icons.location_on : Icons.location_off,
                        size: 14,
                        color: _locationEnabled ? Colors.greenAccent : Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _locationEnabled ? 'Near You' : 'Location Off',
                        style: TextStyle(
                          color: _locationEnabled ? Colors.greenAccent : Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Sort Toggle
                GestureDetector(
                  onTap: _toggleSortMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sortMode == 'distance' ? Icons.near_me : Icons.sort_by_alpha,
                          size: 14,
                          color: AppColors.silver400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sortMode == 'distance' ? 'By Distance' : 'By Name',
                          style: const TextStyle(
                            color: AppColors.silver400,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, Map<String, dynamic> doc, int index) {
    final String fullName = doc['full_name'] ?? 'Dr. Unknown';
    final String specialization = doc['qualification'] ?? doc['specialization'] ?? 'Specialist';
    final String city = doc['city'] ?? '';
    final String distanceDisplay = doc['distance_display'] ?? '';
    final double? distance = doc['distance'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context, 
          '/book-appointment', 
          arguments: doc,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.01)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distance Badge
                    Row(
                      children: [
                        Icon(
                          distance != null ? Icons.near_me : Icons.location_off,
                          size: 10,
                          color: distance != null 
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distance != null ? distanceDisplay : city.isNotEmpty ? city : 'Location unknown',
                          style: TextStyle(
                            color: distance != null 
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName.replaceAll('Dr. ', ''),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialization.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          (doc['average_rating'] ?? doc['rating'])?.toStringAsFixed(1) ?? '4.5',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${doc['review_count'] ?? '12'})',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'BOOK NOW',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Doctor Avatar
              Container(
                width: 60, 
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: doc['profile_picture'] != null 
                    ? Image.network(
                        doc['profile_picture'].toString().startsWith('http') 
                          ? doc['profile_picture'] 
                          : '${ApiConfig.baseUrl.replaceAll('/api/', '')}${doc['profile_picture']}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person,
                          size: 32,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.white.withOpacity(0.2),
                      ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (index * 80).ms, duration: 500.ms).slideY(begin: 0.08, end: 0),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 24),
          Text(
            'No Doctors Available',
            style: GoogleFonts.plusJakartaSans(fontSize: 24, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Failed to load specialists',
              style: GoogleFonts.plusJakartaSans(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadDoctors,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}
