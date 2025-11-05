import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'models/map_styles.dart';

void main() {
  // System UI für Edge-to-Edge konfigurieren
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Edge-to-Edge Mode aktivieren
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigatio',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E88E5), // Uber-style Blue
          secondary: Color(0xFF26C6DA), // Teal accent
          surface: Color(0xFFF8F9FA),
          background: Color(0xFFF8F9FA),
          onSurface: Color(0xFF212121),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF212121),
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF42A5F5), // Lighter blue for dark theme
          secondary: Color(0xFF4DD0E1), // Lighter teal
          surface: Color(0xFF1A1A1A),
          background: Color(0xFF121212),
          onSurface: Color(0xFFFFFFFF),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
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
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Abrufen des Standorts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Moderne Top-Navigation (wie Uber)
  Widget _buildTopNavigationBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(
              Icons.navigation,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Navigatio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            // Theme Toggle Button
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _toggleDarkMode,
                icon: Icon(
                  _currentMapStyle.name.contains('Dunkel')
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                iconSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Schwimmende Controls (rechts, wie bei Miles)
  Widget _buildFloatingControls() {
    return Positioned(
      right: 20,
      top: MediaQuery.of(context).padding.top + 80,
      child: Column(
        children: [
          // Location Button
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton(
              heroTag: "location",
              onPressed: _getCurrentLocation,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.primary,
              elevation: 2,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          // Zoom In
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: "zoom_in",
              onPressed: () {
                final currentZoom = _mapController.camera.zoom;
                _mapController.move(
                  _mapController.camera.center,
                  currentZoom + 1,
                );
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 1,
              mini: true,
              child: const Icon(Icons.add, size: 18),
            ),
          ),
          // Zoom Out
          Container(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: "zoom_out",
              onPressed: () {
                final currentZoom = _mapController.camera.zoom;
                _mapController.move(
                  _mapController.camera.center,
                  currentZoom - 1,
                );
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 1,
              mini: true,
              child: const Icon(Icons.remove, size: 18),
            ),
          ),
        ],
      ),
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
      // Entferne AppBar komplett für echten Vollbildmodus
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
          : SizedBox.expand(
              child: Stack(
                children: [
                  // Vollbild-Karte die kompletten Bildschirm ausfüllt
                  Positioned.fill(
                    child: FlutterMap(
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
                      ],
                    ),
                  ),
                  // Moderne Top-Navigation Bar
                  _buildTopNavigationBar(),
                  // Schwimmende Control-Buttons (rechts)
                  _buildFloatingControls(),
                ],
              ),
            ),
    );
  }
}
