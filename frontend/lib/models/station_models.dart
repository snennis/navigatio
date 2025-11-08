import 'package:latlong2/latlong.dart';

class Station {
  final int id;
  final String name;
  final String type;
  final LatLng coordinates;
  final double? similarity;

  Station({
    required this.id,
    required this.name,
    required this.type,
    required this.coordinates,
    this.similarity,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'],
      name: json['name'],
      type: json['type'] ?? 'unknown',
      coordinates: LatLng(
        json['coordinates']['lat'].toDouble(),
        json['coordinates']['lng'].toDouble(),
      ),
      similarity: json['similarity']?.toDouble(),
    );
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Station && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ConnectionSearch {
  final Station? fromStation;
  final Station? toStation;

  ConnectionSearch({this.fromStation, this.toStation});

  bool get isComplete => fromStation != null && toStation != null;

  ConnectionSearch copyWith({
    Station? fromStation,
    Station? toStation,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return ConnectionSearch(
      fromStation: clearFrom ? null : fromStation ?? this.fromStation,
      toStation: clearTo ? null : toStation ?? this.toStation,
    );
  }
}
