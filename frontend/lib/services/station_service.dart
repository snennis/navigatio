import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station_models.dart';

class StationService {
  static const String baseUrl = 'http://localhost:3000/api';

  /// Suche nach Haltestellen mit Fuzzy Search
  static Future<List<Station>> searchStations(String query) async {
    if (query.isEmpty || query.length < 2) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stations/search?q=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) {
          try {
            return Station.fromJson(json);
          } catch (e) {
            print('Error parsing station: $json, Error: $e');
            return null;
          }
        }).where((station) => station != null).cast<Station>().toList();
      } else {
        print('Error searching stations: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error searching stations: $e');
      return [];
    }
  }

  /// Haltestelle anhand der ID abrufen
  static Future<Station?> getStationById(String id) async {
    try {
      final stations = await searchStations('');
      return stations.firstWhere(
        (station) => station.id == id,
        orElse: () => throw Exception('Station not found'),
      );
    } catch (e) {
      print('Error getting station by ID: $e');
      return null;
    }
  }
}
