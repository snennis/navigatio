const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// PostgreSQL Connection
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// Initialize database extensions
async function initializeDatabase() {
  try {
    // Enable trigram extension for fuzzy search
    await pool.query('CREATE EXTENSION IF NOT EXISTS pg_trgm;');
    console.log('Database extensions initialized');
  } catch (error) {
    console.warn('Could not initialize database extensions:', error.message);
  }
}

initializeDatabase();

// Cache System
const cache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 Minuten in Millisekunden

// Cache Helper Functions
function getCacheKey(west, south, east, north, type) {
  // Runde Koordinaten auf 2 Dezimalstellen für bessere Cache-Hits
  const roundedWest = Math.round(west * 100) / 100;
  const roundedSouth = Math.round(south * 100) / 100;
  const roundedEast = Math.round(east * 100) / 100;
  const roundedNorth = Math.round(north * 100) / 100;
  return `${type}:${roundedWest},${roundedSouth},${roundedEast},${roundedNorth}`;
}

function getCachedData(key) {
  const cached = cache.get(key);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    console.log(`🎯 Cache hit for ${key}`);
    return cached.data;
  }
  if (cached) {
    cache.delete(key); // Remove expired cache
    console.log(`⏰ Cache expired for ${key}`);
  }
  return null;
}

function setCachedData(key, data) {
  cache.set(key, {
    data: data,
    timestamp: Date.now()
  });
  console.log(`💾 Cached data for ${key} (cache size: ${cache.size})`);
}

// Middleware
app.use(cors());
app.use(express.json());

// Test connection
pool.connect((err, client, release) => {
  if (err) {
    console.error('Error connecting to PostgreSQL:', err.stack);
  } else {
    console.log('✅ Connected to PostgreSQL database');
    release();
  }
});

// API Routes

// Get ÖPNV stops/stations (points)
app.get('/api/stops', async (req, res) => {
  try {
    const { west, south, east, north, bbox } = req.query;
    
    // Check cache first
    let w, s, e, n;
    if (west && south && east && north) {
      w = parseFloat(west);
      s = parseFloat(south);
      e = parseFloat(east);
      n = parseFloat(north);
    } else if (bbox) {
      const [bboxWest, bboxSouth, bboxEast, bboxNorth] = bbox.split(',').map(Number);
      w = bboxWest;
      s = bboxSouth;
      e = bboxEast;
      n = bboxNorth;
    }
    
    if (w && s && e && n) {
      const cacheKey = getCacheKey(w, s, e, n, 'stops');
      const cachedData = getCachedData(cacheKey);
      if (cachedData) {
        return res.json(cachedData);
      }
    }
    
    let query = `
      SELECT 
        osm_id,
        name,
        public_transport,
        railway,
        highway,
        ST_X(ST_Transform(way, 4326)) as longitude,
        ST_Y(ST_Transform(way, 4326)) as latitude
      FROM planet_osm_point 
      WHERE (
        public_transport IS NOT NULL 
        OR railway IN ('station', 'halt', 'tram_stop')
        OR highway = 'bus_stop'
      )
    `;
    
    const values = [];
    
    // Add bounding box filter if provided
    if (west && south && east && north) {
      query += ` AND ST_Transform(way, 4326) && ST_MakeEnvelope($1, $2, $3, $4, 4326)`;
      values.push(parseFloat(west), parseFloat(south), parseFloat(east), parseFloat(north));
    } else if (bbox) {
      const [bboxWest, bboxSouth, bboxEast, bboxNorth] = bbox.split(',').map(Number);
      query += ` AND ST_Transform(way, 4326) && ST_MakeEnvelope($1, $2, $3, $4, 4326)`;
      values.push(bboxWest, bboxSouth, bboxEast, bboxNorth);
    }
    
    // Remove LIMIT to get all stops in the bounding box
    
    const result = await pool.query(query, values);
    
    const stops = result.rows.map(row => ({
      id: row.osm_id,
      name: row.name || 'Unnamed Stop',
      type: row.public_transport || row.railway || row.highway,
      coordinates: [row.longitude, row.latitude]
    }));
    
    const response = {
      type: 'FeatureCollection',
      features: stops.map(stop => ({
        type: 'Feature',
        id: stop.id,
        properties: {
          name: stop.name,
          type: stop.type
        },
        geometry: {
          type: 'Point',
          coordinates: stop.coordinates
        }
      }))
    };
    
    // Cache the result
    if (w && s && e && n) {
      const cacheKey = getCacheKey(w, s, e, n, 'stops');
      setCachedData(cacheKey, response);
    }
    
    res.json(response);
    
  } catch (error) {
    console.error('❌ Error fetching stops:', error.message);
    console.error('Full error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Get ÖPNV routes/ways (lines)
app.get('/api/routes', async (req, res) => {
  try {
    const { west, south, east, north, bbox } = req.query;
    
    // Check cache first
    let w, s, e, n;
    if (west && south && east && north) {
      w = parseFloat(west);
      s = parseFloat(south);
      e = parseFloat(east);
      n = parseFloat(north);
    } else if (bbox) {
      const [bboxWest, bboxSouth, bboxEast, bboxNorth] = bbox.split(',').map(Number);
      w = bboxWest;
      s = bboxSouth;
      e = bboxEast;
      n = bboxNorth;
    }
    
    if (w && s && e && n) {
      const cacheKey = getCacheKey(w, s, e, n, 'routes');
      const cachedData = getCachedData(cacheKey);
      if (cachedData) {
        return res.json(cachedData);
      }
    }
    
    let query = `
      SELECT 
        osm_id,
        name,
        route,
        public_transport,
        railway,
        highway,
        ST_AsGeoJSON(ST_Transform(way, 4326)) as geometry
      FROM planet_osm_line 
      WHERE (
        route = 'subway'
        OR railway = 'subway'
      )
    `;
    
    const values = [];
    
    if (west && south && east && north) {
      query += ` AND ST_Transform(way, 4326) && ST_MakeEnvelope($1, $2, $3, $4, 4326)`;
      values.push(parseFloat(west), parseFloat(south), parseFloat(east), parseFloat(north));
    } else if (bbox) {
      const [bboxWest, bboxSouth, bboxEast, bboxNorth] = bbox.split(',').map(Number);
      query += ` AND ST_Transform(way, 4326) && ST_MakeEnvelope($1, $2, $3, $4, 4326)`;
      values.push(bboxWest, bboxSouth, bboxEast, bboxNorth);
    }
    
    query += ` LIMIT 1000`; // Increased limit for routes
    
    const result = await pool.query(query, values);
    
    const response = {
      type: 'FeatureCollection',
      features: result.rows.map(row => ({
        type: 'Feature',
        id: row.osm_id,
        properties: {
          name: row.name || 'Unnamed Route',
          route: row.route,
          type: row.public_transport || row.railway || row.highway
        },
        geometry: JSON.parse(row.geometry)
      }))
    };
    
    // Cache the result
    if (w && s && e && n) {
      const cacheKey = getCacheKey(w, s, e, n, 'routes');
      setCachedData(cacheKey, response);
    }
    
    res.json(response);
    
  } catch (error) {
    console.error('❌ Error fetching routes:', error.message);
    console.error('Full error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// API Endpoint für Haltestellensuche (Fuzzy Search)
app.get('/api/stations/search', async (req, res) => {
  try {
    console.log('Searching stations with query:', req.query.q);
    
    const searchQuery = req.query.q;
    if (!searchQuery || searchQuery.length < 2) {
      return res.json([]);
    }
    
    // PostgreSQL Fuzzy Search mit trigram similarity
    const query = `
      SELECT 
        osm_id,
        name,
        public_transport,
        railway,
        highway,
        ST_X(ST_Transform(way, 4326)) as longitude,
        ST_Y(ST_Transform(way, 4326)) as latitude,
        similarity(name, $1) as similarity_score
      FROM planet_osm_point 
      WHERE name IS NOT NULL
        AND name != ''
        AND (
          public_transport IN ('stop_position', 'platform', 'station')
          OR railway IN ('station', 'halt', 'tram_stop', 'subway_entrance')
          OR highway = 'bus_stop'
        )
        AND (
          name ILIKE $2
          OR similarity(name, $1) > 0.3
        )
      ORDER BY 
        similarity_score DESC,
        name ASC
      LIMIT 20
    `;
    
    const searchPattern = `%${searchQuery}%`;
    const result = await pool.query(query, [searchQuery, searchPattern]);
    
    const stations = result.rows.map(row => ({
      id: row.osm_id,
      name: row.name,
      type: row.public_transport || row.railway || row.highway,
      coordinates: {
        lat: parseFloat(row.latitude),
        lng: parseFloat(row.longitude)
      },
      similarity: parseFloat(row.similarity_score)
    }));
    
    console.log(`Found ${stations.length} stations for query "${searchQuery}"`);
    res.json(stations);
    
  } catch (error) {
    console.error('Error searching stations:', error);
    res.status(500).json({ 
      error: 'Failed to search stations',
      details: error.message 
    });
  }
});

// API Endpoint für Routenberechnung zwischen zwei Haltestellen
app.get('/api/routes/calculate', async (req, res) => {
  try {
    const { from, to } = req.query;
    
    if (!from || !to) {
      return res.status(400).json({ 
        error: 'Both from and to station IDs are required' 
      });
    }

    console.log(`Calculating route from ${from} to ${to}`);

    // 1. Get station coordinates
    const stationQuery = `
      SELECT 
        osm_id,
        name,
        ST_X(ST_Transform(way, 4326)) as longitude,
        ST_Y(ST_Transform(way, 4326)) as latitude
      FROM planet_osm_point 
      WHERE osm_id IN ($1, $2)
    `;
    
    const stationResult = await pool.query(stationQuery, [from, to]);
    
    if (stationResult.rows.length !== 2) {
      return res.status(404).json({ 
        error: 'One or both stations not found' 
      });
    }

    const fromStation = stationResult.rows.find(row => row.osm_id === from);
    const toStation = stationResult.rows.find(row => row.osm_id === to);

    // 2. Simple straight line connection for now (can be enhanced with actual routing)
    const routeGeometry = {
      type: "LineString",
      coordinates: [
        [fromStation.longitude, fromStation.latitude],
        [toStation.longitude, toStation.latitude]
      ]
    };

    // 3. Find nearby routes/lines for better visualization
    const nearbyRoutesQuery = `
      SELECT DISTINCT
        osm_id,
        name,
        route,
        ST_AsGeoJSON(ST_Transform(way, 4326)) as geometry
      FROM planet_osm_line 
      WHERE (
        route = 'subway'
        OR railway = 'subway'
      )
      AND (
        ST_DWithin(
          ST_Transform(way, 4326)::geography,
          ST_MakePoint($1, $2)::geography,
          1000
        )
        OR ST_DWithin(
          ST_Transform(way, 4326)::geography,
          ST_MakePoint($3, $4)::geography,
          1000
        )
      )
      LIMIT 50
    `;

    const nearbyRoutes = await pool.query(nearbyRoutesQuery, [
      fromStation.longitude, fromStation.latitude,
      toStation.longitude, toStation.latitude
    ]);

    const response = {
      route: {
        type: 'Feature',
        properties: {
          from: {
            id: fromStation.osm_id,
            name: fromStation.name,
            coordinates: [fromStation.longitude, fromStation.latitude]
          },
          to: {
            id: toStation.osm_id,
            name: toStation.name,
            coordinates: [toStation.longitude, toStation.latitude]
          },
          distance: calculateDistance(
            fromStation.latitude, fromStation.longitude,
            toStation.latitude, toStation.longitude
          ),
          type: 'direct_connection'
        },
        geometry: routeGeometry
      },
      nearbyRoutes: nearbyRoutes.rows.map(row => ({
        type: 'Feature',
        id: row.osm_id,
        properties: {
          name: row.name || 'Unnamed Route',
          route: row.route,
          type: 'subway'
        },
        geometry: JSON.parse(row.geometry)
      }))
    };

    console.log(`Route calculated: ${response.route.properties.distance.toFixed(2)}km`);
    res.json(response);

  } catch (error) {
    console.error('Error calculating route:', error);
    res.status(500).json({ 
      error: 'Failed to calculate route',
      details: error.message 
    });
  }
});

// Helper function to calculate distance between two points
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// Health Check
app.get('/health', async (req, res) => {
  res.json({ status: 'OK', message: 'ÖPNV API is running' });
});

// Cache statistics
app.get('/cache/stats', (req, res) => {
  const stats = {
    size: cache.size,
    keys: Array.from(cache.keys()),
    ttl_minutes: CACHE_TTL / 60 / 1000
  };
  res.json(stats);
});

// Clear cache
app.delete('/cache', (req, res) => {
  const oldSize = cache.size;
  cache.clear();
  res.json({ 
    message: `Cache cleared. Removed ${oldSize} entries.`,
    old_size: oldSize,
    new_size: cache.size 
  });
});

app.listen(port, () => {
  console.log(`🚀 ÖPNV API Server running on http://localhost:${port}`);
  console.log(`📊 Health check: http://localhost:${port}/health`);
  console.log(`🚏 Stops API: http://localhost:${port}/api/stops`);
  console.log(`🚌 Routes API: http://localhost:${port}/api/routes`);
});