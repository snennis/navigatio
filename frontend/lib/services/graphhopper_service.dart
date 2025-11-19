import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_models.dart';

/// Service für die Kommunikation mit GraphHopper über das Backend
class GraphHopperService {
  static const String baseUrl = 'http://localhost:3000/api';

  /// Berechnet eine Route zwischen zwei Koordinaten unter Verwendung von GraphHopper
  /// Die Anfrage läuft über unser Backend, das mit GraphHopper kommuniziert
  static Future<GraphHopperRouteResponse?> calculateRoute({
    required String fromStationId,
    required String toStationId,
  }) async {
    try {
      print(
        'Requesting route from $fromStationId to $toStationId via GraphHopper',
      );

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/routes/calculate?from=$fromStationId&to=$toStationId',
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('GraphHopper request timeout');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print(
          'GraphHopper route received: ${data['route']['properties']['distance']}km',
        );
        return GraphHopperRouteResponse.fromJson(data);
      } else {
        print('Error from backend: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calculating route with GraphHopper: $e');
      return null;
    }
  }

  /// Prüft, ob GraphHopper verfügbar ist
  static Future<bool> isAvailable() async {
    try {
      // Test durch einen einfachen Health-Check
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      print('GraphHopper availability check failed: $e');
      return false;
    }
  }
}
