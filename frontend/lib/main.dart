import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'models/map_styles.dart';
import 'models/station_models.dart';
import 'models/route_models.dart';
import 'services/station_service.dart';
import 'widgets/connection_search_widget.dart';
import 'widgets/route_details_sheet.dart';

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

  // User Location
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Connection Search
  ConnectionSearch _connectionSearch = ConnectionSearch();
  bool _showConnectionSearch = false;

  // Route Display - Updated to use GraphHopper
  GraphHopperRouteResponse? _currentRoute;
  bool _showRouteDetails = false;

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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
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
            _showRouteDetails = true;
          });

          // Zoom to route bounds
          _zoomToRoute(route);
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
  void _zoomToRoute(GraphHopperRouteResponse route) {
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

  // Clear route and return to normal map view
  void _clearRoute() {
    setState(() {
      _currentRoute = null;
      _showRouteDetails = false;
    });
  }

  // Show route details sheet
  void _showRouteDetailsSheet() {
    if (_currentRoute == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => RouteDetailsSheet(
          routeResponse: _currentRoute!,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
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
                heroTag: "details",
                onPressed: _showRouteDetailsSheet,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                elevation: 2,
                child: const Icon(Icons.info_outline_rounded),
              ),
            ),
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
                        // Railway network loading removed - no longer needed
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
                        // GraphHopper Route Line (Main route from GraphHopper)
                        if (_currentRoute != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points:
                                    _currentRoute!.route.geometry.coordinates,
                                strokeWidth: 6.0,
                                color: Colors.blue,
                                borderStrokeWidth: 2.0,
                                borderColor: Colors.white,
                              ),
                            ],
                          ),
                        // Display the actual transit routes (S-Bahn, U-Bahn, Tram, Bus, etc.)
                        if (_currentRoute != null &&
                            _currentRoute!.nearbyRoutes.isNotEmpty) ...[
                          // Transit Routes (alle ÖPNV-Linien in der Nähe der Route)
                          PolylineLayer(
                            polylines: _currentRoute!.nearbyRoutes.map((route) {
                              // Farben je nach Transportmittel
                              Color routeColor = Colors.blue; // Default
                              double strokeWidth = 4.0;

                              String transportType =
                                  route.properties['type'] ??
                                  route.properties['route'] ??
                                  route.properties['railway'] ??
                                  route.properties['highway'] ??
                                  route.properties['public_transport'] ??
                                  '';

                              // Erweiterte Transportmittel-Erkennung
                              if (transportType.isEmpty ||
                                  transportType == 'unknown') {
                                if (route.properties.containsKey('ref')) {
                                  final ref = route.properties['ref']
                                      .toString();
                                  if (ref.startsWith('U')) {
                                    transportType = 'subway';
                                  } else if (ref.startsWith('S')) {
                                    transportType = 'light_rail';
                                  } else {
                                    transportType = 'bus';
                                  }
                                } else if (route.properties.containsKey(
                                  'name',
                                )) {
                                  final name = route.properties['name']
                                      .toString()
                                      .toLowerCase();
                                  if (name.contains('u-bahn') ||
                                      name.contains('u ')) {
                                    transportType = 'subway';
                                  } else if (name.contains('s-bahn') ||
                                      name.contains('s ')) {
                                    transportType = 'light_rail';
                                  } else if (name.contains('tram')) {
                                    transportType = 'tram';
                                  } else if (name.contains('bus')) {
                                    transportType = 'bus';
                                  } else if (name.contains('walk') ||
                                      name.contains('fuß')) {
                                    transportType = 'walking';
                                  }
                                }
                              }

                              // Spezielle Behandlung für highway = 'bus_guideway'
                              if (route.properties['highway'] ==
                                  'bus_guideway') {
                                transportType = 'bus';
                              }

                              switch (transportType.toLowerCase()) {
                                case 'subway':
                                case 'u-bahn':
                                  routeColor = Colors.blue; // U-Bahn blau
                                  strokeWidth = 5.0;
                                  break;
                                case 'light_rail':
                                case 's-bahn':
                                case 'suburban':
                                  routeColor = Colors.green; // S-Bahn grün
                                  strokeWidth = 5.0;
                                  break;
                                case 'tram':
                                case 'streetcar':
                                  routeColor = Colors.red; // Tram rot
                                  strokeWidth = 4.0;
                                  break;
                                case 'bus':
                                  routeColor = Colors.purple; // Bus lila
                                  strokeWidth = 3.0;
                                  break;
                                case 'train':
                                case 'rail':
                                case 'railway':
                                  routeColor = Colors.orange; // Zug orange
                                  strokeWidth = 5.0;
                                  break;
                                case 'ferry':
                                  routeColor = Colors.cyan; // Fähre cyan
                                  strokeWidth = 4.0;
                                  break;
                                case 'walking':
                                case 'foot':
                                  routeColor = Colors
                                      .green
                                      .shade700; // Fußweg dunkelgrün
                                  strokeWidth = 3.0;
                                  break;
                                default:
                                  // Fallback basierend auf anderen Properties
                                  if (route.properties.containsKey('ref')) {
                                    final ref = route.properties['ref']
                                        .toString();
                                    if (ref.startsWith('U')) {
                                      routeColor = Colors.blue; // U-Bahn
                                      strokeWidth = 5.0;
                                    } else if (ref.startsWith('S')) {
                                      routeColor = Colors.green; // S-Bahn
                                      strokeWidth = 5.0;
                                    } else {
                                      routeColor = Colors.purple; // Bus
                                      strokeWidth = 3.0;
                                    }
                                  } else {
                                    routeColor = Colors.blue; // Standard
                                    strokeWidth = 4.0;
                                  }
                              }

                              return Polyline(
                                points: route.coordinates,
                                strokeWidth: strokeWidth,
                                color: routeColor,
                              );
                            }).toList(),
                          ),
                        ],
                        // Start and End Markers (always show when route exists)
                        if (_currentRoute != null)
                          MarkerLayer(
                            markers: [
                              // Start Marker
                              Marker(
                                point: _currentRoute!
                                    .route
                                    .properties
                                    .from
                                    .coordinates,
                                width: 50,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
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
                                point: _currentRoute!
                                    .route
                                    .properties
                                    .to
                                    .coordinates,
                                width: 50,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.stop,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

                  // Transport Legend (when route is active)
                  if (_currentRoute != null &&
                      _currentRoute!.nearbyRoutes.isNotEmpty)
                    Positioned(
                      bottom: 100,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transportmittel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._getActiveLegendItems(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  List<Widget> _getActiveLegendItems() {
    if (_currentRoute == null || _currentRoute!.nearbyRoutes.isEmpty) return [];

    Set<String> activeTypes = {};
    for (var route in _currentRoute!.nearbyRoutes) {
      String type =
          route.properties['type'] ??
          route.properties['route'] ??
          route.properties['railway'] ??
          route.properties['highway'] ??
          route.properties['public_transport'] ??
          'unknown';

      // Erweiterte Klassifizierung basierend auf verschiedenen Properties
      if (type == 'unknown' || type.isEmpty) {
        if (route.properties.containsKey('ref')) {
          final ref = route.properties['ref'].toString();
          if (ref.startsWith('U')) {
            type = 'subway';
          } else if (ref.startsWith('S')) {
            type = 'light_rail';
          } else {
            type = 'bus';
          }
        } else if (route.properties.containsKey('name')) {
          final name = route.properties['name'].toString().toLowerCase();
          if (name.contains('u-bahn') || name.contains('u ')) {
            type = 'subway';
          } else if (name.contains('s-bahn') || name.contains('s ')) {
            type = 'light_rail';
          } else if (name.contains('tram') || name.contains('straßenbahn')) {
            type = 'tram';
          } else if (name.contains('bus')) {
            type = 'bus';
          } else if (name.contains('walk') ||
              name.contains('fuß') ||
              name.contains('foot')) {
            type = 'walking';
          }
        }
      }

      // Spezielle Behandlung für highway = 'bus_guideway'
      if (route.properties['highway'] == 'bus_guideway') {
        type = 'bus';
      }

      activeTypes.add(type);
    }

    return activeTypes.map((type) {
      Color color;
      String label;
      IconData icon;

      switch (type.toLowerCase()) {
        case 'subway':
        case 'u-bahn':
          color = Colors.blue;
          label = 'U-Bahn';
          icon = Icons.subway;
          break;
        case 'light_rail':
        case 's-bahn':
        case 'suburban':
          color = Colors.green;
          label = 'S-Bahn';
          icon = Icons.train;
          break;
        case 'tram':
        case 'streetcar':
          color = Colors.red;
          label = 'Tram';
          icon = Icons.tram;
          break;
        case 'bus':
          color = Colors.purple;
          label = 'Bus';
          icon = Icons.directions_bus;
          break;
        case 'train':
        case 'rail':
        case 'railway':
          color = Colors.orange;
          label = 'Zug';
          icon = Icons.train;
          break;
        case 'ferry':
          color = Colors.cyan;
          label = 'Fähre';
          icon = Icons.directions_boat;
          break;
        case 'walking':
        case 'foot':
          color = Colors.green.shade700;
          label = 'Fußweg';
          icon = Icons.directions_walk;
          break;
        default:
          color = Colors.grey;
          label = 'Andere';
          icon = Icons.help;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Container(width: 20, height: 3, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Calculates distance between two LatLng points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius in meters

    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLng = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}
