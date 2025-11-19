const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// GraphHopper Configuration
const GRAPHHOPPER_URL = process.env.GRAPHHOPPER_URL || 'http://localhost:8989';
const GRAPHHOPPER_PROFILE = process.env.GRAPHHOPPER_PROFILE || 'foot';
const USE_PUBLIC_TRANSPORT = process.env.USE_PUBLIC_TRANSPORT === 'true' || true; // Default: use PT

// PostgreSQL Connection (OSM data)
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// PostgreSQL Connection (GTFS data)
const gtfsPool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: 'osm2gtfs',
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// Initialize database extensions
async function initializeDatabase() {
  try {
    // Enable trigram extension for fuzzy search in both databases
    await pool.query('CREATE EXTENSION IF NOT EXISTS pg_trgm;');
    await gtfsPool.query('CREATE EXTENSION IF NOT EXISTS pg_trgm;');
    console.log('Database extensions initialized for both OSM and GTFS databases');
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
        stop_id,
        stop_name,
        stop_lat,
        stop_lon,
        location_type
      FROM stops 
      WHERE stop_name IS NOT NULL
    `;
    
    const values = [];
    
    // Add bounding box filter if provided
    if (west && south && east && north) {
      query += ` AND stop_lon BETWEEN $1 AND $3 AND stop_lat BETWEEN $2 AND $4`;
      values.push(parseFloat(west), parseFloat(south), parseFloat(east), parseFloat(north));
    } else if (bbox) {
      const [bboxWest, bboxSouth, bboxEast, bboxNorth] = bbox.split(',').map(Number);
      query += ` AND stop_lon BETWEEN $1 AND $3 AND stop_lat BETWEEN $2 AND $4`;
      values.push(bboxWest, bboxSouth, bboxEast, bboxNorth);
    }
    
    // Remove LIMIT to get all stops in the bounding box
    
    const result = await gtfsPool.query(query, values);
    
    const stops = result.rows.map(row => ({
      id: row.stop_id,
      name: row.stop_name || 'Unnamed Stop',
      type: row.location_type === 1 ? 'station' : 'stop',
      coordinates: [row.stop_lon, row.stop_lat]
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
    
    // PostgreSQL Fuzzy Search mit trigram similarity on GTFS stops
    const query = `
      SELECT 
        stop_id,
        stop_name,
        stop_lat,
        stop_lon,
        location_type,
        similarity(stop_name, $1) as similarity_score
      FROM stops 
      WHERE stop_name IS NOT NULL
        AND stop_name != ''
        AND (
          stop_name ILIKE $2
          OR similarity(stop_name, $1) > 0.3
        )
      ORDER BY 
        similarity_score DESC,
        stop_name ASC
      LIMIT 20
    `;
    
    const searchPattern = `%${searchQuery}%`;
    const result = await gtfsPool.query(query, [searchQuery, searchPattern]);
    
    const stations = result.rows.map(row => ({
      id: row.stop_id,
      name: row.stop_name,
      type: row.location_type === 1 ? 'station' : 'stop',
      coordinates: {
        lat: parseFloat(row.stop_lat),
        lng: parseFloat(row.stop_lon)
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

// API Endpoint für Routenberechnung zwischen zwei Haltestellen mit GraphHopper
app.get('/api/routes/calculate', async (req, res) => {
  try {
    const { from, to } = req.query;
    
    if (!from || !to) {
      return res.status(400).json({ 
        error: 'Both from and to station IDs are required' 
      });
    }

    console.log(`Calculating route from ${from} to ${to} using GraphHopper`);

    // 1. Get station coordinates from GTFS database
    const stationQuery = `
      SELECT 
        stop_id,
        stop_name,
        stop_lat,
        stop_lon
      FROM stops 
      WHERE stop_id IN ($1, $2)
    `;
    
    const stationResult = await gtfsPool.query(stationQuery, [from, to]);
    
    if (stationResult.rows.length !== 2) {
      return res.status(404).json({ 
        error: 'One or both stations not found' 
      });
    }

    const fromStation = stationResult.rows.find(row => row.stop_id === from);
    const toStation = stationResult.rows.find(row => row.stop_id === to);

    console.log('From Station:', {
      stop_id: fromStation.stop_id,
      name: fromStation.stop_name,
      lon: fromStation.stop_lon,
      lat: fromStation.stop_lat
    });
    console.log('To Station:', {
      stop_id: toStation.stop_id,
      name: toStation.stop_name,
      lon: toStation.stop_lon,
      lat: toStation.stop_lat
    });

    // 2. Call GraphHopper API for routing
    let graphhopperUrl;
    let graphhopperParams;
    
    if (USE_PUBLIC_TRANSPORT) {
      // Use Public Transport endpoint
      graphhopperUrl = `${GRAPHHOPPER_URL}/route-pt`;
      
      // Get current time or use provided time
      const now = new Date();
      const departureTime = now.toISOString();
      
      graphhopperParams = {
        point: [
          `${fromStation.stop_lat},${fromStation.stop_lon}`,
          `${toStation.stop_lat},${toStation.stop_lon}`
        ],
        'pt.earliest_departure_time': departureTime,
        'pt.profile': true,
        locale: 'de',
        instructions: true,
        'pt.limit_solutions': 3
      };
    } else {
      // Use regular routing endpoint (foot/bike/car)
      graphhopperUrl = `${GRAPHHOPPER_URL}/route`;
      graphhopperParams = {
        point: [
          `${fromStation.stop_lat},${fromStation.stop_lon}`,
          `${toStation.stop_lat},${toStation.stop_lon}`
        ],
        profile: GRAPHHOPPER_PROFILE,
        locale: 'de',
        instructions: true,
        calc_points: true,
        points_encoded: false
      };
    }

    console.log('Calling GraphHopper API:', graphhopperUrl, graphhopperParams);

    const paramsSerializer = params => {
  const parts = [];

  // Serialize points correctly
  if (Array.isArray(params.point)) {
    params.point.forEach(p => parts.push(`point=${encodeURIComponent(p)}`));
  }

  // Serialize the remaining PT params
  for (const key in params) {
    if (key === "point") continue;
    parts.push(`${key}=${encodeURIComponent(params[key])}`);
  }

  return parts.join("&");
};

try {
  graphhopperResponse = await axios.get(graphhopperUrl, {
    params: graphhopperParams,
    paramsSerializer,
    timeout: 10000
  });
    } catch (graphhopperError) {
      console.error('GraphHopper API error:', graphhopperError.message);
      if (graphhopperError.response) {
        console.error('GraphHopper error response:', {
          status: graphhopperError.response.status,
          data: graphhopperError.response.data
        });
      }
      
      // Fallback to simple straight line if GraphHopper fails
      console.log('Falling back to direct connection');
      const fallbackRoute = {
        route: {
          type: 'Feature',
          properties: {
            from: {
              id: fromStation.stop_id,
              name: fromStation.stop_name,
              type: 'stop',
              coordinates: [fromStation.stop_lon, fromStation.stop_lat]
            },
            to: {
              id: toStation.stop_id,
              name: toStation.stop_name,
              type: 'stop',
              coordinates: [toStation.stop_lon, toStation.stop_lat]
            },
            distance: calculateDistance(
              fromStation.stop_lat, fromStation.stop_lon,
              toStation.stop_lat, toStation.stop_lon
            ),
            duration: 0,
            type: 'direct_connection',
            source: 'fallback',
            error: 'GraphHopper not available'
          },
          geometry: {
            type: "LineString",
            coordinates: [
              [fromStation.stop_lon, fromStation.stop_lat],
              [toStation.stop_lon, toStation.stop_lat]
            ]
          }
        },
        instructions: [],
        nearbyRoutes: []
      };
      
      return res.json(fallbackRoute);
    }

    const ghData = graphhopperResponse.data;
    
    // Handle both PT and regular routing responses
    let path;
    let routeGeometry;
    let instructions = [];
    let routeType = 'graphhopper_route';
    
    if (USE_PUBLIC_TRANSPORT && ghData.paths) {
      // Public Transport response
      if (!ghData.paths || ghData.paths.length === 0) {
        return res.status(404).json({ 
          error: 'No public transport route found by GraphHopper' 
        });
      }
      
      path = ghData.paths[0];

      /* --- GTFS Route Name Enrichment for PT Legs --- */
      if (path.legs) {
        for (let i = 0; i < path.legs.length; i++) {
          const leg = path.legs[i];

          if (leg.type === "pt" && leg.route_id) {
            try {
              const routeLookup = await gtfsPool.query(
                `SELECT route_short_name, route_long_name 
                 FROM routes 
                 WHERE route_id = $1
                 LIMIT 1`,
                [leg.route_id]
              );

              if (routeLookup.rows.length > 0) {
                const r = routeLookup.rows[0];
                leg.route_short_name = r.route_short_name || null;
                leg.route_long_name = r.route_long_name || null;
                leg.display_line = r.route_short_name 
                  ? r.route_short_name 
                  : leg.route_id;
              } else {
                leg.display_line = leg.route_id;
              }
            } catch (lookupError) {
              console.error("GTFS route lookup failed:", lookupError.message);
              leg.display_line = leg.route_id;
            }
          }
        }
      }
      /* --- END GTFS Route Name Enrichment --- */
      
      // PT routes have legs with different transport modes
      if (path.legs) {
        // Combine all leg geometries
        const allCoordinates = [];
        path.legs.forEach(leg => {
          if (leg.geometry && leg.geometry.coordinates) {
            allCoordinates.push(...leg.geometry.coordinates);
          }
        });
        
        routeGeometry = {
          type: "LineString",
          coordinates: allCoordinates
        };
        
        // Extract instructions from legs
        path.legs.forEach((leg, legIndex) => {
          if (leg.instructions) {
            instructions.push(...leg.instructions.map(instr => ({
              ...instr,
              legIndex: legIndex,
              legType: leg.type || 'unknown'
            })));
          }
        });
        
        routeType = 'public_transport';
      } else {
        // Fallback if no legs
        routeGeometry = {
          type: "LineString",
          coordinates: path.points?.coordinates || [
            [fromStation.stop_lon, fromStation.stop_lat],
            [toStation.stop_lon, toStation.stop_lat]
          ]
        };
        instructions = path.instructions || [];
      }
    } else {
      // Regular routing response
      if (!ghData.paths || ghData.paths.length === 0) {
        return res.status(404).json({ 
          error: 'No route found by GraphHopper' 
        });
      }
      
      path = ghData.paths[0];
      
      routeGeometry = {
        type: "LineString",
        coordinates: path.points.coordinates // GraphHopper returns [lon, lat] format
      };
      
      instructions = path.instructions || [];
    }

    // 4. Find nearby routes/lines for better visualization
    const nearbyRoutesQuery = `
      SELECT DISTINCT
        osm_id,
        name,
        route,
        ST_AsGeoJSON(ST_Transform(way, 4326)) as geometry
      FROM planet_osm_line 
      WHERE (
        route IN ('subway', 'tram', 'bus', 'train')
        OR railway IN ('subway', 'tram', 'rail')
      )
      AND (
        ST_DWithin(
          ST_Transform(way, 4326)::geography,
          ST_MakePoint($1, $2)::geography,
          500
        )
        OR ST_DWithin(
          ST_Transform(way, 4326)::geography,
          ST_MakePoint($3, $4)::geography,
          500
        )
      )
      LIMIT 30
    `;

    const nearbyRoutes = await pool.query(nearbyRoutesQuery, [
      fromStation.stop_lon, fromStation.stop_lat,
      toStation.stop_lon, toStation.stop_lat
    ]);

    const response = {
      route: {
        type: 'Feature',
        properties: {
          from: {
            id: fromStation.stop_id,
            name: fromStation.stop_name,
            type: 'stop',
            coordinates: [fromStation.stop_lon, fromStation.stop_lat]
          },
          to: {
            id: toStation.stop_id,
            name: toStation.stop_name,
            type: 'stop',
            coordinates: [toStation.stop_lon, toStation.stop_lat]
          },
          distance: path.distance / 1000, // Convert meters to kilometers
          duration: path.time / 1000, // Convert milliseconds to seconds
          type: routeType,
          source: 'graphhopper',
          profile: USE_PUBLIC_TRANSPORT ? 'pt' : GRAPHHOPPER_PROFILE,
          transfers: path.transfers || 0,
          legs: path.legs || []
        },
        geometry: routeGeometry
      },
      instructions: instructions,
      nearbyRoutes: [] // Disabled - showing only the calculated route
    };

    const routeInfo = USE_PUBLIC_TRANSPORT 
      ? `${response.route.properties.distance.toFixed(2)}km, ${(response.route.properties.duration / 60).toFixed(1)}min, ${response.route.properties.transfers} transfers`
      : `${response.route.properties.distance.toFixed(2)}km, ${(response.route.properties.duration / 60).toFixed(1)}min`;
    
    console.log(`GraphHopper ${routeType} calculated: ${routeInfo}`);
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