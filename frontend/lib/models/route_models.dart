import 'package:latlong2/latlong.dart';

// ===== GraphHopper Models =====

/// Response von GraphHopper über das Backend
class GraphHopperRouteResponse {
  final RouteConnection route;
  final List<GraphHopperInstruction> instructions;
  final List<RouteFeature> nearbyRoutes;

  GraphHopperRouteResponse({
    required this.route,
    required this.instructions,
    required this.nearbyRoutes,
  });

  factory GraphHopperRouteResponse.fromJson(Map<String, dynamic> json) {
    return GraphHopperRouteResponse(
      route: RouteConnection.fromJson(json['route']),
      instructions: (json['instructions'] as List? ?? [])
          .map((instruction) => GraphHopperInstruction.fromJson(instruction))
          .toList(),
      nearbyRoutes: (json['nearbyRoutes'] as List? ?? [])
          .map((route) => RouteFeature.fromJson(route))
          .toList(),
    );
  }
}

/// GraphHopper Wegbeschreibung (Turn-by-Turn)
class GraphHopperInstruction {
  final double distance;
  final int time;
  final String text;
  final int sign;
  final List<int> interval;

  GraphHopperInstruction({
    required this.distance,
    required this.time,
    required this.text,
    required this.sign,
    required this.interval,
  });

  factory GraphHopperInstruction.fromJson(Map<String, dynamic> json) {
    return GraphHopperInstruction(
      distance: (json['distance'] ?? 0).toDouble(),
      time: (json['time'] ?? 0).toInt(),
      text: json['text'] ?? '',
      sign: (json['sign'] ?? 0).toInt(),
      interval: (json['interval'] as List? ?? []).map((i) => i as int).toList(),
    );
  }

  /// Gibt eine Beschreibung der Wegrichtung zurück
  String getDirectionDescription() {
    switch (sign) {
      case -98:
        return 'U-Turn';
      case -8:
        return 'Scharf links abbiegen';
      case -7:
        return 'Links abbiegen';
      case -6:
        return 'Leicht links abbiegen';
      case -3:
        return 'Links halten';
      case 0:
        return 'Geradeaus';
      case 1:
        return 'Leicht rechts abbiegen';
      case 2:
        return 'Rechts abbiegen';
      case 3:
        return 'Scharf rechts abbiegen';
      case 4:
        return 'Ziel erreicht';
      case 5:
        return 'Über Kreisverkehr';
      case 6:
        return 'Kreisverkehr verlassen';
      case -2:
        return 'Links halten';
      default:
        return 'Weiter';
    }
  }

  /// Formatiert die Entfernung
  String getFormattedDistance() {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Formatiert die Zeit
  String getFormattedTime() {
    final minutes = (time / 60000).round();
    if (minutes < 1) {
      return '< 1 Min';
    }
    return '$minutes Min';
  }
}

// ===== Original Models (backward compatible) =====

class RouteResponse {
  final RouteConnection route;
  final List<RouteFeature> nearbyRoutes;

  RouteResponse({required this.route, required this.nearbyRoutes});

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
  final double? duration; // Optional: Zeit in Sekunden
  final String type;
  final String? source; // Optional: 'graphhopper' oder 'fallback'
  final String? profile; // Optional: Profil (z.B. 'foot', 'car', 'pt')
  final int? transfers; // Optional: Anzahl Umstiege bei PT
  final List<RouteLeg>? legs; // Optional: PT-Legs (verschiedene Abschnitte)

  RouteProperties({
    required this.from,
    required this.to,
    required this.distance,
    this.duration,
    required this.type,
    this.source,
    this.profile,
    this.transfers,
    this.legs,
  });

  factory RouteProperties.fromJson(Map<String, dynamic> json) {
    return RouteProperties(
      from: RouteStation.fromJson(json['from']),
      to: RouteStation.fromJson(json['to']),
      distance: json['distance'].toDouble(),
      duration: json['duration']?.toDouble(),
      type: json['type'],
      source: json['source'],
      profile: json['profile'],
      transfers: json['transfers']?.toInt(),
      legs: json['legs'] != null
          ? (json['legs'] as List).map((leg) => RouteLeg.fromJson(leg)).toList()
          : null,
    );
  }

  /// Formatiert die Entfernung
  String getFormattedDistance() {
    // ÖPNV: Summiere Distanzen aller Legs
    if (isPublicTransport() && legs != null && legs!.isNotEmpty) {
      final sum = legs!.map((l) => l.distance ?? 0).fold(0.0, (a, b) => a + b);

      if (sum < 1000) {
        return '${sum.toStringAsFixed(0)}m';
      } else {
        return '${(sum / 1000).toStringAsFixed(1)}km';
      }
    }

    // Standard (Fußweg, Auto, Fahrrad)
    if (distance < 1) {
      return '${(distance * 1000).toStringAsFixed(0)}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  /// Formatiert die Dauer
  String getFormattedDuration() {
    if (duration == null) return '';
    final minutes = (duration! / 60).round();
    if (minutes < 60) {
      return '$minutes Min';
    } else {
      final hours = (minutes / 60).floor();
      final mins = minutes % 60;
      return '${hours}h ${mins}min';
    }
  }

  /// Prüft ob es eine ÖPNV-Route ist
  bool isPublicTransport() {
    return profile == 'pt' || type == 'public_transport';
  }
}

/// Ein Abschnitt (Leg) einer ÖPNV-Route
class RouteLeg {
  final String? type; // z.B. 'pt', 'walk', 'bike'
  final String? departureLocation;
  final String? arrivalLocation;
  final double? distance;
  final double? duration;
  final String? routeId; // z.B. 'U7', 'S1'
  final String? headsign; // Richtung
  final Map<String, dynamic>? geometry;

  RouteLeg({
    this.type,
    this.departureLocation,
    this.arrivalLocation,
    this.distance,
    this.duration,
    this.routeId,
    this.headsign,
    this.geometry,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      type: json['type'],
      departureLocation:
          json['departureLocation'] ?? json['departure_location'],
      arrivalLocation: json['arrivalLocation'] ?? json['arrival_location'],
      distance: json['distance']?.toDouble(),
      duration: json['duration']?.toDouble(),
      routeId: json['routeId'] ?? json['route_id'] ?? json['trip_id'],
      headsign: json['headsign'] ?? json['trip_headsign'],
      geometry: json['geometry'],
    );
  }

  /// Gibt den Typ als lesbaren Text zurück
  String getTypeLabel() {
    switch (type?.toLowerCase()) {
      case 'pt':
        return 'ÖPNV';
      case 'walk':
        return 'Zu Fuß';
      case 'bike':
        return 'Fahrrad';
      default:
        return type ?? 'Unbekannt';
    }
  }

  /// Formatiert die Entfernung
  String getFormattedDistance() {
    if (distance == null) return '';
    if (distance! < 1000) {
      return '${distance!.toStringAsFixed(0)}m';
    } else {
      return '${(distance! / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Formatiert die Dauer
  String getFormattedDuration() {
    if (duration == null) return '';
    final minutes = (duration! / 60).round();
    return '$minutes Min';
  }
}

class RouteStation {
  final String id;
  final String name;
  final String? type; // Optional: Typ der Haltestelle
  final LatLng coordinates;

  RouteStation({
    required this.id,
    required this.name,
    this.type,
    required this.coordinates,
  });

  factory RouteStation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List;
    return RouteStation(
      id: json['id'].toString(),
      name: json['name'],
      type: json['type'],
      coordinates: LatLng(
        coords[1].toDouble(),
        coords[0].toDouble(),
      ), // lat, lng
    );
  }
}

class RouteGeometry {
  final String type;
  final List<LatLng> coordinates;

  RouteGeometry({required this.type, required this.coordinates});

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
        coords.addAll(
          (lineString as List)
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList(),
        );
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

// ======================================================
// Transit Mode Model
// ======================================================

class UsedTransitMode {
  final String type; // subway, bus, tram, walking
  final String label; // U7, S1, M45, etc.
  final double distance; // meters
  final double duration; // seconds

  UsedTransitMode({
    required this.type,
    required this.label,
    required this.distance,
    required this.duration,
  });
}

// ======================================================
// Transit Extractor Extension
// ======================================================

extension TransitExtract on GraphHopperRouteResponse {
  List<UsedTransitMode> getUsedTransitModes() {
    final legs = route.properties.legs;
    if (legs == null || legs.isEmpty) return [];

    final result = <UsedTransitMode>[];

    for (final leg in legs) {
      final id = (leg.routeId ?? "").trim();
      final headsign = (leg.headsign ?? "").trim();
      final rawType = (leg.type ?? "").toLowerCase();

      String normalized = "unknown";

      if (rawType.contains("walk")) {
        normalized = "walking";
      } else if (id.startsWith("U")) {
        normalized = "subway";
      } else if (id.startsWith("S")) {
        normalized = "s-bahn";
      } else if (id.startsWith("M") ||
          headsign.toLowerCase().contains("tram")) {
        normalized = "tram";
      } else if (_isBus(id, headsign)) {
        normalized = "bus";
      } else if (rawType.contains("pt")) {
        normalized = "public_transport";
      }

      result.add(
        UsedTransitMode(
          type: normalized,
          label: id.isNotEmpty ? id : rawType,
          distance: leg.distance ?? 0,
          duration: leg.duration ?? 0,
        ),
      );
    }

    return result;
  }

  bool _isBus(String id, String headsign) {
    final first = id.isNotEmpty ? id[0] : "";
    final numericStart = int.tryParse(first) != null;

    final text = headsign.toLowerCase();
    return numericStart || text.contains("bus") || text.contains("line");
  }
}
