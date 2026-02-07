import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _latKey = 'user_latitude';
  static const String _lonKey = 'user_longitude';

  // City coordinates for distance calculation (India)
  static final Map<String, Map<String, double>> cityCoordinates = {
    // Kerala
    'thiruvananthapuram': {'lat': 8.5241, 'lon': 76.9366},
    'trivandrum': {'lat': 8.5241, 'lon': 76.9366},
    'kochi': {'lat': 9.9312, 'lon': 76.2673},
    'cochin': {'lat': 9.9312, 'lon': 76.2673},
    'ernakulam': {'lat': 9.9816, 'lon': 76.2999},
    'kozhikode': {'lat': 11.2588, 'lon': 75.7804},
    'calicut': {'lat': 11.2588, 'lon': 75.7804},
    'thrissur': {'lat': 10.5276, 'lon': 76.2144},
    'kollam': {'lat': 8.8932, 'lon': 76.6141},
    'palakkad': {'lat': 10.7867, 'lon': 76.6548},
    'alappuzha': {'lat': 9.4981, 'lon': 76.3388},
    'kannur': {'lat': 11.8745, 'lon': 75.3704},
    'kottayam': {'lat': 9.5916, 'lon': 76.5222},
    'malappuram': {'lat': 11.0510, 'lon': 76.0711},
    'kasaragod': {'lat': 12.4996, 'lon': 74.9869},
    'pathanamthitta': {'lat': 9.2648, 'lon': 76.7870},
    'idukki': {'lat': 9.8494, 'lon': 76.9710},
    'wayanad': {'lat': 11.6854, 'lon': 76.1320},
    
    // Major Indian Cities
    'mumbai': {'lat': 19.0760, 'lon': 72.8777},
    'delhi': {'lat': 28.7041, 'lon': 77.1025},
    'new delhi': {'lat': 28.6139, 'lon': 77.2090},
    'bangalore': {'lat': 12.9716, 'lon': 77.5946},
    'bengaluru': {'lat': 12.9716, 'lon': 77.5946},
    'hyderabad': {'lat': 17.3850, 'lon': 78.4867},
    'chennai': {'lat': 13.0827, 'lon': 80.2707},
    'kolkata': {'lat': 22.5726, 'lon': 88.3639},
    'pune': {'lat': 18.5204, 'lon': 73.8567},
    'ahmedabad': {'lat': 23.0225, 'lon': 72.5714},
    'jaipur': {'lat': 26.9124, 'lon': 75.7873},
    'lucknow': {'lat': 26.8467, 'lon': 80.9462},
    'chandigarh': {'lat': 30.7333, 'lon': 76.7794},
    'coimbatore': {'lat': 11.0168, 'lon': 76.9558},
    'madurai': {'lat': 9.9252, 'lon': 78.1198},
    'mangalore': {'lat': 12.9141, 'lon': 74.8560},
    'mysore': {'lat': 12.2958, 'lon': 76.6394},
    'mysuru': {'lat': 12.2958, 'lon': 76.6394},
  };

  /// Get current user location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, position.latitude);
      await prefs.setDouble(_lonKey, position.longitude);

      return position;
    } catch (e) {
      return null;
    }
  }

  /// Get saved user location
  Future<Map<String, double>?> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lon = prefs.getDouble(_lonKey);

    if (lat != null && lon != null) {
      return {'lat': lat, 'lon': lon};
    }
    return null;
  }

  /// Get coordinates for a city name
  Map<String, double>? getCityCoordinates(String? cityName) {
    if (cityName == null || cityName.isEmpty) return null;
    
    final normalizedCity = cityName.toLowerCase().trim();
    return cityCoordinates[normalizedCity];
  }

  /// Calculate distance between two points using Haversine formula
  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371; // kilometers

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// Calculate distance from user to doctor's city
  double? getDistanceToDoctor(
    Map<String, double> userLocation,
    String? doctorCity,
  ) {
    final doctorCoords = getCityCoordinates(doctorCity);
    if (doctorCoords == null) return null;

    return calculateDistance(
      userLocation['lat']!,
      userLocation['lon']!,
      doctorCoords['lat']!,
      doctorCoords['lon']!,
    );
  }

  /// Sort doctors by distance from user
  List<Map<String, dynamic>> sortDoctorsByDistance(
    List<dynamic> doctors,
    Map<String, double> userLocation,
  ) {
    final List<Map<String, dynamic>> doctorsWithDistance = [];

    for (final doc in doctors) {
      final city = doc['city']?.toString();
      final distance = getDistanceToDoctor(userLocation, city);
      
      doctorsWithDistance.add({
        ...Map<String, dynamic>.from(doc),
        'distance': distance,
        'distance_display': distance != null 
            ? (distance < 1 ? '${(distance * 1000).toInt()} m' : '${distance.toStringAsFixed(1)} km')
            : 'Unknown',
      });
    }

    // Sort: known distances first (ascending), then unknown
    doctorsWithDistance.sort((a, b) {
      final distA = a['distance'] as double?;
      final distB = b['distance'] as double?;
      
      if (distA == null && distB == null) return 0;
      if (distA == null) return 1;
      if (distB == null) return -1;
      
      return distA.compareTo(distB);
    });

    return doctorsWithDistance;
  }
}
