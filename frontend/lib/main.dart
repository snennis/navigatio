import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'models/map_styles.dart';

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
  bool _isLoading = true;
  bool _hasLocationPermission = false;

  // Kartenstil-Auswahl
  MapStyle _currentMapStyle = MapStyle.availableStyles[0]; // Standard OSM

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Standort-Berechtigung überprüfen
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Aktuellen Standort abrufen
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _hasLocationPermission = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Abrufen des Standorts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Erstelle modernen Standort-Marker
  Widget _buildLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Äußerer Kreis (Schatten-Effekt)
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        // Mittlerer weißer Ring
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        // Innerer blauer Punkt
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  // Hell/Dunkel Modus Toggle
  void _toggleDarkMode() {
    setState(() {
      if (_currentMapStyle.name.contains('Dunkel')) {
        // Wechsel zu Hell
        _currentMapStyle = MapStyle.availableStyles.firstWhere(
          (style) => style.name.contains('Hell'),
        );
      } else {
        // Wechsel zu Dunkel
        _currentMapStyle = MapStyle.availableStyles.firstWhere(
          (style) => style.name.contains('Dunkel'),
        );
      }
    });

    // Bestätigung anzeigen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gewechselt zu: ${_currentMapStyle.name}'),
        duration: const Duration(seconds: 2),
        backgroundColor: _currentMapStyle.name.contains('Dunkel')
            ? Colors.grey.shade800
            : Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigatio - OSM Karte'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Hell/Dunkel Modus Toggle
          IconButton(
            icon: Icon(
              _currentMapStyle.name.contains('Dunkel')
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: _toggleDarkMode,
            tooltip: 'Hell/Dunkel Modus wechseln',
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
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 12.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    // Dynamische Tile Layer basierend auf ausgewähltem Stil
                    TileLayer(
                      urlTemplate: _currentMapStyle.urlTemplate,
                      subdomains: _currentMapStyle.subdomains ?? [],
                      userAgentPackageName: 'com.example.navigatio',
                      maxZoom: 18,
                    ),
                    // Standort-Marker Layer
                    if (_hasLocationPermission)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation,
                            width: 32,
                            height: 32,
                            child: _buildLocationMarker(),
                          ),
                        ],
                      ),
                  ],
                ),
                // Kartenstil-Indikator unten links
                Positioned(
                  bottom: 20,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentMapStyle.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
