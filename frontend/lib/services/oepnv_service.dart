import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/oepnv_models.dart';

class OepnvService {
  static const String baseUrl = 'http://localhost:3000/api';

  // Get ÖPNV stops within bounding box
  static Future<List<OepnvData>> getStops({
    double? west,
    double? south,
    double? east,
    double? north,
  }) async {
    try {
      String url = '$baseUrl/stops';

      // Add bounding box if provided
      if (west != null && south != null && east != null && north != null) {
        url += '?bbox=$west,$south,$east,$north';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features.map((feature) => OepnvData.fromJson(feature)).toList();
      } else {
        throw Exception('Failed to load ÖPNV stops: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading ÖPNV stops: $e');
      return [];
    }
  }

  // Get ÖPNV routes within bounding box
  static Future<List<OepnvRoute>> getRoutes({
    double? west,
    double? south,
    double? east,
    double? north,
  }) async {
    try {
      String url = '$baseUrl/routes';

      if (west != null && south != null && east != null && north != null) {
        url += '?bbox=$west,$south,$east,$north';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features.map((feature) => OepnvRoute.fromJson(feature)).toList();
      } else {
        throw Exception('Failed to load ÖPNV routes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading ÖPNV routes: $e');
      return [];
    }
  }

  // Get stops around a specific location
  static Future<List<OepnvData>> getStopsAroundLocation(
    double latitude,
    double longitude, {
    double radiusKm = 1.0,
  }) async {
    // Calculate approximate bounding box (rough calculation)
    const kmToDegree = 0.009; // Approximate conversion
    final offset = radiusKm * kmToDegree;

    return getStops(
      west: longitude - offset,
      south: latitude - offset,
      east: longitude + offset,
      north: latitude + offset,
    );
  }
}
