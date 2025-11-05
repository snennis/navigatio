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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(
    52.520008,
    13.404954,
  ); // Default: Berlin
  bool _isLoading = true;

  // Kartenstil-Auswahl
  MapStyle _currentMapStyle = MapStyle.availableStyles[0]; // Standard OSM

  // Animation Controller für smooth zooming
  late AnimationController _zoomAnimationController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // Animation Controller für smooth zooming
    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300), // 300ms smooth animation
      vsync: this,
    );
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    super.dispose();
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

  // Smooth Zoom In Animation
  void _smoothZoomIn() async {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom + 1).clamp(3.0, 18.0);

    if (currentZoom >= 18.0) {
      // Feedback bei maximalem Zoom
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.zoom_in, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Maximaler Zoom erreicht'),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      return;
    }

    // Smooth step-by-step zooming
    const steps = 8;
    const stepDuration = 35; // milliseconds per step
    final zoomIncrement = (targetZoom - currentZoom) / steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: stepDuration));
      final newZoom = currentZoom + (zoomIncrement * i);
      _mapController.move(_mapController.camera.center, newZoom);
    }
  }

  // Smooth Zoom Out Animation
  void _smoothZoomOut() async {
    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom - 1).clamp(3.0, 18.0);

    if (currentZoom <= 3.0) {
      // Feedback bei minimalem Zoom
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.zoom_out, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Minimaler Zoom erreicht'),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      return;
    }

    // Smooth step-by-step zooming
    const steps = 8;
    const stepDuration = 35; // milliseconds per step
    final zoomDecrement = (currentZoom - targetZoom) / steps;

    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: stepDuration));
      final newZoom = currentZoom - (zoomDecrement * i);
      _mapController.move(_mapController.camera.center, newZoom);
    }
  }

  // Schwimmende Controls (rechts, wie bei Miles)
  Widget _buildFloatingControls() {
    return Positioned(
      right: 20,
      top: MediaQuery.of(context).padding.top + 12,
      child: Column(
        children: [
          // Theme Toggle Button
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton(
              heroTag: "theme",
              onPressed: _toggleDarkMode,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              child: Icon(
                _currentMapStyle.name.contains('Dunkel')
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
            ),
          ),
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
          // Smooth Zoom In
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: "zoom_in",
              onPressed: _smoothZoomIn,
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 1,
              mini: true,
              child: const Icon(Icons.add, size: 18),
            ),
          ),
          // Smooth Zoom Out
          Container(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: "zoom_out",
              onPressed: _smoothZoomOut,
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
                        // Smooth Interaktionen aktivieren
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                          enableMultiFingerGestureRace: true,
                          scrollWheelVelocity: 0.005, // Smooth scroll wheel
                        ),
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
                  // Schwimmende Control-Buttons (rechts)
                  _buildFloatingControls(),
                ],
              ),
            ),
    );
  }
}
