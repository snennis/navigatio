# GraphHopper Integration - Setup Guide

## Übersicht

Die App nutzt jetzt GraphHopper für das Routing zwischen Haltestellen. Der Workflow ist wie folgt:

1. **User sucht Haltestelle** → App sendet Anfrage an Backend (PostgreSQL)
2. **Backend findet Haltestellen** → Sendet Koordinaten zurück
3. **App kommuniziert mit GraphHopper** → Backend ruft GraphHopper API auf
4. **GraphHopper berechnet Route** → Sendet detaillierte Wegbeschreibung zurück
5. **App zeigt Route an** → Visualisierung auf der Karte + Detail-Sheet

## Voraussetzungen

### GraphHopper lokal installieren

1. **GraphHopper herunterladen:**
   ```bash
   wget https://repo1.maven.org/maven2/com/graphhopper/graphhopper-web/8.0/graphhopper-web-8.0.jar
   ```

2. **OSM-Daten herunterladen** (z.B. Berlin):
   ```bash
   wget https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf
   ```

3. **GraphHopper starten:**
   ```bash
   java -Ddw.graphhopper.datareader.file=berlin-latest.osm.pbf \
        -Ddw.graphhopper.graph.location=./graph-cache \
        -jar graphhopper-web-8.0.jar server config.yml
   ```

4. **GraphHopper UI öffnen:**
   ```
   http://localhost:8989/maps/?profile=foot&layer=OpenStreetMap
   ```

## Backend-Konfiguration

Die Backend-Konfiguration erfolgt über Umgebungsvariablen (`.env`):

```env
# PostgreSQL
DB_USER=your_user
DB_HOST=localhost
DB_NAME=your_db
DB_PASSWORD=your_password
DB_PORT=5432

# GraphHopper (optional, Standard-Werte werden verwendet)
GRAPHHOPPER_URL=http://localhost:8989
GRAPHHOPPER_PROFILE=foot
```

### Backend starten

```bash
cd backend
npm install
npm start
```

## Implementierte Features

### Backend (`backend/server.js`)

- ✅ GraphHopper API-Integration mit axios
- ✅ Fallback auf direkte Verbindung, wenn GraphHopper nicht verfügbar
- ✅ Erweiterte Haltestellensuche (mehrfache Haltestellen werden berücksichtigt)
- ✅ Nearby Routes für bessere Visualisierung

**Endpoint:** `GET /api/routes/calculate?from={stationId}&to={stationId}`

**Response-Struktur:**
```json
{
  "route": {
    "type": "Feature",
    "properties": {
      "from": { "id": "...", "name": "...", "type": "...", "coordinates": [...] },
      "to": { "id": "...", "name": "...", "type": "...", "coordinates": [...] },
      "distance": 1234.5,  // in km
      "duration": 789,     // in Sekunden
      "type": "graphhopper_route",
      "source": "graphhopper",
      "profile": "foot"
    },
    "geometry": {
      "type": "LineString",
      "coordinates": [[lng, lat], ...]
    }
  },
  "instructions": [
    {
      "distance": 100,
      "time": 60000,
      "text": "Geradeaus...",
      "sign": 0,
      "interval": [0, 5]
    }
  ],
  "nearbyRoutes": [...]
}
```

### Frontend

#### Neue Services

**`services/graphhopper_service.dart`**
- GraphHopper API-Kommunikation über Backend
- Timeout-Handling (15 Sekunden)
- Verfügbarkeitsprüfung

**`services/station_service.dart`** (aktualisiert)
- Verwendet GraphHopper für Routing
- Legacy-Methode für Rückwärtskompatibilität

#### Neue Models

**`models/route_models.dart`** (erweitert)
- `GraphHopperRouteResponse` - Vollständige Response mit Instructions
- `GraphHopperInstruction` - Turn-by-Turn Wegbeschreibungen
- `RouteProperties` - Erweitert um `duration`, `source`, `profile`
- Helper-Methoden für Formatierung

#### Neue Widgets

**`widgets/route_details_sheet.dart`**
- Detaillierte Routeninformationen
- Entfernung und Dauer
- Turn-by-Turn Wegbeschreibungen
- Start/Ziel Haltestellen
- Transportmittel-Icons

#### UI-Updates (`main.dart`)

- ✅ GraphHopper-Route als blaue Linie auf der Karte
- ✅ Nearby ÖPNV-Linien zur Orientierung
- ✅ Start/Ziel Marker
- ✅ "Details"-Button für Route-Informationen
- ✅ "Löschen"-Button zum Zurücksetzen
- ✅ Automatischer Zoom auf Route

## Verwendung

### 1. Haltestelle suchen

- Such-Button (🔍) in der App drücken
- Haltestellenname eingeben (min. 2 Zeichen)
- Start- und Zielhaltestelle auswählen

### 2. Route berechnen

- "Suchen"-Button drücken
- App zeigt Route auf der Karte an
- Success-Nachricht mit "Details"-Button erscheint

### 3. Route-Details anzeigen

- **Option 1:** "Details"-Button in Success-Nachricht drücken
- **Option 2:** Info-Button (ℹ️) in den Floating Controls drücken

**Details beinhalten:**
- Entfernung (in km/m)
- Dauer (in Minuten/Stunden)
- Transportmittel (Zu Fuß/Auto/Fahrrad)
- Start/Ziel Informationen
- Turn-by-Turn Wegbeschreibungen

### 4. Route löschen

- "X"-Button in den Floating Controls drücken

## Mehrfache Haltestellen

Die App berücksichtigt, dass Haltestellen mehrfach vorkommen können (z.B. verschiedene Linien, Richtungen). Die Suche zeigt alle Treffer an, und die Routenberechnung nutzt die ausgewählten OSM-IDs.

## GraphHopper Profile

Die App verwendet standardmäßig das `foot`-Profil. Du kannst dies im Backend ändern:

**Verfügbare Profile:**
- `foot` - Fußgänger
- `car` - Auto
- `bike` - Fahrrad
- `hike` - Wandern

**Ändern in `.env`:**
```env
GRAPHHOPPER_PROFILE=bike
```

## Fehlerbehandlung

### GraphHopper nicht erreichbar

Falls GraphHopper nicht läuft, fällt die App automatisch auf eine direkte Verbindung zurück:

```json
{
  "route": {
    "properties": {
      "type": "direct_connection",
      "source": "fallback",
      "error": "GraphHopper not available"
    }
  }
}
```

### Keine Route gefunden

- Überprüfe, ob GraphHopper die OSM-Daten geladen hat
- Stelle sicher, dass die Haltestellen im GraphHopper-Bereich liegen
- Prüfe Backend-Logs für Details

## Debugging

### Backend-Logs anschauen

```bash
cd backend
npm start
```

**Wichtige Log-Nachrichten:**
- `Calculating route from X to Y using GraphHopper`
- `Calling GraphHopper API: ...`
- `GraphHopper route calculated: Xkm, Ymin`
- `GraphHopper API error: ...` (falls Fehler)
- `Falling back to direct connection`

### GraphHopper-Logs

GraphHopper läuft in der Console, wo es gestartet wurde. Überprüfe auf Fehler.

### Frontend-Logs

Flutter Console zeigt:
- `Requesting route from X to Y via GraphHopper`
- `GraphHopper route received: Xkm`
- `Route calculated: X, Y`

## Entwicklung

### Neue GraphHopper-Features hinzufügen

1. **Backend:** Passe `server.js` → `/api/routes/calculate` an
2. **Frontend Models:** Erweitere `route_models.dart`
3. **Frontend Service:** Aktualisiere `graphhopper_service.dart`
4. **UI:** Passe `route_details_sheet.dart` oder `main.dart` an

### Tests

**Backend testen:**
```bash
curl "http://localhost:3000/api/routes/calculate?from=123&to=456"
```

**GraphHopper direkt testen:**
```bash
curl "http://localhost:8989/route?point=52.5200,13.4050&point=52.5300,13.4150&profile=foot"
```

## Nächste Schritte

- [ ] Multimodale Routen (ÖPNV + Fußweg)
- [ ] Alternative Routen anzeigen
- [ ] Höhenprofil für Fahrrad-Routen
- [ ] Echtzeit-Navigation
- [ ] Offline-Routing

## Troubleshooting

**Problem:** GraphHopper antwortet nicht
- **Lösung:** Prüfe, ob GraphHopper läuft auf Port 8989
- **Test:** `curl http://localhost:8989/health`

**Problem:** Backend findet Haltestellen nicht
- **Lösung:** Prüfe PostgreSQL-Verbindung und OSM-Daten

**Problem:** Route wird nicht angezeigt
- **Lösung:** Prüfe Browser-Console/Flutter-Logs für Fehler

**Problem:** "No route found by GraphHopper"
- **Lösung:** Haltestellen liegen außerhalb des GraphHopper-Bereichs
- **Tipp:** Lade größere OSM-Datei oder prüfe Koordinaten

## Support

Bei Fragen oder Problemen, überprüfe:
1. Backend-Logs (`npm start`)
2. GraphHopper-Logs
3. Flutter-Console
4. Browser DevTools (Network-Tab)
