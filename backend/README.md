# ÖPNV Navigation Backend

## Setup

1. **Dependencies installieren:**
```bash
cd backend
npm install
```

2. **Umgebungsvariablen konfigurieren:**
Erstelle eine `.env` Datei im backend Ordner:

```env
# PostgreSQL Datenbank Konfiguration  
DB_HOST=localhost
DB_PORT=5432
DB_NAME=osm2pgsql
DB_USER=your_username
DB_PASSWORD=your_password

# Server Konfiguration
PORT=3000
NODE_ENV=development
```

3. **Datenbank vorbereiten:**
Stelle sicher, dass deine PostgreSQL Datenbank mit OSM-Daten bereit ist:
- Tabelle: `planet_osm_point` (für ÖPNV-Haltestellen)
- Tabelle: `planet_osm_line` (für ÖPNV-Routen)
- PostGIS Extension aktiviert

4. **Server starten:**
```bash
npm start
```

## API Endpoints

- `GET /api/stops` - ÖPNV Haltestellen mit Bounding Box Filter
- `GET /api/routes` - ÖPNV Routen mit Bounding Box Filter

### Parameter:
- `west`, `south`, `east`, `north` - Bounding Box Koordinaten

### Beispiel:
```
http://localhost:3000/api/stops?west=13.2&south=52.4&east=13.5&north=52.6
```

## Unterstützte ÖPNV Tags

**Haltestellen (planet_osm_point):**
- `public_transport = stop_position`
- `highway = bus_stop`
- `railway = tram_stop`
- `railway = station`

**Routen (planet_osm_line):**
- `route = bus`
- `route = tram`
- `route = subway`
- `railway = tram`
- `railway = subway`