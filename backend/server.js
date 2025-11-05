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

// Health check
app.get('/health', (req, res) => {
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