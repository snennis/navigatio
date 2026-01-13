# Navigatio Backend 🖥️

> Node.js Express API für ÖPNV-Daten mit PostgreSQL/PostGIS und GraphHopper-Routing

## 🎯 Übersicht

Das **Navigatio Backend** stellt eine hochperformante REST-API bereit, die OpenStreetMap-Daten aus einer PostgreSQL/PostGIS-Datenbank abfragt und mit GraphHopper für Routing-Funktionalität kombiniert.

## ✨ Features

### 🗄️ **Datenbank-Integration**
- **PostgreSQL + PostGIS** - Räumliche Datenbankabfragen
- **osm2pgsql Schema** - Standard OpenStreetMap-Datenformat  
- **Smart Caching** - 5-Minuten TTL In-Memory-Cache
- **Bounding Box Queries** - Geografisch optimierte Abfragen

### 🛤️ **GraphHopper-Integration**
- **Lokale Routing-Engine** - Schnelle Berechnungen
- **Multi-Modal** - Fußweg + ÖPNV kombiniert
- **Turn-by-Turn** - Detaillierte Wegbeschreibungen
- **Profile Support** - Verschiedene Verkehrsmittel

### 🚀 **Performance**
- **In-Memory Cache** - Redis-ähnliche Performance ohne Redis
- **Debounced Queries** - Vermeidung redundanter DB-Abfragen  
- **Optimized SQL** - PostGIS-optimierte Spatial Queries
- **Async Processing** - Non-blocking API-Calls

## 🛠️ Setup & Installation

### **1. Dependencies installieren**
```bash
cd backend
npm install
```

### **2. Umgebungsvariablen konfigurieren**

**Erstelle `.env` Datei:**
```bash
cp .env.example .env
```

**Konfiguriere `.env`:**
```env
# PostgreSQL Datenbank (OSM Data)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=osm2pgsql
DB_USER=your_username
DB_PASSWORD=your_password

# Server Konfiguration
PORT=3000
NODE_ENV=development

# GraphHopper API
GRAPHHOPPER_URL=http://localhost:8989
GRAPHHOPPER_PROFILE=foot
USE_PUBLIC_TRANSPORT=true

# Cache Konfiguration
CACHE_TTL=300  # 5 Minuten
```

### **3. Datenbank vorbereiten**

**PostgreSQL-Berechtigungen setzen:**
```sql
-- Als PostgreSQL Superuser
GRANT SELECT ON ALL TABLES IN SCHEMA public TO your_username;
GRANT USAGE ON SCHEMA public TO your_username;

-- Tabellen prüfen
SELECT count(*) FROM planet_osm_line WHERE route IS NOT NULL;
SELECT count(*) FROM planet_osm_point WHERE public_transport IS NOT NULL;
```

**PostGIS-Extension (falls nicht vorhanden):**
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

### **4. GraphHopper Setup**

Siehe [GRAPHHOPPER_INTEGRATION.md](../GRAPHHOPPER_INTEGRATION.md) für Details.

**Quick Start:**
```bash
# GraphHopper für Berlin herunterladen und starten
wget https://repo1.maven.org/maven2/com/graphhopper/graphhopper-web/8.0/graphhopper-web-8.0.jar
wget https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf

java -Ddw.graphhopper.datareader.file=berlin-latest.osm.pbf \
     -Ddw.graphhopper.graph.location=berlin-graph \
     -jar graphhopper-web-8.0.jar server config.yml
```

### **5. Server starten**
```bash
# Produktion
npm start

# Development mit Auto-Reload
npm run dev

# Mit Debug-Logs
DEBUG=navigatio:* npm start
```

## 📡 API Documentation

### **🚊 ÖPNV Routes**
```http
GET /api/routes?west=13.2&south=52.4&east=13.5&north=52.6
```

**Response:**
```json
{
  "routes": [
    {
      "id": 123456,
      "name": "U7", 
      "route": "subway",
      "colour": "#3366CC",
      "network": "VBB",
      "geometry": "LINESTRING(13.4132 52.5219, ...)"
    }
  ],
  "cache_info": {
    "hit": false,
    "key": "routes_132_524_135_526", 
    "ttl": 300,
    "created_at": "2026-01-13T10:30:00Z"
  },
  "query_time_ms": 142
}
```

### **🚏 Station Search**
```http
GET /api/stations/search?q=alexander&limit=10
```

**Response:**
```json
{
  "stations": [
    {
      "id": 789012,
      "name": "Alexanderplatz",
      "lat": 52.5219,
      "lon": 13.4132,
      "transport_types": ["subway", "bus", "tram"],
      "lines": ["U2", "U5", "U8", "M1", "M4", "100"]
    }
  ]
}
```

### **🛤️ GraphHopper Routing**
```http
POST /api/route
Content-Type: application/json

{
  "from": {"lat": 52.5219, "lon": 13.4132},
  "to": {"lat": 52.4963, "lon": 13.4445},
  "profile": "foot",
  "include_elevation": false
}
```

**Response:**
```json
{
  "route": {
    "distance": 2134,      // Meter
    "time": 1560,          // Sekunden  
    "ascent": 12.5,        // Höhenmeter
    "descent": 8.3,
    "geometry": "LINESTRING(...)",
    "instructions": [
      {
        "distance": 156,
        "heading": 2.1,
        "sign": 0,
        "text": "Geradeaus auf Alexanderstraße"
      }
    ]
  },
  "graphhopper_time_ms": 89
}
```

### **⚙️ System & Cache Endpoints**
```http
GET /health                 # Server Health Check
GET /cache/stats           # Cache-Statistiken
DELETE /cache              # Cache komplett leeren  
DELETE /cache/:key         # Spezifischen Cache-Key löschen
```

**Health Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-13T10:30:15.123Z",
  "uptime": 3661,
  "database": "connected",
  "graphhopper": "reachable",
  "cache": {
    "size": 42,
    "hit_rate": 0.867,
    "memory_usage": "15.2 MB"
  }
}
```

## 🔧 Technische Details

### **📦 Core Dependencies**

| Package | Version | Zweck |
|---------|---------|-------|
| `express` | ^4.18.2 | Web-Framework & Routing |
| `pg` | ^8.11.3 | PostgreSQL Client |
| `cors` | ^2.8.5 | Cross-Origin Resource Sharing |
| `axios` | ^1.13.2 | HTTP Client (GraphHopper API) |
| `dotenv` | ^16.3.1 | Environment Variable Management |

### **🗄️ Datenbank-Schema**

**ÖPNV-Routen (planet_osm_line):**
```sql
SELECT 
    osm_id,
    name,
    route,           -- 'subway', 'bus', 'tram', etc.
    railway,         -- 'subway', 'rail', 'tram'
    colour,          -- Hex-Farbcode der Linie
    network,         -- 'VBB' für Berlin
    ST_AsGeoJSON(way) as geometry
FROM planet_osm_line 
WHERE route IN ('subway', 'bus', 'tram', 'light_rail', 'ferry')
   OR railway IN ('subway', 'rail', 'tram', 'light_rail')
   AND way && ST_SetSRID(ST_MakeBox2D(
       ST_Point($1, $2), ST_Point($3, $4)
   ), 4326);
```

**ÖPNV-Haltestellen (planet_osm_point):**
```sql
SELECT 
    osm_id,
    name,
    public_transport,  -- 'stop_position', 'platform', 'station'
    highway,          -- 'bus_stop'
    railway,          -- 'station', 'halt', 'tram_stop'
    ST_Y(way) as lat,
    ST_X(way) as lon
FROM planet_osm_point
WHERE (
    public_transport IN ('stop_position', 'platform', 'station')
    OR highway = 'bus_stop'
    OR railway IN ('station', 'halt', 'tram_stop', 'subway_entrance')
) AND way && ST_SetSRID(ST_MakeBox2D(
    ST_Point($1, $2), ST_Point($3, $4)  
), 4326);
```

### **⚡ Cache-Implementation**

**In-Memory Cache mit TTL:**
```javascript
class CacheManager {
  constructor(ttl = 300000) { // 5 Minuten
    this.cache = new Map();
    this.ttl = ttl;
    this.stats = { hits: 0, misses: 0, sets: 0 };
  }
  
  get(key) {
    const entry = this.cache.get(key);
    if (!entry || Date.now() > entry.expires) {
      this.stats.misses++;
      this.cache.delete(key);
      return null;
    }
    this.stats.hits++;
    return entry.value;
  }
  
  set(key, value) {
    this.cache.set(key, {
      value,
      expires: Date.now() + this.ttl,
      created: Date.now()
    });
    this.stats.sets++;
  }
}
```

**Smart Cache Keys:**
```javascript
// Gerundete Koordinaten für bessere Cache-Hits
function generateCacheKey(west, south, east, north) {
  return `routes_${Math.round(west*10)}_${Math.round(south*10)}_${Math.round(east*10)}_${Math.round(north*10)}`;
}
```

### **🔍 SQL-Optimierungen**

**Spatial Index nutzen:**
```sql
-- Stelle sicher, dass Spatial Index vorhanden ist
CREATE INDEX IF NOT EXISTS planet_osm_line_way_idx 
    ON planet_osm_line USING GIST (way);

CREATE INDEX IF NOT EXISTS planet_osm_point_way_idx  
    ON planet_osm_point USING GIST (way);

-- Attribute-Indizes für häufige Queries
CREATE INDEX IF NOT EXISTS planet_osm_line_route_idx
    ON planet_osm_line (route) WHERE route IS NOT NULL;
```

## 🚀 Performance-Monitoring

### **📊 Built-in Monitoring**

**Cache-Statistiken:**
```bash
curl http://localhost:3000/cache/stats
```

**Response:**
```json
{
  "cache": {
    "size": 156,
    "hits": 1042,
    "misses": 287,
    "hit_rate": 0.784,
    "sets": 298,
    "memory_usage": "18.7 MB",
    "oldest_entry": "2026-01-13T10:25:14.123Z",
    "cleanup_count": 23
  }
}
```

**Database Performance:**
```bash
# Aktive Verbindungen  
psql -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# Slow Queries
psql -c "SELECT query, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 5;"
```

### **🔧 Performance-Tuning**

**PostgreSQL Optimierungen (postgresql.conf):**
```ini
# Memory
shared_buffers = 256MB
work_mem = 4MB
maintenance_work_mem = 64MB

# Connection Pool
max_connections = 100
shared_preload_libraries = 'pg_stat_statements'

# PostGIS Performance
random_page_cost = 1.1
effective_cache_size = 1GB
```

**Node.js Optimierungen:**
```javascript
// Connection Pool für PostgreSQL
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST, 
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
  max: 20,                    // Maximale Connections
  idleTimeoutMillis: 30000,   // Idle Connection Timeout
  connectionTimeoutMillis: 2000, // Connection Timeout
});
```

## 🐛 Troubleshooting

### **❌ Häufige Probleme**

| Problem | Symptom | Lösung |
|---------|---------|--------|
| 🔴 **DB Connection Failed** | `error: role "user" does not exist` | PostgreSQL User in `.env` prüfen |
| 🔴 **Permission Denied** | `permission denied for table planet_osm_line` | `GRANT SELECT` Rechte setzen |
| 🔴 **GraphHopper Unreachable** | `ECONNREFUSED localhost:8989` | GraphHopper Service status prüfen |
| 🔴 **No Routes Found** | `routes: []` trotz Daten | WHERE-Clause und OSM Tags prüfen |
| 🔴 **High Memory Usage** | Cache wächst unbegrenzt | TTL und Cleanup-Mechanismus prüfen |

### **🔍 Debug-Befehle**

**Server-Logs mit Details:**
```bash
# Development Mode
DEBUG=navigatio:* npm run dev

# Nur DB-Queries  
DEBUG=navigatio:db npm start

# Nur Cache-Operations
DEBUG=navigatio:cache npm start
```

**Datenbank-Tests:**
```bash
# Verbindung testen
psql -U $DB_USER -d $DB_NAME -c "SELECT version();"

# ÖPNV-Daten prüfen
psql -U $DB_USER -d $DB_NAME -c "
  SELECT route, count(*) 
  FROM planet_osm_line 
  WHERE route IN ('subway', 'bus', 'tram') 
  GROUP BY route;
"

# Spatial Index Status
psql -U $DB_USER -d $DB_NAME -c "
  SELECT schemaname, tablename, indexname  
  FROM pg_indexes 
  WHERE tablename LIKE 'planet_osm_%' 
  AND indexname LIKE '%way%';
"
```

**API-Tests:**
```bash
# Health Check
curl -s http://localhost:3000/health | jq

# Routes Test
curl -s "http://localhost:3000/api/routes?west=13.3&south=52.4&east=13.5&north=52.6" | jq '.routes | length'

# Cache Performance
curl -s http://localhost:3000/cache/stats | jq '.cache.hit_rate'
```

### **📈 Monitoring Setup**

**PM2 für Production:**
```bash
npm install -g pm2

# App starten
pm2 start server.js --name navigatio-backend

# Monitoring
pm2 monit

# Logs
pm2 logs navigatio-backend
```

**Log-Rotation:**
```javascript
// logger.js
const winston = require('winston');

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error',
      maxsize: 10485760, // 10MB
      maxFiles: 5
    }),
    new winston.transports.File({ 
      filename: 'logs/combined.log',
      maxsize: 10485760,
      maxFiles: 10 
    })
  ],
});
```

## 🧪 Testing

### **Unit Tests:**
```bash
npm test
```

**API Integration Tests:**
```javascript
// tests/api.test.js
const request = require('supertest');
const app = require('../server');

describe('ÖPNV API', () => {
  test('GET /api/routes returns valid data', async () => {
    const response = await request(app)
      .get('/api/routes?west=13.3&south=52.4&east=13.5&north=52.6')
      .expect(200);
      
    expect(response.body).toHaveProperty('routes');
    expect(Array.isArray(response.body.routes)).toBe(true);
  });
});
```

### **Load Testing:**
```bash
# Apache Bench
ab -n 1000 -c 10 "http://localhost:3000/api/routes?west=13.3&south=52.4&east=13.5&north=52.6"

# wrk Load Test  
wrk -t12 -c400 -d30s "http://localhost:3000/api/routes?west=13.3&south=52.4&east=13.5&north=52.6"
```

---

🖥️ **Navigatio Backend** - Hochperformante API für ÖPNV-Navigation

[🔙 Zurück zur Haupt-README](../README.md) • [📊 API Docs](API.md) • [🛤️ GraphHopper Setup](../GRAPHHOPPER_INTEGRATION.md)