# Navigatio Frontend 📱

> Flutter-basierte mobile App für ÖPNV-Navigation in Berlin mit OpenStreetMap-Integration

## 🎯 Übersicht

Die **Navigatio Frontend** ist eine moderne Flutter-App, die eine intuitive Benutzeroberfläche für die Navigation mit öffentlichen Verkehrsmitteln in Berlin bietet. Sie kombiniert interaktive Karten mit Echtzeit-ÖPNV-Daten.

## ✨ Features

### 🎨 **Moderne UI**
- **💧 Liquid Glass Design** - Transparente UI mit Blur-Effekten
- **📱 Edge-to-Edge** - Vollbild-Erlebnis ohne störende Ränder  
- **🌙 Dark/Light Mode** - Automatische Kartenstil-Anpassung
- **🎬 Smooth Animations** - 60fps Zoom- und Bewegungsanimationen

### 🗺️ **Karten-Features**
- **Interactive Maps** - Basiert auf flutter_map mit OSM/CartoDB Tiles
- **ÖPNV-Layer** - Live-Anzeige aller Berliner Verkehrslinien
- **Station Search** - TypeAhead-Suche mit Autocomplete
- **Routing** - GraphHopper-Integration für präzise Navigation

### 📱 **Mobile-Optimiert**
- **Geolocation** - Automatische Standorterkennung
- **Responsive Design** - Optimiert für verschiedene Bildschirmgrößen  
- **Platform-Native** - Android & iOS Support
- **Performance** - Lazy Loading und intelligentes Caching

## 🏗️ App-Architektur

```
lib/
├── 🚀 main.dart                    # App Entry Point & System UI Setup
├── 📊 models/                      # Datenmodelle
│   ├── map_styles.dart            # Kartenstil-Definitionen  
│   ├── station_models.dart        # ÖPNV-Station Datenstrukturen
│   └── route_models.dart          # GraphHopper Route Models
├── 🔧 services/                   # Business Logic & API
│   └── station_service.dart      # Backend-Kommunikation
└── 🎨 widgets/                    # UI-Komponenten
    ├── connection_search_widget.dart  # Stationssuche
    └── route_details_sheet.dart      # Route-Detail-Ansicht
```

## 🛠️ Setup & Installation

### **Voraussetzungen**
- Flutter SDK >=3.9.2
- Dart SDK >=3.0.0
- Android Studio / Xcode (für Geräte-Deployment)

### **Dependencies installieren**
```bash
flutter pub get
```

### **App starten**
```bash
# Debug Mode
flutter run

# Release Mode  
flutter run --release

# Spezifisches Device
flutter run -d <device-id>

# Web Development
flutter run -d web-server --web-port 8080
```

### **Build für Produktion**
```bash
# Android APK
flutter build apk --release

# iOS IPA (nur auf macOS)
flutter build ipa --release

# Web Build
flutter build web --release
```

## 🔧 Technische Details

### **📦 Key Dependencies**

| Package | Version | Zweck |
|---------|---------|-------|
| `flutter_map` | ^7.0.2 | Interaktive OpenStreetMap-Integration |
| `latlong2` | ^0.9.1 | GPS-Koordinaten und geometrische Berechnungen |
| `geolocator` | ^12.0.0 | Geolocation Services & Permissions |
| `http` | ^1.1.0 | REST API Client für Backend-Kommunikation |
| `flutter_typeahead` | ^5.2.0 | Autocomplete Station Search |

### **🎨 UI-Komponenten**

**MapWidget** - Hauptkartenansicht:
```dart
FlutterMap(
  options: MapOptions(
    center: LatLng(52.5170, 13.3889), // Berlin Zentrum
    zoom: 13.0,
    maxZoom: 18.0,
    minZoom: 10.0,
  ),
  children: [
    TileLayer(urlTemplate: mapStyle.urlTemplate),
    PolylineLayer(polylines: routeLines),
    MarkerLayer(markers: stationMarkers),
  ],
)
```

**ConnectionSearchWidget** - Station Search:
```dart
TypeAheadFormField<Station>(
  textFieldConfiguration: TextFieldConfiguration(
    decoration: InputDecoration(
      hintText: 'Von Station...',
      prefixIcon: Icon(Icons.search),
    ),
  ),
  suggestionsCallback: (pattern) => 
    StationService.searchStations(pattern),
  itemBuilder: (context, station) => 
    StationListTile(station: station),
)
```

### **📡 API-Integration**

**Backend-Kommunikation:**
```dart
class StationService {
  static const String baseUrl = 'http://localhost:3000/api';
  
  // ÖPNV-Linien laden
  static Future<List<Route>> loadRoutes(BoundingBox bounds) async {
    final response = await http.get(Uri.parse(
      '$baseUrl/routes?west=${bounds.west}&south=${bounds.south}'
      '&east=${bounds.east}&north=${bounds.north}'
    ));
    return RouteResponse.fromJson(jsonDecode(response.body)).routes;
  }
  
  // Stationen suchen
  static Future<List<Station>> searchStations(String query) async {
    if (query.length < 2) return [];
    final response = await http.get(Uri.parse(
      '$baseUrl/stations/search?q=${Uri.encodeComponent(query)}&limit=10'
    ));
    return StationResponse.fromJson(jsonDecode(response.body)).stations;
  }
}
```

## 🎮 Bedienung

### **🗺️ Karten-Navigation**
- **Pinch-to-Zoom**: Zwei Finger zum Zoomen
- **Pan**: Ein Finger zum Bewegen der Karte
- **Tap**: Marker antippen für Details
- **Long Press**: Koordinaten anzeigen

### **🚊 ÖPNV-Modus**
1. **🚂-Button** rechts oben antippen
2. Verkehrslinien werden automatisch geladen
3. Karte zoomen/bewegen für neue Bereiche
4. Linien antippen für Detailinformationen

### **🔍 Stationssuche**
1. Suchfeld oben antippen  
2. Mindestens 2 Zeichen eingeben
3. Aus Vorschlägen auswählen
4. Route zwischen Stationen berechnen lassen

## 🚀 Performance-Optimierungen

### **📊 Smart Loading**
```dart
// Debounced Map Movement
Timer? _debounce;
void _onMapMove() {
  _debounce?.cancel();
  _debounce = Timer(Duration(milliseconds: 500), () {
    _loadVisibleRoutes();
  });
}

// Adaptive Bounding Box
double _getBoundingBoxBuffer(double zoomLevel) {
  return math.max(0.01, (18 - zoomLevel) * 0.005);
}
```

### **🧠 Memory Management**
- **Lazy Loading** - Nur sichtbare Map-Tiles laden
- **Cache Invalidation** - Alte Daten automatisch entfernen
- **Image Optimization** - Marker-Icons effizient verwalten

## 🐛 Debugging & Testing

### **🔍 Debug-Befehle**
```bash
# Flutter Diagnose
flutter doctor -v

# Dependency-Check
flutter pub deps

# Performance Profile
flutter run --profile

# Widget-Tests
flutter test

# Integration Tests
flutter drive --target=test_driver/app.dart
```

### **📱 Device Testing**
```bash
# Verfügbare Devices anzeigen
flutter devices

# Spezifisches Device
flutter run -d <device-name>

# iOS Simulator
flutter run -d "iPhone 14 Pro"

# Android Emulator
flutter run -d android
```

### **🔧 Häufige Probleme**

| Problem | Lösung |
|---------|--------|
| **Geolocation Permission** | `flutter pub add permission_handler` |
| **HTTP Network Error** | Backend-URL in StationService prüfen |
| **Map Tiles nicht ladend** | Internet-Verbindung und Tile-Server prüfen |
| **Build Fehler** | `flutter clean && flutter pub get` |

## 🚀 Roadmap

### **Q1 2026**
- [ ] 🔄 **Offline Maps** - Lokale Tile-Speicherung
- [ ] ♿ **Accessibility** - Screen Reader Support
- [ ] 🌐 **Internationalization** - i18n Support

### **Q2 2026**  
- [ ] 📱 **iOS Widget** - Home Screen Integration
- [ ] 🔔 **Push Notifications** - Verspätungs-Alerts
- [ ] 🎨 **Custom Themes** - Personalisierbare UI

## 📝 Contributing

### **🧪 Testing Guidelines**
```dart
// Widget Tests Beispiel
testWidgets('Station search shows results', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());
  await tester.enterText(find.byKey(Key('search-field')), 'Alexander');
  await tester.pump(Duration(seconds: 1));
  expect(find.text('Alexanderplatz'), findsOneWidget);
});
```

### **📏 Code Standards**
- **Dart Style Guide** befolgen
- **Widget-Tests** für neue Features
- **Performance** - 60fps Target
- **Accessibility** - Semantic Labels

---

📱 **Navigatio Frontend** - Teil der intelligenten ÖPNV-Navigation für Berlin

[🔙 Zurück zur Haupt-README](../README.md)