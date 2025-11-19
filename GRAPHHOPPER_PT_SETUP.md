# GraphHopper Public Transport Setup

## Problem gelöst
Der 400-Fehler kam daher, dass wir den falschen GraphHopper-Endpunkt verwendet haben. Für ÖPNV-Routing muss der `/route-pt` Endpunkt anstatt `/route` verwendet werden.

## Was wurde geändert

### Backend (`server.js`)

1. **Neue Konfiguration**:
   ```javascript
   const USE_PUBLIC_TRANSPORT = process.env.USE_PUBLIC_TRANSPORT === 'true' || true;
   ```
   - Standardmäßig aktiviert
   - Kann über `.env` deaktiviert werden

2. **Routing-Logik**:
   - **PT-Modus**: Verwendet `/route-pt` mit `pt.earliest_departure_time`
   - **Regular-Modus**: Verwendet `/route` mit `profile` (foot/bike/car)

3. **Response-Verarbeitung**:
   - PT-Antworten haben `legs` (verschiedene Abschnitte: Laufen, U-Bahn, Bus etc.)
   - Alle Leg-Geometrien werden kombiniert
   - Transfers werden gezählt

### Frontend

#### Models (`route_models.dart`)

- **`RouteLeg`** - Neue Klasse für PT-Abschnitte:
  - `type`: 'pt', 'walk', 'bike'
  - `routeId`: z.B. 'U7', 'S1'
  - `headsign`: Fahrtrichtung
  - `departureLocation` / `arrivalLocation`
  - `distance` / `duration`

- **`RouteProperties`** - Erweitert:
  - `transfers`: Anzahl Umstiege
  - `legs`: Liste der Route-Abschnitte
  - `isPublicTransport()`: Prüfung ob ÖPNV

#### UI (`route_details_sheet.dart`)

- **Neue Legs-Anzeige**:
  - Zeigt jeden Abschnitt einzeln
  - Farben je nach Transport-Typ (Grün=ÖPNV, Orange=Fuß, Lila=Fahrrad)
  - Icons für jeden Leg-Typ
  - Linie/Richtung (z.B. "U7 → Rudow")

- **Transfers-Anzeige**:
  - Zeigt Anzahl der Umstiege in Summary Card
  - Icon mit Anzahl

## GraphHopper PT einrichten

### Voraussetzungen

GraphHopper benötigt GTFS-Daten für Public Transport Routing:

1. **GTFS-Daten herunterladen** (z.B. für Berlin):
   ```bash
   wget https://www.vbb.de/fileadmin/user_upload/VBB/Dokumente/API-Datensaetze/gtfs-mastscharf/GTFS.zip
   unzip GTFS.zip -d gtfs/
   ```

2. **config.yml erstellen** (neben der GraphHopper JAR):
   ```yaml
   graphhopper:
     datareader.file: berlin-latest.osm.pbf
     graph.location: ./graph-cache
     
     # Enable Public Transport
     gtfs.file: ./gtfs/GTFS.zip
     
     profiles:
       - name: foot
       - name: pt
         vehicle: pt
         weighting: fastest
   ```

3. **GraphHopper mit PT starten**:
   ```bash
   java -Xmx4g -Xms1g \
        -Ddw.graphhopper.datareader.file=berlin-latest.osm.pbf \
        -Ddw.graphhopper.graph.location=./graph-cache \
        -Ddw.graphhopper.gtfs.file=./gtfs \
        -jar graphhopper-web-8.0.jar server config.yml
   ```

### Test

```bash
# Test PT Routing
curl "http://localhost:8989/route-pt?point=52.53661,13.13711&point=52.53633,13.19940&pt.earliest_departure_time=2025-11-18T08:00:00%2B01:00"
```

**Erwartete Response**:
```json
{
  "paths": [{
    "distance": 5000,
    "time": 1200000,
    "transfers": 1,
    "legs": [
      {
        "type": "walk",
        "distance": 200,
        "duration": 150000,
        "geometry": {...}
      },
      {
        "type": "pt",
        "route_id": "U7",
        "trip_headsign": "Rudow",
        "departure_location": "Leopoldplatz",
        "arrival_location": "Westhafen",
        "geometry": {...}
      }
    ]
  }]
}
```

## Verwendung in der App

### Standardmäßig

- App nutzt automatisch ÖPNV-Routing
- Zeigt Verbindungen mit Umstiegen
- Visualisiert jeden Abschnitt (Fuß/ÖPNV)

### Zwischen Modi wechseln

**Option 1: Environment Variable** (`.env`):
```env
USE_PUBLIC_TRANSPORT=true   # ÖPNV-Routing (Standard)
USE_PUBLIC_TRANSPORT=false  # Fußweg-Routing
```

**Option 2: Code** (`server.js`):
```javascript
const USE_PUBLIC_TRANSPORT = true;  // oder false
```

## Troubleshooting

### "400 Bad Request"
**Problem**: GraphHopper lehnt die Anfrage ab

**Lösung 1**: GTFS-Daten fehlen
```bash
# Prüfe ob GTFS-Daten geladen wurden
ls graph-cache/pt_*
```

Sollte PT-Files zeigen. Falls nicht, GTFS-Daten neu laden.

**Lösung 2**: Falsches Zeitformat
```javascript
// Backend sendet automatisch ISO 8601:
pt.earliest_departure_time: "2025-11-18T08:00:00+01:00"
```

### "No route found"
**Problem**: GraphHopper findet keine ÖPNV-Verbindung

**Mögliche Ursachen**:
1. Haltestellen außerhalb des GTFS-Bereichs
2. Keine Verbindung zur angegebenen Zeit (zu spät/früh)
3. GTFS-Daten veraltet

**Test**:
```bash
# Prüfe, ob PT-Daten vorhanden
java -jar graphhopper-web-8.0.jar import berlin-latest.osm.pbf gtfs/
```

### Fallback funktioniert

Wenn GraphHopper nicht verfügbar ist, zeigt die App automatisch eine direkte Luftlinie:

```javascript
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

## Konfiguration optimieren

### Performance

```yaml
# config.yml
graphhopper:
  gtfs:
    max_transfer_seconds: 1800  # Max 30min Umstiegezeit
    max_visit_limit: 100000     # Suchraum begrenzen
```

### Zeitfenster

```javascript
// Backend - automatische Zeit
const now = new Date();
const departureTime = now.toISOString();

// Oder feste Zeit
const departureTime = "2025-11-18T08:00:00+01:00";
```

### Profile-Mix

Du kannst auch beide Modi parallel anbieten:

```javascript
// Endpoint mit Parameter
app.get('/api/routes/calculate', async (req, res) => {
  const usePT = req.query.mode === 'pt';
  // ...
});
```

Frontend:
```dart
// Mit PT
await StationService.calculateRoute(fromId, toId, mode: 'pt');

// Ohne PT (nur Fuß)
await StationService.calculateRoute(fromId, toId, mode: 'foot');
```

## Nächste Schritte

- [ ] Zeitauswahl im Frontend (Abfahrtszeit)
- [ ] Alternative Routen anzeigen (paths[1], paths[2])
- [ ] Echtzeit-Daten (Verspätungen)
- [ ] Detaillierte Stop-Informationen
- [ ] Fahrplan-Ansicht
