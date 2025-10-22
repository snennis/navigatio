import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigatio - OSM Karten App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(
    52.520008,
    13.404954,
  ); // Default: Berlin
  List<Marker> _markers = [];
  List<Marker> _userMarkers = []; // Benutzer-gesetzte Marker
  bool _isLoading = true;
  bool _isAddingMarker = false; // Modus zum Marker setzen

  @override
  void initState() {
    super.initState();
    _setDefaultMarker();
    _getCurrentLocation();
  }

  void _setDefaultMarker() {
    setState(() {
      _updateLocationMarker();
      _isLoading = false;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Standort-Berechtigung überprüfen
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Aktuellen Standort abrufen
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateLocationMarker();
      });
    } catch (e) {
      print('Fehler beim Abrufen des Standorts: $e');
      // Fallback bereits in _setDefaultMarker() gesetzt
    }
  }

  void _updateLocationMarker() {
    _markers = [
      Marker(
        point: _currentLocation,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
    ];
  }

  void _toggleMarkerMode() {
    setState(() {
      _isAddingMarker = !_isAddingMarker;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isAddingMarker
              ? 'Tippe auf die Karte, um einen Marker zu setzen'
              : 'Marker-Modus deaktiviert',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addMarkerAtPosition(LatLng position) {
    if (!_isAddingMarker) return;

    setState(() {
      _userMarkers.add(
        Marker(
          point: position,
          width: 35,
          height: 35,
          child: GestureDetector(
            onTap: () => _showMarkerDialog(position),
            child: const Icon(Icons.place, color: Colors.orange, size: 35),
          ),
        ),
      );
      _isAddingMarker = false; // Automatisch deaktivieren nach dem Setzen
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Marker gesetzt bei ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        ),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () => _removeLastMarker(),
        ),
      ),
    );
  }

  void _removeLastMarker() {
    if (_userMarkers.isNotEmpty) {
      setState(() {
        _userMarkers.removeLast();
      });
    }
  }

  void _clearAllUserMarkers() {
    setState(() {
      _userMarkers.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alle Marker entfernt')));
  }

  void _showMarkerDialog(LatLng position) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Marker Info'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latitude: ${position.latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${position.longitude.toStringAsFixed(6)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userMarkers.removeWhere(
                    (marker) => marker.point == position,
                  );
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marker entfernt')),
                );
              },
              child: const Text('Entfernen'),
            ),
          ],
        );
      },
    );
  }

  List<Marker> _getAllMarkers() {
    return [..._markers, ..._userMarkers];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigatio - OSM Karte'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              _isAddingMarker ? Icons.place : Icons.add_location,
              color: _isAddingMarker ? Colors.orange : null,
            ),
            onPressed: _toggleMarkerMode,
            tooltip: _isAddingMarker
                ? 'Marker-Modus beenden'
                : 'Marker hinzufügen',
          ),
          if (_userMarkers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllUserMarkers,
              tooltip: 'Alle Marker löschen',
            ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Aktueller Standort',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Lade Karte...'),
                ],
              ),
            )
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 12.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onTap: (tapPosition, point) {
                  if (_isAddingMarker) {
                    _addMarkerAtPosition(point);
                  }
                },
              ),
              children: [
                // OpenStreetMap Tile Layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.navigatio',
                  maxZoom: 18,
                ),
                // Marker Layer mit allen Markern
                MarkerLayer(markers: _getAllMarkers()),
              ],
            ),
      bottomSheet: _userMarkers.isNotEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Text(
                '📍 ${_userMarkers.length} Marker gesetzt',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            )
          : null,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "zoom_in",
            mini: true,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom + 1,
              );
            },
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "zoom_out",
            mini: true,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom - 1,
              );
            },
            child: const Icon(Icons.zoom_out),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "my_location",
            onPressed: () {
              _mapController.move(_currentLocation, 15.0);
            },
            child: const Icon(Icons.gps_fixed),
          ),
        ],
      ),
    );
  }
}
