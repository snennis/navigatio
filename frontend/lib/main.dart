import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'models/map_styles.dart';
import 'models/oepnv_models.dart';
import 'models/station_models.dart';
import 'models/route_models.dart';
import 'services/oepnv_service.dart';
import 'services/station_service.dart';
import 'widgets/connection_search_widget.dart';

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

  // ÖPNV Daten
  List<OepnvData> _oepnvStops = [];
  List<OepnvRoute> _oepnvRoutes = [];
  bool _showOepnvData = true;
  Timer? _debounceTimer;
  LatLng? _lastLoadedCenter;

  // User Location
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Connection Search
  ConnectionSearch _connectionSearch = ConnectionSearch();
  bool _showConnectionSearch = false;
  
  // Route Display
  RouteResponse? _currentRoute;
  bool _showOnlyRoute = false;

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
    _debounceTimer?.cancel();
    _positionStreamSubscription?.cancel();
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
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Karte zum aktuellen Standort bewegen
      _mapController.move(_userLocation!, 16.0);

      // Kontinuierliches Standort-Tracking starten
      _startLocationTracking();
    } catch (e) {
      print('Fehler beim Abrufen des Standorts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Kontinuierliches Standort-Tracking
  void _startLocationTracking() {
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update nur bei 10m Bewegung
          ),
        ).listen((Position position) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
          });
        });
  }

  // Zur aktuellen Position zurückkehren
  void _centerOnUserLocation() async {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16.0);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Zur aktuellen Position'),
            ],
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      // Falls noch kein Standort vorhanden, neu abrufen
      _getCurrentLocation();
    }
  }

  // Verbindungssuche anzeigen/verstecken
  void _toggleConnectionSearch() {
    setState(() {
      _showConnectionSearch = !_showConnectionSearch;
    });
  }

  // Verbindungssuche aktualisieren
  void _updateConnectionSearch(ConnectionSearch search) {
    setState(() {
      _connectionSearch = search;
    });
  }

  // Verbindung suchen
  void _searchConnection() async {
    if (_connectionSearch.isComplete) {
      try {
        setState(() {
          _showConnectionSearch = false; // Hide search widget
        });

        // Show loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 8),
                Text('Berechne Verbindung...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );

        // Calculate route
        final route = await StationService.calculateRoute(
          _connectionSearch.fromStation!.id,
          _connectionSearch.toStation!.id,
        );

        if (route != null) {
          setState(() {
            _currentRoute = route;
            _showOnlyRoute = true;
          });

          // Zoom to route bounds
          _zoomToRoute(route);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verbindung gefunden: ${route.route.properties.distance.toStringAsFixed(2)} km',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Verbindung gefunden'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler bei der Routenberechnung: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Zoom to route bounds
  void _zoomToRoute(RouteResponse route) {
    final fromCoord = route.route.properties.from.coordinates;
    final toCoord = route.route.properties.to.coordinates;
    
    // Calculate bounds
    final south = math.min(fromCoord.latitude, toCoord.latitude);
    final north = math.max(fromCoord.latitude, toCoord.latitude);
    final west = math.min(fromCoord.longitude, toCoord.longitude);
    final east = math.max(fromCoord.longitude, toCoord.longitude);
    
    // Add padding
    final padding = 0.01; // ~1km padding
    final bounds = LatLngBounds(
      LatLng(south - padding, west - padding),
      LatLng(north + padding, east + padding),
    );
    
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds));
  }

  // Clear route and show all ÖPNV data again
  void _clearRoute() {
    setState(() {
      _currentRoute = null;
      _showOnlyRoute = false;
    });
  }

  // ÖPNV Daten laden
  Future<void> _loadOepnvData() async {
    if (!_showOepnvData) return;

    try {
      // Erweiterte Bounding Box für ganz Berlin
      final center = _mapController.camera.center;
      final zoom = _mapController.camera.zoom;

      // Dynamische Bounding Box basierend auf Zoom-Level
      double delta = zoom > 12
          ? 0.02
          : zoom > 10
          ? 0.05
          : 0.1;

      final west = center.longitude - delta;
      final south = center.latitude - delta;
      final east = center.longitude + delta;
      final north = center.latitude + delta;

      print(
        '🔍 Loading ÖPNV data for bounds: W=$west S=$south E=$east N=$north (zoom=$zoom)',
      );

      // ÖPNV Routes laden (Stops erstmal deaktiviert)
      // final stops = await OepnvService.getStops(
      //   west: west,
      //   south: south,
      //   east: east,
      //   north: north,
      // );

      final routes = await OepnvService.getRoutes(
        west: west,
        south: south,
        east: east,
        north: north,
      );
      setState(() {
        // _oepnvStops = stops;
        _oepnvStops = []; // Keine Stops für jetzt
        _oepnvRoutes = routes;
      });

      print('✅ Loaded ${routes.length} ÖPNV routes (stops disabled)');

      // Erfolg-Feedback
      if (routes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.train, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('${routes.length} ÖPNV-Linien geladen'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading ÖPNV data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Fehler beim Laden der ÖPNV-Daten: $e'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
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
          // Connection Search Button
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: FloatingActionButton(
              heroTag: "search",
              onPressed: _toggleConnectionSearch,
              backgroundColor: _showConnectionSearch 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
              foregroundColor: _showConnectionSearch
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
              elevation: 2,
              child: const Icon(Icons.search_rounded),
            ),
          ),
          // Clear Route Button (only show when route is displayed)
          if (_currentRoute != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                heroTag: "clear",
                onPressed: _clearRoute,
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                elevation: 2,
                child: const Icon(Icons.clear_rounded),
              ),
            ),
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
          // Location Button with tracking indicator
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Stack(
              children: [
                FloatingActionButton(
                  heroTag: "location",
                  onPressed: _centerOnUserLocation,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 2,
                  child: const Icon(Icons.my_location_rounded),
                ),
                // Tracking indicator
                if (_positionStreamSubscription != null &&
                    !_positionStreamSubscription!.isPaused)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
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
          // ÖPNV Toggle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: "oepnv_toggle",
              onPressed: () {
                setState(() {
                  _showOepnvData = !_showOepnvData;
                });
                if (_showOepnvData) {
                  _loadOepnvData();
                }
              },
              backgroundColor: _showOepnvData
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              foregroundColor: _showOepnvData
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
              elevation: 1,
              mini: true,
              child: Icon(
                _showOepnvData ? Icons.train : Icons.train_outlined,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ÖPNV Hilfsfunktionen
  Color _getStopColor(String type) {
    switch (type.toLowerCase()) {
      case 'bus_stop':
      case 'bus':
        return Colors.purple; // Buslinien = Lila
      case 'tram_stop':
      case 'tram':
        return Colors.pink; // Tram = Rosa
      case 'subway_entrance':
      case 'station':
        return Colors.blue; // U-Bahn = Blau
      case 'halt':
      case 'railway_station':
      case 'rail':
        return Colors.green; // S-Bahn = Grün
      case 'train':
      case 'regional':
        return Colors.red; // Regionalbahnen = Rot
      case 'stop_position':
        return Colors.orange; // Allgemeine Haltestelle
      default:
        return Colors.grey;
    }
  }

  IconData _getStopIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bus_stop':
      case 'bus':
        return Icons.directions_bus;
      case 'tram_stop':
      case 'tram':
        return Icons.tram;
      case 'subway_entrance':
      case 'station':
        return Icons.subway;
      case 'railway_station':
      case 'train':
        return Icons.train;
      default:
        return Icons.place;
    }
  }

  Color _getRouteColor(String type) {
    switch (type.toLowerCase()) {
      case 'bus':
        return Colors.purple.withOpacity(0.8); // Buslinien = Lila
      case 'tram':
        return Colors.pink.withOpacity(0.8); // Tram = Rosa
      case 'subway':
      case 'u-bahn':
        return Colors.blue.withOpacity(0.8); // U-Bahn = Blau
      case 'rail':
      case 'railway':
      case 's-bahn':
        return Colors.green.withOpacity(0.8); // S-Bahn = Grün
      case 'train':
      case 'regional':
      case 'light_rail':
        return Colors.red.withOpacity(0.8); // Regionalbahnen = Rot
      default:
        return Colors.grey.withOpacity(0.8);
    }
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
                        // ÖPNV-Daten automatisch laden wenn Karte bewegt wird
                        onPositionChanged: (MapCamera camera, bool hasGesture) {
                          if (_showOepnvData && hasGesture) {
                            // Check if moved significantly (more than 0.01 degrees ≈ 1km)
                            if (_lastLoadedCenter == null ||
                                (_lastLoadedCenter!.latitude -
                                            camera.center.latitude)
                                        .abs() >
                                    0.01 ||
                                (_lastLoadedCenter!.longitude -
                                            camera.center.longitude)
                                        .abs() >
                                    0.01) {
                              _debounceTimer?.cancel();
                              _debounceTimer = Timer(
                                const Duration(milliseconds: 1000),
                                () {
                                  _lastLoadedCenter = camera.center;
                                  _loadOepnvData();
                                },
                              );
                            }
                          }
                        },
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
                        // ÖPNV Routen Layer (nur anzeigen wenn keine spezifische Route gewählt)
                        if (_showOepnvData && _oepnvRoutes.isNotEmpty && !_showOnlyRoute)
                          PolylineLayer(
                            polylines: _oepnvRoutes.map((route) {
                              return Polyline(
                                points: route.coordinates,
                                strokeWidth: 3.0,
                                color: _getRouteColor(route.type),
                              );
                            }).toList(),
                          ),
                        // ÖPNV Stops Layer (nur anzeigen wenn keine spezifische Route gewählt)
                        if (_showOepnvData && _oepnvStops.isNotEmpty && !_showOnlyRoute)
                          MarkerLayer(
                            markers: _oepnvStops.map((stop) {
                              return Marker(
                                point: stop.location,
                                width: 20,
                                height: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getStopColor(stop.type),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getStopIcon(stop.type),
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        // Current Route Layers (when route is selected)
                        if (_currentRoute != null) ...[
                          // Route Line
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _currentRoute!.route.geometry.coordinates,
                                strokeWidth: 5.0,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                          // Nearby Routes (for context)
                          PolylineLayer(
                            polylines: _currentRoute!.nearbyRoutes.map((route) {
                              return Polyline(
                                points: route.coordinates,
                                strokeWidth: 2.0,
                                color: Colors.grey.withOpacity(0.5),
                              );
                            }).toList(),
                          ),
                          // Start and End Markers
                          MarkerLayer(
                            markers: [
                              // Start Marker
                              Marker(
                                point: _currentRoute!.route.properties.from.coordinates,
                                width: 50,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              // End Marker
                              Marker(
                                point: _currentRoute!.route.properties.to.coordinates,
                                width: 50,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // User Location Marker (über allen anderen)
                        if (_userLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _userLocation!,
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Schwimmende Control-Buttons (rechts)
                  _buildFloatingControls(),

                  // Connection Search Widget (oben)
                  if (_showConnectionSearch)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 20,
                      left: 20,
                      right: 80, // Platz für die Control-Buttons
                      child: AnimatedOpacity(
                        opacity: _showConnectionSearch ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: ConnectionSearchWidget(
                          initialSearch: _connectionSearch,
                          onSearchChanged: _updateConnectionSearch,
                          onSearchPressed: _searchConnection,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
