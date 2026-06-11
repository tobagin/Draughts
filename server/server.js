#!/usr/bin/env node

/**
 * Draughts Multiplayer WebSocket Server
 *
 * A lightweight relay server for real-time multiplayer draughts games.
 * Handles room creation, matchmaking, and move synchronization.
 */

const WebSocket = require('ws');
const http = require('http');
const crypto = require('crypto');
const { createClient } = require('@supabase/supabase-js');
const { renderDashboard } = require('./dashboard');

const PORT = process.env.PORT || 8443;
const ROOM_CODE_LENGTH = 6;
const REQUIRED_VERSION = '2.0.1'; // Minimum client version required
const GAME_INACTIVITY_TIMEOUT = 30 * 60 * 1000; // 30 minutes of inactivity
const DISCONNECT_TIMEOUT = 60 * 1000; // 60 seconds to reconnect
const MOVE_MIN_INTERVAL_MS = 50; // Minimum spacing between moves from one client (anti-flood)
const MOVE_BURST_ALLOWANCE = 4; // Tolerate short bursts (e.g. rapid multi-capture steps)
const SERVER_VERSION = require('./package.json').version; // Single source of truth
const STATS_CACHE_TTL_MS = 5000; // Cache the dashboard HTML briefly to shield Supabase from refresh/abuse

// Logging utility with timestamps
function getTimestamp() {
  const now = new Date();
  return `[${now.toISOString().substring(11, 23)}]`; // HH:MM:SS.mmm format
}

function log(...args) {
  console.log(getTimestamp(), ...args);
}

function logError(...args) {
  console.error(getTimestamp(), ...args);
}

// Initialize Supabase client (optional - gracefully degrades if not configured)
let supabase = null;
const ENABLE_SUPABASE = process.env.ENABLE_SUPABASE !== 'false';

if (ENABLE_SUPABASE && process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
  supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
  log('✅ Supabase connected - game history and stats will be persisted');
} else {
  log('⚠️  Supabase not configured - running in memory-only mode');
}

// Game rooms storage
const rooms = new Map();

// Client connections storage
const clients = new Map();

// Quick match queue (variant -> array of waiting clients)
const quickMatchQueue = new Map();

// Statistics tracking
const stats = {
  totalGames: 0,
  activeGames: 0,
  completedGames: 0,
  gamesByVariant: {},
  gamesByResult: {
    red_wins: 0,
    black_wins: 0,
    draw: 0,
    resignation: 0,
    timeout: 0
  },
  peakConcurrentGames: 0,
  peakConcurrentGamesAllTime: 0, // All-time peak (loaded from DB)
  totalConnections: 0, // Session only
  totalConnectionsAllTime: 0, // All-time (loaded from DB)
  startTime: Date.now()
};

// Version comparison helper
function isVersionCompatible(clientVersion, requiredVersion) {
  const parseVersion = (v) => v.split('.').map(n => parseInt(n) || 0);
  const client = parseVersion(clientVersion);
  const required = parseVersion(requiredVersion);

  // Compare major.minor.patch
  for (let i = 0; i < 3; i++) {
    if (client[i] > required[i]) return true;
    if (client[i] < required[i]) return false;
  }
  return true; // Versions are equal
}

// Room code generator (cryptographically secure randomness)
function generateRoomCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code;
  do {
    code = '';
    const bytes = crypto.randomBytes(ROOM_CODE_LENGTH);
    for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
      code += chars.charAt(bytes[i] % chars.length);
    }
  } while (rooms.has(code)); // Ensure code is unique
  return code;
}

// Session ID generator (cryptographically secure, unguessable)
function generateSessionId() {
  return crypto.randomBytes(16).toString('hex');
}

/**
 * Validate the structure of an incoming move payload.
 * The server is a relay, but basic sanity checks prevent malformed or
 * malicious payloads (out-of-bounds coordinates, oversized capture arrays)
 * from being stored and forwarded to the opponent.
 */
function isValidMovePayload(move) {
  if (!move || typeof move !== 'object') return false;

  const MAX_BOARD = 12; // Largest supported board (Canadian draughts)
  const coords = [move.from_row, move.from_col, move.to_row, move.to_col];
  for (const c of coords) {
    if (!Number.isInteger(c) || c < 0 || c >= MAX_BOARD) return false;
  }

  if (!Number.isInteger(move.piece_id)) return false;

  if (move.captured_pieces !== undefined) {
    if (!Array.isArray(move.captured_pieces)) return false;
    // A capture chain can never exceed the opponent's piece count (max 30 on 12x12)
    if (move.captured_pieces.length > 30) return false;
    if (!move.captured_pieces.every(Number.isInteger)) return false;
  }

  return true;
}

/**
 * Sanitize a player-supplied display name: coerce to string, strip control
 * characters (prevents log injection), and cap the length so a malicious
 * client cannot exhaust memory or break logs/storage.
 */
function sanitizeName(value, fallback) {
  if (typeof value !== 'string') return fallback;
  // Drop control characters (prevents log injection) and cap length
  const cleaned = Array.from(value)
    .filter(ch => { const c = ch.charCodeAt(0); return c >= 0x20 && c !== 0x7F; })
    .join('')
    .trim()
    .slice(0, 40);
  return cleaned.length > 0 ? cleaned : fallback;
}

/**
 * Sanitize a variant identifier. Variants are short slugs (e.g. "international",
 * "graeco-turkish"); anything outside that shape is rejected so it can never be
 * persisted and rendered on the dashboard.
 */
function sanitizeVariant(value) {
  if (typeof value !== 'string') return null;
  const cleaned = value.trim().slice(0, 32);
  return /^[A-Za-z0-9 _-]+$/.test(cleaned) ? cleaned : null;
}

/**
 * Fetch stats from Supabase
 */
async function fetchSupabaseStats() {
  if (!supabase) return null;

  try {
    const { data, error } = await supabase
      .from('game_stats_summary')
      .select('*')
      .single();

    if (error) {
      logError('Failed to fetch stats from Supabase:', error.message);
      return null;
    }

    return data;
  } catch (err) {
    logError('Exception fetching stats from Supabase:', err);
    return null;
  }
}

/**
 * Fetch variant stats from Supabase
 */
async function fetchSupabaseVariantStats() {
  if (!supabase) return null;

  try {
    const { data, error} = await supabase
      .from('variant_stats')
      .select('*')
      .order('game_count', { ascending: false });

    if (error) {
      logError('Failed to fetch variant stats from Supabase:', error.message);
      return null;
    }

    return data;
  } catch (err) {
    logError('Exception fetching variant stats from Supabase:', err);
    return null;
  }
}

/**
 * Load server stats from Supabase (total connections and peak games)
 */
async function loadServerStats() {
  if (!supabase) return;

  try {
    const { data, error } = await supabase
      .from('server_stats')
      .select('*')
      .eq('id', 1)
      .single();

    if (error && error.code !== 'PGRST116') { // PGRST116 = no rows found
      logError('Failed to load server stats from Supabase:', error.message);
      return;
    }

    if (data) {
      stats.totalConnectionsAllTime = data.total_connections || 0;
      stats.peakConcurrentGamesAllTime = data.peak_concurrent_games || 0;
      log(`📊 Loaded stats: ${stats.totalConnectionsAllTime} total connections, ${stats.peakConcurrentGamesAllTime} peak games`);
    } else {
      // Initialize the row if it doesn't exist
      await supabase
        .from('server_stats')
        .insert({ id: 1, total_connections: 0, peak_concurrent_games: 0 });
      log('📊 Initialized server stats in database');
    }
  } catch (err) {
    logError('Exception loading server stats:', err);
  }
}

/**
 * Increment total connections in database
 */
async function incrementTotalConnections() {
  if (!supabase) return;

  try {
    stats.totalConnectionsAllTime++;

    const { error } = await supabase
      .from('server_stats')
      .update({
        total_connections: stats.totalConnectionsAllTime,
        updated_at: new Date().toISOString()
      })
      .eq('id', 1);

    if (error) {
      logError('Failed to increment total connections:', error.message);
    }
  } catch (err) {
    logError('Exception incrementing total connections:', err);
  }
}

/**
 * Update peak concurrent games if current exceeds stored peak
 */
async function updatePeakGames(currentActiveGames) {
  if (!supabase) return;

  if (currentActiveGames > stats.peakConcurrentGamesAllTime) {
    try {
      stats.peakConcurrentGamesAllTime = currentActiveGames;

      const { error } = await supabase
        .from('server_stats')
        .update({
          peak_concurrent_games: stats.peakConcurrentGamesAllTime,
          updated_at: new Date().toISOString()
        })
        .eq('id', 1);

      if (error) {
        logError('Failed to update peak games:', error.message);
      } else {
        log(`🔥 New peak! ${stats.peakConcurrentGamesAllTime} concurrent games`);
      }
    } catch (err) {
      logError('Exception updating peak games:', err);
    }
  }
}

/**
 * Gather the live data and hand it to the (presentation-only) dashboard
 * renderer. Keeps Supabase access here in the server, rendering in dashboard.js.
 */
async function generateStatsHTML() {
  const [supabaseStats, supabaseVariantStats] = await Promise.all([
    fetchSupabaseStats(),
    fetchSupabaseVariantStats()
  ]);

  return renderDashboard({
    stats,
    supabaseEnabled: !!supabase,
    clientsCount: clients.size,
    roomsCount: rooms.size,
    serverVersion: SERVER_VERSION,
    supabaseStats,
    supabaseVariantStats
  });
}

// Create HTTP server
// Short-lived cache for the rendered dashboard so repeated loads (the page
// auto-refreshes every 30s) don't hit Supabase on every request.
let statsCache = { html: null, expires: 0 };

// Security headers applied to every HTTP response
const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer'
};

const server = http.createServer((req, res) => {
  // Only GET/HEAD are meaningful for the read-only endpoints
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { ...SECURITY_HEADERS, 'Allow': 'GET, HEAD' });
    res.end('Method not allowed');
    return;
  }

  // Ignore any query string when matching routes
  const path = req.url.split('?')[0];

  if (path === '/health') {
    res.writeHead(200, { ...SECURITY_HEADERS, 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      version: SERVER_VERSION,
      rooms: rooms.size,
      clients: clients.size,
      uptime: process.uptime()
    }));
  } else if (path === '/stats') {
    const now = Date.now();
    if (statsCache.html && statsCache.expires > now) {
      res.writeHead(200, { ...SECURITY_HEADERS, 'Content-Type': 'text/html; charset=utf-8' });
      res.end(statsCache.html);
      return;
    }
    generateStatsHTML()
      .then(html => {
        statsCache = { html, expires: Date.now() + STATS_CACHE_TTL_MS };
        res.writeHead(200, { ...SECURITY_HEADERS, 'Content-Type': 'text/html; charset=utf-8' });
        res.end(html);
      })
      .catch(err => {
        // Without this catch a Supabase failure would leave the request hanging
        logError('Failed to render stats dashboard:', err);
        res.writeHead(500, { ...SECURITY_HEADERS, 'Content-Type': 'text/plain' });
        res.end('Internal server error');
      });
  } else {
    res.writeHead(404, { ...SECURITY_HEADERS, 'Content-Type': 'text/plain' });
    res.end('Not found');
  }
});

// Create WebSocket server with keepalive
const wss = new WebSocket.Server({
  server,
  clientTracking: true,
  perMessageDeflate: false // Disable compression for lower latency
});

// WebSocket keepalive - send pings every 25 seconds to keep connection alive
// (increased from 15s to reduce false timeouts)
const WEBSOCKET_PING_INTERVAL = 25000;
const keepaliveInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      log('⚠️  WebSocket connection timed out - no pong received in 25s');
      return ws.terminate();
    }

    ws.isAlive = false;
    ws.ping();
  });
}, WEBSOCKET_PING_INTERVAL);

wss.on('close', () => {
  clearInterval(keepaliveInterval);
});

log(`🎮 Draughts Multiplayer Server starting...`);

wss.on('connection', (ws) => {
  let clientId = null;
  let isReconnecting = false;

  // WebSocket-level keepalive
  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
    log(`🏓 Pong received from ${clientId || 'unknown'}`);
  });

  // Track total connections
  stats.totalConnections++;
  incrementTotalConnections(); // Persist to database

  // Wait for initial message to get session ID
  const handleFirstMessage = (data) => {
    try {
      const message = JSON.parse(data.toString());
      log(`📨 First message received - Type: ${message.type}, Version: ${message.version || 'not provided'}`);

      // Check client version
      const clientVersion = message.version || '0.0.0';
      if (!isVersionCompatible(clientVersion, REQUIRED_VERSION)) {
        send(ws, {
          type: 'error',
          error_code: 'VERSION_MISMATCH',
          error_description: `Client version ${clientVersion} is outdated. Please update to version ${REQUIRED_VERSION} or later.`,
          required_version: REQUIRED_VERSION,
          client_version: clientVersion
        });
        log(`❌ Client rejected due to version mismatch: ${clientVersion} < ${REQUIRED_VERSION}`);
        ws.close();
        return;
      }

      // Check if this is a reconnection
      if (message.type === 'reconnect' && message.session_id) {
        const existingClient = clients.get(message.session_id);
        if (existingClient) {
          // Reconnecting client
          clientId = message.session_id;
          isReconnecting = true;

          // Close old WebSocket if it exists and is still open
          if (existingClient.ws && existingClient.ws.readyState === WebSocket.OPEN) {
            log(`🔌 Closing old WebSocket for ${clientId}`);
            existingClient.ws.close();
          }

          existingClient.ws = ws;
          existingClient.disconnected = false;
          existingClient.disconnectTime = null;
          log(`🔄 Client reconnected: ${clientId}`);

          // Send reconnection success with current game state
          const room = rooms.get(existingClient.roomCode);
          send(ws, {
            type: 'reconnected',
            session_id: clientId,
            room_code: existingClient.roomCode,
            player_name: existingClient.playerName,
            player_color: existingClient.playerColor,
            room: room ? {
              variant: room.variant,
              opponent_name: (clientId === room.host) ? room.guestName : room.hostName
            } : null
          });

          // Notify opponent of reconnection if in a room
          if (room) {
            const opponentId = (clientId === room.host) ? room.guest : room.host;
            const opponentClient = clients.get(opponentId);
            if (opponentClient) {
              send(opponentClient.ws, {
                type: 'opponent_reconnected',
                timestamp: Date.now()
              });
            }

            // If the game is in progress, send GAME_STARTED to restore the game
            if (room.gameStarted) {
              const opponentName = (clientId === room.host) ? room.guestName : room.hostName;

              const allMoves = room.moves ? room.moves.map(m => m.move) : [];

              // Incremental restore: if the client still holds game state from
              // before the blip (it reports how many moves it has already
              // applied), only send the moves it is missing instead of the
              // entire history. Falls back to a full replay on a fresh start.
              let appliedCount = Number.isInteger(message.applied_move_count) ? message.applied_move_count : 0;
              if (appliedCount < 0 || appliedCount > allMoves.length) {
                appliedCount = 0; // Out of range - safest to resend everything
              }
              const movesToRestore = allMoves.slice(appliedCount);

              // Prepare reconnection message with timer settings
              const reconnectMessage = {
                type: 'game_started',
                variant: room.variant,
                your_color: existingClient.playerColor,
                opponent_name: opponentName,
                room_code: existingClient.roomCode,
                moves: movesToRestore,            // Only the moves the client is missing
                base_move_count: appliedCount,    // Index the delta starts at (0 = full replay)
                total_move_count: allMoves.length // Where the client should end up
              };

              // Add timer settings if enabled
              if (room.use_timer) {
                reconnectMessage.use_timer = true;
                reconnectMessage.minutes_per_side = room.minutes_per_side;
                reconnectMessage.increment_seconds = room.increment_seconds;
                reconnectMessage.clock_type = room.clock_type;
                // Send current timer state
                reconnectMessage.red_time_remaining = room.redTimeRemaining;
                reconnectMessage.black_time_remaining = room.blackTimeRemaining;
                reconnectMessage.active_player_color = room.activePlayerColor;
              } else {
                reconnectMessage.use_timer = false;
              }

              send(ws, reconnectMessage);

              log(`🎮 Restored game session for ${clientId} - ${room.variant} as ${existingClient.playerColor} (sent ${movesToRestore.length} of ${allMoves.length} moves, from #${appliedCount})`);
            }
          }
        } else {
          // Session expired or invalid
          clientId = generateSessionId();
          log(`✅ Client connected (expired session): ${clientId}`);
          clients.set(clientId, { ws, roomCode: null, playerName: null, playerColor: null });
          send(ws, { type: 'connected', session_id: clientId });
        }
      } else {
        // New connection
        clientId = generateSessionId();
        log(`✅ Client connected: ${clientId}`);
        clients.set(clientId, { ws, roomCode: null, playerName: null, playerColor: null });
        send(ws, { type: 'connected', session_id: clientId });
      }

      // Remove the temporary listener and set up normal message handling
      ws.off('message', handleFirstMessage);
      ws.on('message', (data) => {
        try {
          const message = JSON.parse(data.toString());
          handleMessage(clientId, message);
        } catch (error) {
          logError(`❌ Error parsing message from ${clientId}:`, error);
          sendError(ws, 'PARSE_ERROR', 'Invalid JSON');
        }
      });

      // 'connect' and 'reconnect' are handshake messages fully handled above;
      // anything else that arrived as the first message is a real request.
      if (message.type !== 'reconnect' && message.type !== 'connect') {
        handleMessage(clientId, message);
      }

    } catch (error) {
      logError(`❌ Error in initial connection:`, error);
      ws.close();
    }
  };

  ws.on('message', handleFirstMessage);

  ws.on('close', () => {
    if (clientId) {
      // Ignore close events from a stale socket that was replaced by a
      // reconnection - otherwise the old socket's close would mark the
      // freshly reconnected client as disconnected
      const client = clients.get(clientId);
      if (client && client.ws !== ws) {
        log(`🔌 Stale socket closed for ${clientId} (already reconnected)`);
        return;
      }
      log(`❌ Client disconnected: ${clientId}`);
      handleDisconnect(clientId);
    }
  });

  ws.on('error', (error) => {
    if (clientId) {
      logError(`❌ WebSocket error for ${clientId}:`, error);
    }
  });
});

/**
 * Handle incoming messages from clients
 */
function handleMessage(clientId, message) {
  const { type, timestamp } = message;
  const client = clients.get(clientId);

  if (!client) {
    log(`⚠️  Received message from unknown client: ${clientId} (${type})`);
    return;
  }

  log(`📨 Message from ${clientId}: ${type}`);

  switch (type) {
    case 'create_room':
      handleCreateRoom(clientId, message);
      break;

    case 'join_room':
      handleJoinRoom(clientId, message);
      break;

    case 'quick_match':
      handleQuickMatch(clientId, message);
      break;

    case 'cancel_quick_match':
      handleCancelQuickMatch(clientId);
      break;

    case 'make_move':
      handleMove(clientId, message);
      break;

    case 'resign':
      handleResign(clientId);
      break;

    case 'offer_draw':
      handleOfferDraw(clientId);
      break;

    case 'accept_draw':
      handleAcceptDraw(clientId);
      break;

    case 'reject_draw':
      handleRejectDraw(clientId);
      break;

    case 'game_ended':
      handleGameEnded(clientId, message);
      break;

    case 'ping':
      handlePing(clientId, timestamp);
      break;

    default:
      log(`⚠️  Unknown message type: ${type}`);
      sendError(client.ws, 'UNKNOWN_TYPE', `Unknown message type: ${type}`);
  }
}

/**
 * Handle room creation
 */
function handleCreateRoom(clientId, message) {
  const client = clients.get(clientId);
  if (!client) return;
  const { use_timer, minutes_per_side, increment_seconds, clock_type } = message;

  // Sanitize client-supplied values before storing/persisting them
  const variant = sanitizeVariant(message.variant);
  if (!variant) {
    sendError(client.ws, 'INVALID_VARIANT', 'Unknown or malformed game variant');
    return;
  }
  const hostName = sanitizeName(message.player_name, 'Host');

  const roomCode = generateRoomCode();
  const playerColor = 'Red'; // Host is always Red

  rooms.set(roomCode, {
    code: roomCode,
    host: clientId,
    guest: null,
    variant,
    use_timer,
    minutes_per_side,
    increment_seconds,
    clock_type,
    hostName,
    guestName: null,
    gameStarted: false,
    moves: [],
    lastActivityTime: Date.now(),
    inactivityTimer: null,
    // Timer state (server-tracked)
    redTimeRemaining: use_timer ? minutes_per_side * 60 * 1000 : null, // milliseconds
    blackTimeRemaining: use_timer ? minutes_per_side * 60 * 1000 : null,
    activePlayerColor: 'red', // Who's timer is running
    lastMoveTime: null // When the last move was made
  });

  client.roomCode = roomCode;
  client.playerName = hostName;
  client.playerColor = playerColor;

  send(client.ws, {
    type: 'room_created',
    room_code: roomCode,
    player_color: playerColor,
    timestamp: Date.now()
  });

  log(`🏠 Room created: ${roomCode} by ${hostName}`);
}

/**
 * Handle joining a room
 */
function handleJoinRoom(clientId, message) {
  const client = clients.get(clientId);
  if (!client) return;
  const { room_code } = message;
  const guestName = sanitizeName(message.player_name, 'Guest');

  const room = rooms.get(room_code);

  if (!room) {
    sendError(client.ws, 'ROOM_NOT_FOUND', `Room ${room_code} not found`);
    return;
  }

  if (room.guest) {
    sendError(client.ws, 'ROOM_FULL', 'Room is already full');
    return;
  }

  if (room.gameStarted) {
    sendError(client.ws, 'GAME_STARTED', 'Game has already started');
    return;
  }

  // Add guest to room
  room.guest = clientId;
  room.guestName = guestName;
  client.roomCode = room_code;
  client.playerName = guestName;
  client.playerColor = 'Black'; // Guest is always Black

  // Notify host that opponent joined
  const hostClient = clients.get(room.host);
  if (hostClient) {
    send(hostClient.ws, {
      type: 'opponent_joined',
      opponent_name: guestName,
      timestamp: Date.now()
    });
  }

  // Start the game
  startGame(room_code);
}

/**
 * Start a game in a room
 */
function startGame(room_code) {
  const room = rooms.get(room_code);
  if (!room) {
    logError(`❌ Cannot start game: Room ${room_code} not found`);
    return;
  }

  if (room.gameStarted) {
    log(`⚠️ Game already started in room ${room_code}`);
    return;
  }

  room.gameStarted = true;
  room.startedAt = Date.now();
  room.lastMoveTime = Date.now(); // Initialize for timer tracking

  // Update stats
  stats.totalGames++;
  stats.activeGames++;
  if (!stats.gamesByVariant[room.variant]) {
    stats.gamesByVariant[room.variant] = 0;
  }
  stats.gamesByVariant[room.variant]++;
  if (stats.activeGames > stats.peakConcurrentGames) {
    stats.peakConcurrentGames = stats.activeGames;
  }

  // Update all-time peak in database
  updatePeakGames(stats.activeGames);

  const hostClient = clients.get(room.host);
  const guestClient = clients.get(room.guest);

  if (!hostClient || !guestClient) {
    logError(`❌ Cannot start game: Missing players in room ${room_code}`);
    return;
  }

  // Send game_started to both players (include timer settings if enabled)
  const gameStartedMessage = {
    type: 'game_started',
    variant: room.variant,
    timestamp: Date.now()
  };

  // Add timer settings if enabled
  if (room.use_timer) {
    gameStartedMessage.use_timer = true;
    gameStartedMessage.minutes_per_side = room.minutes_per_side;
    gameStartedMessage.increment_seconds = room.increment_seconds;
    gameStartedMessage.clock_type = room.clock_type;
    // Send current timer state
    gameStartedMessage.red_time_remaining = room.redTimeRemaining;
    gameStartedMessage.black_time_remaining = room.blackTimeRemaining;
    gameStartedMessage.active_player_color = room.activePlayerColor;
  } else {
    gameStartedMessage.use_timer = false;
  }

  send(guestClient.ws, {
    ...gameStartedMessage,
    your_color: 'Black',
    opponent_name: room.hostName
  });

  send(hostClient.ws, {
    ...gameStartedMessage,
    your_color: 'Red',
    opponent_name: room.guestName
  });

  // Start inactivity timer
  startInactivityTimer(room);

  log(`🎮 Game started in room ${room_code}: ${room.hostName} vs ${room.guestName}`);
}

/**
 * Handle move made
 */
function handleMove(clientId, message) {
  const client = clients.get(clientId);
  if (!client) return;

  // Reject moves from disconnected clients
  if (client.disconnected) {
    log(`⚠️  Rejected move from disconnected client: ${clientId}`);
    return;
  }

  // Reject malformed or out-of-bounds move payloads before storing/forwarding
  if (!isValidMovePayload(message.move)) {
    log(`⚠️  Rejected invalid move payload from client: ${clientId}`);
    sendError(client.ws, 'INVALID_MOVE', 'Malformed move payload');
    return;
  }

  // Rate limit move submissions to prevent a malicious client from flooding
  // the opponent or exhausting server memory. A small burst budget absorbs
  // legitimate rapid input (e.g. a multi-capture played in quick succession).
  const nowTs = Date.now();
  if (client.lastMoveAt !== undefined) {
    const sinceLast = nowTs - client.lastMoveAt;
    if (sinceLast < MOVE_MIN_INTERVAL_MS) {
      client.moveBurst = (client.moveBurst || 0) + 1;
      if (client.moveBurst > MOVE_BURST_ALLOWANCE) {
        log(`⚠️  Rate-limited move flood from client: ${clientId}`);
        sendError(client.ws, 'RATE_LIMITED', 'Too many moves too quickly');
        return;
      }
    } else {
      client.moveBurst = 0;
    }
  }
  client.lastMoveAt = nowTs;

  const room = rooms.get(client.roomCode);

  if (!room) {
    sendError(client.ws, 'NO_ROOM', 'Not in a room');
    return;
  }

  // Update timer state if enabled
  if (room.use_timer && room.lastMoveTime) {
    const now = Date.now();
    const timeElapsed = now - room.lastMoveTime;

    // Deduct time from the player who just moved
    const playerColor = (clientId === room.host) ? 'red' : 'black';
    if (playerColor === 'red') {
      room.redTimeRemaining = Math.max(0, room.redTimeRemaining - timeElapsed);
      // Add increment if using Fischer clock
      if (room.clock_type === 'Fischer' && room.increment_seconds) {
        room.redTimeRemaining += room.increment_seconds * 1000;
      }
    } else {
      room.blackTimeRemaining = Math.max(0, room.blackTimeRemaining - timeElapsed);
      // Add increment if using Fischer clock
      if (room.clock_type === 'Fischer' && room.increment_seconds) {
        room.blackTimeRemaining += room.increment_seconds * 1000;
      }
    }

    // Switch active player
    room.activePlayerColor = (playerColor === 'red') ? 'black' : 'red';
    room.lastMoveTime = now;

    log(`⏱️  Timer update: Red ${Math.floor(room.redTimeRemaining/1000)}s, Black ${Math.floor(room.blackTimeRemaining/1000)}s`);
  }

  // Store move
  room.moves.push({
    player: clientId,
    move: message.move,
    timestamp: Date.now()
  });

  // Update last activity time and reset inactivity timer
  room.lastActivityTime = Date.now();
  startInactivityTimer(room);

  // Forward move to opponent with timer state
  const opponentId = (clientId === room.host) ? room.guest : room.host;
  const opponentClient = clients.get(opponentId);

  if (opponentClient) {
    const moveMessage = {
      type: 'move_made',
      move: message.move,
      timestamp: Date.now()
    };

    // Add timer state if enabled
    if (room.use_timer) {
      moveMessage.red_time_remaining = room.redTimeRemaining;
      moveMessage.black_time_remaining = room.blackTimeRemaining;
      moveMessage.active_player_color = room.activePlayerColor;
    }

    send(opponentClient.ws, moveMessage);
  }

  log(`♟️  Move in room ${client.roomCode} - Move #${room.moves.length} by ${client.playerName} (${client.playerColor}) - Total moves: ${room.moves.length}`);
}

/**
 * Handle resign
 */
function handleResign(clientId) {
  const client = clients.get(clientId);

  // Reject resignation from disconnected clients
  if (client.disconnected) {
    log(`⚠️  Rejected resign from disconnected client: ${clientId}`);
    return;
  }

  const room = rooms.get(client.roomCode);

  if (!room) return;

  const winner = (clientId === room.host) ? 'black_wins' : 'red_wins';

  // Update stats
  if (room.gameStarted) {
    stats.activeGames--;
    stats.completedGames++;

    // Track result type
    if (winner === 'red_wins') {
      stats.gamesByResult.red_wins++;
    } else if (winner === 'black_wins') {
      stats.gamesByResult.black_wins++;
    }

    // Track resignation
    stats.gamesByResult.resignation++;
  }

  // Save game to Supabase
  saveGameToSupabase(room, winner, 'resignation');

  // Notify both players
  broadcastToRoom(room, {
    type: 'game_ended',
    result: winner,
    reason: 'resignation',
    timestamp: Date.now()
  });

  log(`🏳️  ${client.playerName} resigned in room ${client.roomCode}`);
  cleanupRoom(room.code);
}

/**
 * Handle offer draw
 */
function handleOfferDraw(clientId) {
  const client = clients.get(clientId);
  const room = rooms.get(client.roomCode);

  if (!room) return;

  const opponentId = (clientId === room.host) ? room.guest : room.host;
  const opponentClient = clients.get(opponentId);

  if (opponentClient) {
    send(opponentClient.ws, {
      type: 'draw_offered',
      timestamp: Date.now()
    });
  }

  log(`🤝 Draw offered in room ${client.roomCode}`);
}

/**
 * Handle accept draw
 */
function handleAcceptDraw(clientId) {
  const client = clients.get(clientId);
  const room = rooms.get(client.roomCode);

  if (!room) return;

  broadcastToRoom(room, {
    type: 'game_ended',
    result: 'draw',
    reason: 'agreement',
    timestamp: Date.now()
  });

  log(`🤝 Draw accepted in room ${client.roomCode}`);
  cleanupRoom(room.code);
}

/**
 * Handle reject draw
 */
function handleRejectDraw(clientId) {
  const client = clients.get(clientId);
  const room = rooms.get(client.roomCode);

  if (!room) return;

  const opponentId = (clientId === room.host) ? room.guest : room.host;
  const opponentClient = clients.get(opponentId);

  if (opponentClient) {
    send(opponentClient.ws, {
      type: 'draw_response',
      accepted: false,
      timestamp: Date.now()
    });
  }

  log(`❌ Draw rejected in room ${client.roomCode}`);
}

/**
 * Handle game ended (natural end - checkmate, no moves, etc.)
 */
function handleGameEnded(clientId, message) {
  const client = clients.get(clientId);
  if (!client || !client.roomCode) return;

  const room = rooms.get(client.roomCode);

  if (!room) return;

  const { result, reason } = message;

  // Update stats
  if (room.gameStarted) {
    stats.activeGames--;
    stats.completedGames++;

    // Track result type
    if (result === 'red_wins' || result === 'Red wins') {
      stats.gamesByResult.red_wins++;
    } else if (result === 'black_wins' || result === 'Black wins') {
      stats.gamesByResult.black_wins++;
    } else if (result === 'draw') {
      stats.gamesByResult.draw++;
    }

    // Track reason
    if (reason === 'resignation') {
      stats.gamesByResult.resignation++;
    } else if (reason === 'timeout') {
      stats.gamesByResult.timeout++;
    }
  }

  // Save game to Supabase
  saveGameToSupabase(room, result, reason);

  // Broadcast game ended to both players
  broadcastToRoom(room, {
    type: 'game_ended',
    result: result || 'unknown',
    reason: reason || 'game_over',
    timestamp: Date.now()
  });

  log(`🏁 Game ended in room ${client.roomCode}: ${result} (${reason})`);
  cleanupRoom(room.code);
}

/**
 * Handle ping
 */
function handlePing(clientId, timestamp) {
  const client = clients.get(clientId);
  if (!client) {
    log(`⚠️  Received ping from unknown client: ${clientId}`);
    return;
  }
  send(client.ws, {
    type: 'pong',
    timestamp: timestamp || Date.now()
  });
}

/**
 * Handle client disconnect
 */
function handleDisconnect(clientId) {
  const client = clients.get(clientId);

  if (client) {
    // Mark client as disconnected but keep data for reconnection
    client.disconnected = true;
    client.disconnectTime = Date.now();

    if (client.roomCode) {
      const room = rooms.get(client.roomCode);

      if (room) {
        // Notify opponent
        const opponentId = (clientId === room.host) ? room.guest : room.host;
        const opponentClient = clients.get(opponentId);

        if (opponentClient) {
          send(opponentClient.ws, {
            type: 'opponent_disconnected',
            timestamp: Date.now()
          });

          // After disconnect timeout, if still disconnected, end game
          setTimeout(() => {
            const currentClient = clients.get(clientId);
            if (currentClient && currentClient.disconnected) {
              const winner = (clientId === room.host) ? 'black_wins' : 'red_wins';

              // Save game to Supabase
              saveGameToSupabase(room, winner, 'disconnect_timeout');

              send(opponentClient.ws, {
                type: 'game_ended',
                result: winner,
                reason: 'opponent_timeout',
                timestamp: Date.now()
              });
              cleanupRoom(room.code);
              clients.delete(clientId); // Now fully remove client
            }
          }, DISCONNECT_TIMEOUT);
        }
      }
    }

    // Always give disconnect timeout to reconnect, regardless of room state
    setTimeout(() => {
      const currentClient = clients.get(clientId);
      if (currentClient && currentClient.disconnected) {
        log(`⏱️  Client session expired after ${DISCONNECT_TIMEOUT / 1000}s: ${clientId}`);
        clients.delete(clientId);
      }
    }, DISCONNECT_TIMEOUT);
  }
}

/**
 * Broadcast message to all players in a room
 */
function broadcastToRoom(room, message) {
  const hostClient = clients.get(room.host);
  const guestClient = clients.get(room.guest);

  if (hostClient) send(hostClient.ws, message);
  if (guestClient) send(guestClient.ws, message);
}

/**
 * Save game to Supabase
 */
async function saveGameToSupabase(room, winner, reason) {
  if (!supabase) return; // Skip if Supabase not configured
  if (room.saved) {
    log(`⚠️  Game ${room.code} already saved, skipping duplicate save`);
    return; // Prevent duplicate saves
  }

  room.saved = true; // Mark as saved

  try {
    const gameData = {
      room_code: room.code,
      variant: room.variant,
      host_name: room.hostName,
      guest_name: room.guestName,
      winner: winner,
      result_reason: reason,
      move_count: room.moves.length,
      duration_seconds: room.startedAt ? Math.floor((Date.now() - room.startedAt) / 1000) : 0,
      use_timer: room.use_timer || false,
      minutes_per_side: room.minutes_per_side || null,
      increment_seconds: room.increment_seconds || null,
      clock_type: room.clock_type || null,
      started_at: room.startedAt ? new Date(room.startedAt).toISOString() : new Date().toISOString(),
      ended_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('games')
      .insert([gameData])
      .select()
      .single();

    if (error) {
      logError('❌ Failed to save game to Supabase:', error.message);
      return null;
    }

    log(`💾 Game saved to Supabase: ${room.code} (ID: ${data.id})`);

    // Optionally save moves for replay
    if (room.moves && room.moves.length > 0) {
      const movesData = room.moves.map((move, index) => ({
        game_id: data.id,
        move_number: index + 1,
        player_color: move.player === room.host ? 'red' : 'black',
        move_data: move.move,
        timestamp: new Date(move.timestamp).toISOString()
      }));

      const { error: movesError } = await supabase
        .from('moves')
        .insert(movesData);

      if (movesError) {
        logError('❌ Failed to save moves to Supabase:', movesError.message);
      }
    }

    return data;
  } catch (err) {
    logError('❌ Exception saving game to Supabase:', err);
    return null;
  }
}

/**
 * Clean up a room
 */
/**
 * Start or restart inactivity timer for a room
 */
function startInactivityTimer(room) {
  // Don't use inactivity timer for games with time controls - they have their own timer
  if (room.use_timer) {
    return;
  }

  // Clear existing timer if any
  if (room.inactivityTimer) {
    clearTimeout(room.inactivityTimer);
  }

  // Set new timer
  room.inactivityTimer = setTimeout(() => {
    const timeSinceLastActivity = Date.now() - room.lastActivityTime;

    if (timeSinceLastActivity >= GAME_INACTIVITY_TIMEOUT) {
      log(`⏱️  Game in room ${room.code} timed out due to inactivity (${Math.floor(timeSinceLastActivity / 60000)} minutes)`);

      // Notify both players
      const hostClient = clients.get(room.host);
      const guestClient = clients.get(room.guest);

      if (hostClient && hostClient.ws) {
        send(hostClient.ws, {
          type: 'game_ended',
          result: 'draw',
          reason: 'Game abandoned due to inactivity',
          timestamp: Date.now()
        });
      }

      if (guestClient && guestClient.ws) {
        send(guestClient.ws, {
          type: 'game_ended',
          result: 'draw',
          reason: 'Game abandoned due to inactivity',
          timestamp: Date.now()
        });
      }

      // Update stats
      if (room.gameStarted) {
        stats.activeGames--;
        stats.completedGames++;
        stats.gamesByResult.timeout++;
      }

      // Save game to Supabase
      saveGameToSupabase(room, 'draw', 'inactivity');

      cleanupRoom(room.code);
    }
  }, GAME_INACTIVITY_TIMEOUT);
}

function cleanupRoom(roomCode) {
  const room = rooms.get(roomCode);
  if (room) {
    // Clear inactivity timer if exists
    if (room.inactivityTimer) {
      clearTimeout(room.inactivityTimer);
      room.inactivityTimer = null;
    }

    log(`🧹 Cleaning up room ${roomCode}`);
    rooms.delete(roomCode);
  }
}

/**
 * Send a message to a client
 */
function send(ws, message) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

/**
 * Send an error message
 */
function sendError(ws, code, description) {
  send(ws, {
    type: 'error',
    error_code: code,
    error_description: description,
    timestamp: Date.now()
  });
}

/**
 * Handle quick match request
 */
function handleQuickMatch(clientId, message) {
  const client = clients.get(clientId);
  if (!client) return;

  const variant = sanitizeVariant(message.variant);
  if (!variant) {
    sendError(client.ws, 'INVALID_VARIANT', 'Unknown or malformed game variant');
    return;
  }
  const player_name = sanitizeName(message.player_name, 'Player');

  log(`🎲 Quick match request from ${player_name} for ${variant}`);

  // Check if someone is already waiting for this variant
  if (!quickMatchQueue.has(variant)) {
    quickMatchQueue.set(variant, []);
  }

  const queue = quickMatchQueue.get(variant);

  // First, remove this client from queue if they're already in it (prevent duplicates)
  const existingIndex = queue.findIndex(entry => entry.clientId === clientId);
  if (existingIndex !== -1) {
    queue.splice(existingIndex, 1);
    log(`🔄 Removed duplicate entry for ${player_name} from queue`);
  }

  if (queue.length > 0) {
    // Match found! Pair with first waiting player
    const waitingClient = queue.shift();

    // Prevent self-matching
    if (waitingClient.clientId === clientId) {
      log(`⚠️  Prevented self-match for ${player_name}`);
      // Put them back in queue
      queue.push({
        clientId: clientId,
        playerName: player_name,
        ws: client.ws
      });
      return;
    }

    log(`✅ Match found! ${waitingClient.playerName} vs ${player_name}`);

    // Create a room for them
    const room_code = generateRoomCode();
    rooms.set(room_code, {
      code: room_code,
      host: waitingClient.clientId,
      hostName: waitingClient.playerName,
      guest: clientId,
      guestName: player_name,
      variant: variant,
      use_timer: false, // Quick match doesn't support timers yet
      minutes_per_side: null,
      increment_seconds: null,
      clock_type: null,
      gameStarted: false,
      moves: [],
      lastActivityTime: Date.now(),
      inactivityTimer: null,
      // Timer state (not used in quick match)
      redTimeRemaining: null,
      blackTimeRemaining: null,
      activePlayerColor: 'red',
      lastMoveTime: null
    });

    // Set room codes and player info for both clients
    const waitingClientObj = clients.get(waitingClient.clientId);
    if (waitingClientObj) {
      waitingClientObj.roomCode = room_code;
      waitingClientObj.playerName = waitingClient.playerName;
      waitingClientObj.playerColor = 'Red'; // Host is Red
    }

    client.roomCode = room_code;
    client.playerName = player_name;
    client.playerColor = 'Black'; // Guest is Black

    // Notify both players that match is found
    send(waitingClient.ws, {
      type: 'quick_match_found',
      room_code: room_code,
      timestamp: Date.now()
    });

    send(client.ws, {
      type: 'quick_match_found',
      room_code: room_code,
      timestamp: Date.now()
    });

    // Start the game immediately
    startGame(room_code);
  } else {
    // No one waiting, add to queue
    queue.push({
      clientId: clientId,
      playerName: player_name,
      ws: client.ws
    });

    log(`⏳ ${player_name} added to ${variant} queue (${queue.length} waiting)`);

    // Notify client they're searching
    send(client.ws, {
      type: 'quick_match_searching',
      timestamp: Date.now()
    });
  }
}

/**
 * Handle cancel quick match
 */
function handleCancelQuickMatch(clientId) {
  const client = clients.get(clientId);
  if (!client) return;

  // Remove from all queues
  for (const [variant, queue] of quickMatchQueue.entries()) {
    const index = queue.findIndex(entry => entry.clientId === clientId);
    if (index !== -1) {
      queue.splice(index, 1);
      log(`❌ Client ${clientId} removed from ${variant} quick match queue`);
    }
  }
}

// Start server
server.listen(PORT, async () => {
  log(`🚀 Draughts Multiplayer Server v${SERVER_VERSION} running on port ${PORT}`);
  log(`📡 WebSocket endpoint: ws://localhost:${PORT}`);
  log(`🏥 Health check: http://localhost:${PORT}/health`);

  // Load all-time stats from database
  await loadServerStats();
});

// Graceful shutdown - close client sockets and the HTTP server, then exit.
let shuttingDown = false;
function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  log(`${signal} received: shutting down gracefully`);

  // Notify and close all connected clients
  for (const ws of wss.clients) {
    try {
      send(ws, { type: 'server_shutdown', timestamp: Date.now() });
      ws.close(1001, 'Server shutting down');
    } catch (err) {
      logError('Error closing client during shutdown:', err);
    }
  }

  server.close(() => {
    log('HTTP server closed - exiting');
    process.exit(0);
  });

  // Force exit if connections don't drain in time
  setTimeout(() => {
    logError('Shutdown timed out - forcing exit');
    process.exit(1);
  }, 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Last-resort safety nets so one bad message can't silently wedge the server
process.on('unhandledRejection', (reason) => {
  logError('Unhandled promise rejection:', reason);
});
process.on('uncaughtException', (err) => {
  logError('Uncaught exception:', err);
});
