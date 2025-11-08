import 'package:latlong2/latlong.dart';

class RouteResponse {
  final RouteConnection route;
  final List<RouteFeature> nearbyRoutes;

  RouteResponse({
    required this.route,
    required this.nearbyRoutes,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    return RouteResponse(
      route: RouteConnection.fromJson(json['route']),
      nearbyRoutes: (json['nearbyRoutes'] as List)
          .map((route) => RouteFeature.fromJson(route))
          .toList(),
    );
  }
}

class RouteConnection {
  final String type;
  final RouteProperties properties;
  final RouteGeometry geometry;

  RouteConnection({
    required this.type,
    required this.properties,
    required this.geometry,
  });

  factory RouteConnection.fromJson(Map<String, dynamic> json) {
    return RouteConnection(
      type: json['type'],
      properties: RouteProperties.fromJson(json['properties']),
      geometry: RouteGeometry.fromJson(json['geometry']),
    );
  }
}

class RouteProperties {
  final RouteStation from;
  final RouteStation to;
  final double distance;
  final String type;

  RouteProperties({
    required this.from,
    required this.to,
    required this.distance,
    required this.type,
  });

  factory RouteProperties.fromJson(Map<String, dynamic> json) {
    return RouteProperties(
      from: RouteStation.fromJson(json['from']),
      to: RouteStation.fromJson(json['to']),
      distance: json['distance'].toDouble(),
      type: json['type'],
    );
  }
}

class RouteStation {
  final String id;
  final String name;
  final LatLng coordinates;

  RouteStation({
    required this.id,
    required this.name,
    required this.coordinates,
  });

  factory RouteStation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List;
    return RouteStation(
      id: json['id'].toString(),
      name: json['name'],
      coordinates: LatLng(coords[1].toDouble(), coords[0].toDouble()), // lat, lng
    );
  }
}

class RouteGeometry {
  final String type;
  final List<LatLng> coordinates;

  RouteGeometry({
    required this.type,
    required this.coordinates,
  });

  factory RouteGeometry.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List;
    return RouteGeometry(
      type: json['type'],
      coordinates: coords
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList(),
    );
  }
}

class RouteFeature {
  final String type;
  final String id;
  final Map<String, dynamic> properties;
  final List<LatLng> coordinates;

  RouteFeature({
    required this.type,
    required this.id,
    required this.properties,
    required this.coordinates,
  });

  factory RouteFeature.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    List<LatLng> coords = [];
    
    if (geometry['type'] == 'LineString') {
      coords = (geometry['coordinates'] as List)
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList();
    } else if (geometry['type'] == 'MultiLineString') {
      for (var lineString in geometry['coordinates']) {
        coords.addAll((lineString as List)
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList());
      }
    }

    return RouteFeature(
      type: json['type'],
      id: json['id'].toString(),
      properties: json['properties'],
      coordinates: coords,
    );
  }
}