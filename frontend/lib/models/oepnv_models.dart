import 'package:latlong2/latlong.dart';

class OepnvData {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;

  OepnvData({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory OepnvData.fromJson(Map<String, dynamic> json) {
    final coordinates = json['geometry']['coordinates'] as List;
    return OepnvData(
      id: json['id'].toString(),
      name: json['properties']['name'] ?? 'Unknown',
      type: json['properties']['type'] ?? 'unknown',
      latitude: coordinates[1].toDouble(),
      longitude: coordinates[0].toDouble(),
    );
  }
}

class OepnvRoute {
  final String id;
  final String name;
  final String type;
  final List<LatLng> coordinates;

  OepnvRoute({
    required this.id,
    required this.name,
    required this.type,
    required this.coordinates,
  });

  factory OepnvRoute.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    List<LatLng> coords = [];

    if (geometry['type'] == 'LineString') {
      coords = (geometry['coordinates'] as List)
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList();
    }

    return OepnvRoute(
      id: json['id'].toString(),
      name: json['properties']['name'] ?? 'Unknown Route',
      type: json['properties']['type'] ?? 'unknown',
      coordinates: coords,
    );
  }
}
