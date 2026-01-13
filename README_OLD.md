# Navigatio 🗺️

Eine moderne Flutter-Navigation-App mit ÖPNV-Integration für Berlin, die PostgreSQL/PostGIS-Datenbanken mit OpenStreetMap-Daten nutzt.

## ✨ Features

### 🎨 **Moderne UI/UX**
- **Liquid Glass Design** - Moderne, transparente UI-Elemente
- **Edge-to-Edge Display** - Vollbild-Kartenerlebnis
- **Smooth Animations** - Flüssige Zoom- und Bewegungsanimationen
- **Floating Controls** - Schwebende Steuerelemente wie in professionellen Apps
- **Hell/Dunkel Modus** - Verschiedene Kartenstile verfügbar

### � **ÖPNV-Integration**
- **Echte Berliner Daten** - Direkte Integration mit PostgreSQL/PostGIS-Datenbank
- **U-Bahn-Linien** - Visualisierung des kompletten U-Bahn-Netzes
- **Farbkodierung** - Unterschiedliche Farben für verschiedene Verkehrsmittel:
  - � U-Bahn: Blau
  - 🟢 S-Bahn: Grün  
  - 🟣 Bus: Lila
  - 🩷 Tram: Rosa
  - 🔴 Regionalbahn: Rot

### 🚀 **Performance**
- **Smart Caching** - 5-Minuten-Cache für API-Abfragen
- **Intelligente Bounding Boxes** - Zoom-basiertes Laden von Daten
- **Debounced Loading** - Optimierte Datenabfragen beim Kartenbewegen

## 🏗️ Architektur

```
├── frontend/           # Flutter App
│   ├── lib/
│   │   ├── models/     # Datenmodelle (ÖPNV, Kartenstile)
│   │   ├── services/   # API-Services
│   │   └── main.dart   # Haupt-App
│   └── pubspec.yaml
└── backend/            # Node.js API Server
    ├── server.js       # Express Server mit PostGIS
    ├── package.json
    └── README.md
```

## 🛠️ Installation

### **Voraussetzungen**
- Flutter SDK (>=3.0.0)
- Node.js (>=16.0.0)
- PostgreSQL mit PostGIS-Extension
- OSM-Daten in osm2pgsql-Format

### **Backend Setup**

1. **Dependencies installieren:**
```bash
cd backend
npm install
```

2. **Umgebungsvariablen konfigurieren:**
```bash
# Kopiere die Vorlage und bearbeite sie
cp .env.example .env
nano .env

# Oder direkt erstellen:
cat > .env << EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=osm2pgsql
DB_USER=your_username
DB_PASSWORD=your_password
PORT=3000
EOF
```

3. **Datenbank vorbereiten:**
```sql
-- PostgreSQL-Berechtigungen setzen
GRANT SELECT ON ALL TABLES IN SCHEMA public TO your_username;
```

4. **Server starten:**
```bash
npm start
```

### **Frontend Setup**

1. **Dependencies installieren:**
```bash
cd frontend
flutter pub get
```

2. **App starten:**
```bash
flutter run
```

## 📡 API Endpoints

### **Routen**
```http
GET /api/routes?west=13.2&south=52.4&east=13.5&north=52.6
```

### **Haltestellen** (derzeit deaktiviert)
```http
GET /api/stops?west=13.2&south=52.4&east=13.5&north=52.6
```

### **Cache-Management**
```http
GET /cache/stats     # Cache-Statistiken
DELETE /cache        # Cache leeren
```

### **Health Check**
```http
GET /health          # Server-Status
```

## �️ Datenbank Schema

Die App nutzt das Standard-osm2pgsql-Schema:

- **`planet_osm_line`** - Für Verkehrslinien (U-Bahn, S-Bahn, etc.)
- **`planet_osm_point`** - Für Haltestellen und Stationen

### **Wichtige Spalten:**
- `route` - Art der Route (subway, bus, tram, etc.)
- `railway` - Bahnart (subway, rail, tram, etc.)
- `name` - Name der Linie/Station
- `way` - PostGIS-Geometrie

## 🎮 Bedienung

### **Karten-Navigation**
- **Pinch-to-Zoom** - Zoomen mit zwei Fingern
- **Pan** - Karte mit einem Finger bewegen
- **Zoom-Buttons** - Floating Action Buttons rechts

### **ÖPNV-Modus**
1. **🚂-Button** rechts oben antippen
2. **U-Bahn-Linien** werden automatisch geladen
3. **Karte bewegen** - Neue Daten werden automatisch nachgeladen

### **Kartenstile**
- **🌙/☀️-Button** - Zwischen Hell- und Dunkelmodus wechseln
- **Verschiedene Provider** - OSM, CartoDB, etc.

## 🔧 Technische Details

### **Frontend (Flutter)**
- **flutter_map** - Karten-Widget
- **latlong2** - Koordinaten-Handling
- **http** - API-Kommunikation
- **geolocator** - GPS-Zugriff

### **Backend (Node.js)**
- **Express** - Web-Framework
- **pg** - PostgreSQL-Client
- **cors** - Cross-Origin-Handling
- **dotenv** - Umgebungsvariablen

### **Datenbank**
- **PostgreSQL** - Haupt-Datenbank
- **PostGIS** - Räumliche Erweiterung
- **osm2pgsql** - OSM-Datenimport

## 🚀 Performance-Optimierungen

### **Caching-System**
- **In-Memory Cache** - 5 Minuten TTL
- **Smart Keys** - Gerundete Koordinaten für bessere Cache-Hits
- **Automatic Cleanup** - Abgelaufene Einträge werden automatisch entfernt

### **Data Loading**
- **Bounding Box Filtering** - Nur sichtbare Bereiche laden
- **Zoom-based Limits** - Datenmenge basierend auf Zoom-Level
- **Debounced Requests** - Verhindert zu häufige API-Calls

### **UI Optimizations**
- **Smooth Animations** - 60 FPS Zoom-Animationen
- **Efficient Rendering** - Nur sichtbare Elemente rendern
- **Memory Management** - Automatische Bereinigung alter Daten

## 🐛 Troubleshooting

### **Backend-Probleme**
```bash
# Datenbankverbindung testen
psql -U your_username -d osm2pgsql -c "SELECT count(*) FROM planet_osm_line;"

# Logs prüfen
npm start  # Siehe Console-Output
```

### **Frontend-Probleme**
```bash
# Flutter-Diagnose
flutter doctor

# Dependencies neu laden
flutter clean && flutter pub get
```

### **Häufige Fehler**
- **"role does not exist"** → PostgreSQL-Benutzer in .env prüfen
- **"permission denied"** → GRANT-Rechte für Tabellen setzen
- **"No routes loaded"** → Datenbank-Inhalt und WHERE-Clause prüfen

## 📈 Roadmap

- [ ] **Routing-Integration** - Turn-by-Turn-Navigation
- [ ] **Offline-Karten** - Lokale Kartendaten
- [ ] **Real-time ÖPNV** - Live-Verspätungen
- [ ] **Multi-Modal** - Kombinierte Verkehrsmittel
- [ ] **Accessibility** - Barrierefreiheit
- [ ] **PWA Support** - Web-Version

## 🤝 Contributing

1. Fork das Repository
2. Feature-Branch erstellen (`git checkout -b feature/amazing-feature`)
3. Changes committen (`git commit -m 'Add amazing feature'`)
4. Branch pushen (`git push origin feature/amazing-feature`)
5. Pull Request öffnen

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert.

## 👥 Autoren

- **Dennis** - Initial work - Navigation App für 5. Semester

## 🙏 Danksagungen

- **OpenStreetMap** - Geodaten
- **Flutter Team** - Framework
- **PostGIS** - Räumliche Datenbank-Erweiterung
- **osm2pgsql** - OSM-Import-Tool
