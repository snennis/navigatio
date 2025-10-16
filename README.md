# 📍 Navigatio

> **Navigation App für iOS, Android & Web**  
> *Universitätsprojekt - 5. Semester*

Eine moderne Flutter-basierte Navigations-App mit OpenStreetMap-Integration, die auf allen Plattformen läuft - ohne API-Keys oder Kosten!

## 🚀 Features

- 🗺️ **OpenStreetMap Integration** - Kostenlose, offene Kartengrundlage
- 📱 **Cross-Platform** - iOS, Android & Web Support
- 📍 **GPS-Standorterkennung** - Automatische Positionsbestimmung
- 🎮 **Interactive Maps** - Zoom, Pan und Marker-Support  
- 🔒 **Privacy-First** - Keine Google/Apple Maps Dependencies
- ⚡ **Performance** - Optimiert für mobile Geräte

## 📁 Projektstruktur

```
navigatio/
├── frontend/          # Flutter App
│   ├── lib/          # Dart Source Code
│   ├── android/      # Android-spezifische Konfiguration
│   ├── ios/          # iOS-spezifische Konfiguration
│   └── web/          # Web-spezifische Konfiguration
├── backend/          # (Future) Backend Services
└── README.md         # Diese Datei
```

## 🛠️ Installation & Setup

### Voraussetzungen
- Flutter SDK (>=3.9.2)
- Dart SDK
- Android Studio / Xcode (für mobile Entwicklung)
- Git

### 1. Repository klonen
```bash
git clone https://github.com/snennis/navigatio.git
cd navigatio/frontend
```

### 2. Dependencies installieren
```bash
flutter pub get
```

### 3. App starten

#### Web (Chrome)
```bash
flutter run -d chrome
```

#### Android (Gerät/Emulator)
```bash
flutter run -d android
```

#### iOS (iPhone/Simulator)  
```bash
flutter run -d ios
```

#### Verfügbare Geräte anzeigen
```bash
flutter devices
```

## 📦 Verwendete Packages

- **flutter_map** `^7.0.2` - OpenStreetMap Integration
- **latlong2** `^0.9.1` - Koordinaten-Handling  
- **geolocator** `^12.0.0` - GPS & Location Services
- **cupertino_icons** `^1.0.8` - iOS-Style Icons

## 🔧 Konfiguration

### Android Berechtigungen
Die App benötigt folgende Berechtigungen in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS Berechtigungen  
Standort-Berechtigungen in `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Diese App benötigt Zugriff auf Ihren Standort für die Navigation.</string>
```

## 🎯 Funktionen

### Aktuelle Features
- ✅ Interactive OpenStreetMap
- ✅ GPS-Standorterkennung  
- ✅ Zoom-Kontrollen (In/Out)
- ✅ Standort-Marker
- ✅ "Mein Standort" Button
- ✅ Cross-Platform Support

### Geplante Features  
- 🔄 Navigation & Routing
- 🔄 Offline-Karten
- 🔄 POI (Points of Interest)
- 🔄 Favoriten-System
- 🔄 Backend-Integration

## 🏗️ Entwicklung

### Hot Reload
Während der Entwicklung kannst du Hot Reload verwenden:
- **r** - Hot Reload
- **R** - Hot Restart  
- **q** - App beenden

### Build für Production
```bash
# Android APK
flutter build apk

# iOS IPA  
flutter build ios

# Web
flutter build web
```

## 🤝 Beitragen

1. Fork das Repository
2. Erstelle einen Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Committe deine Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Push zum Branch (`git push origin feature/AmazingFeature`)
5. Öffne eine Pull Request

## 🆘 Troubleshooting

### Häufige Probleme

**1. "No pubspec.yaml file found"**
```bash
# Stelle sicher, dass du im frontend/ Ordner bist
cd frontend/
```

**2. Standort-Berechtigung verweigert**
- Android: Berechtigungen in den App-Einstellungen aktivieren
- iOS: Standort-Zugriff in iOS-Einstellungen erlauben

**3. Karten laden nicht**  
- Internet-Verbindung überprüfen
- Firewall/Proxy-Einstellungen kontrollieren

---

*Letztes Update: Oktober 2025*
