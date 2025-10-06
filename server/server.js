#!/usr/bin/env node

/**
 * Draughts Multiplayer WebSocket Server
 *
 * A lightweight relay server for real-time multiplayer draughts games.
 * Handles room creation, matchmaking, and move synchronization.
 */

const WebSocket = require('ws');
const http = require('http');
const { createClient } = require('@supabase/supabase-js');

const PORT = process.env.PORT || 8443;
const ROOM_CODE_LENGTH = 6;
const REQUIRED_VERSION = '2.0.0'; // Minimum client version required
const GAME_INACTIVITY_TIMEOUT = 30 * 60 * 1000; // 30 minutes of inactivity
const DISCONNECT_TIMEOUT = 60 * 1000; // 60 seconds to reconnect

// Initialize Supabase client (optional - gracefully degrades if not configured)
let supabase = null;
const ENABLE_SUPABASE = process.env.ENABLE_SUPABASE !== 'false';

if (ENABLE_SUPABASE && process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
  supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
  console.log('✅ Supabase connected - game history and stats will be persisted');
} else {
  console.log('⚠️  Supabase not configured - running in memory-only mode');
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
  totalConnections: 0,
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

// Room code generator
function generateRoomCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  // Ensure code is unique
  return rooms.has(code) ? generateRoomCode() : code;
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
      console.error('Failed to fetch stats from Supabase:', error.message);
      return null;
    }

    return data;
  } catch (err) {
    console.error('Exception fetching stats from Supabase:', err);
    return null;
  }
}

/**
 * Fetch variant stats from Supabase
 */
async function fetchSupabaseVariantStats() {
  if (!supabase) return null;

  try {
    const { data, error } = await supabase
      .from('variant_stats')
      .select('*')
      .order('game_count', { ascending: false });

    if (error) {
      console.error('Failed to fetch variant stats from Supabase:', error.message);
      return null;
    }

    return data;
  } catch (err) {
    console.error('Exception fetching variant stats from Supabase:', err);
    return null;
  }
}

// Generate stats dashboard HTML
async function generateStatsHTML() {
  const uptime = Math.floor((Date.now() - stats.startTime) / 1000);
  const days = Math.floor(uptime / 86400);
  const hours = Math.floor((uptime % 86400) / 3600);
  const minutes = Math.floor((uptime % 3600) / 60);
  const uptimeStr = `${days}d ${hours}h ${minutes}m`;

  // Fetch Supabase stats if available
  const supabaseStats = await fetchSupabaseStats();
  const supabaseVariantStats = await fetchSupabaseVariantStats();

  // Use Supabase stats if available, otherwise use in-memory stats
  const displayStats = supabaseStats || stats;
  const totalGames = supabaseStats ? (supabaseStats.total_games || 0) : stats.totalGames;

  // Generate variant rows
  let variantRows = '';
  if (supabaseVariantStats && supabaseVariantStats.length > 0) {
    variantRows = supabaseVariantStats.map(row => `
      <tr>
        <td>${row.variant}</td>
        <td>${row.game_count}</td>
        <td>${totalGames > 0 ? ((row.game_count / totalGames) * 100).toFixed(1) : 0}%</td>
      </tr>
    `).join('');
  } else {
    variantRows = Object.entries(stats.gamesByVariant)
      .sort((a, b) => b[1] - a[1])
      .map(([variant, count]) => `
        <tr>
          <td>${variant}</td>
          <td>${count}</td>
          <td>${stats.totalGames > 0 ? ((count / stats.totalGames) * 100).toFixed(1) : 0}%</td>
        </tr>
      `).join('');
  }

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Draughts Server Statistics</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: #333;
      padding: 20px;
      min-height: 100vh;
    }
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    h1 {
      color: white;
      text-align: center;
      margin-bottom: 30px;
      font-size: 2.5rem;
      text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
    }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }
    .stat-card {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      transition: transform 0.2s;
    }
    .stat-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 12px rgba(0,0,0,0.15);
    }
    .stat-value {
      font-size: 2.5rem;
      font-weight: bold;
      color: #667eea;
      margin-bottom: 5px;
    }
    .stat-label {
      color: #666;
      font-size: 0.9rem;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .chart-card {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
      margin-bottom: 20px;
    }
    h2 {
      color: #333;
      margin-bottom: 20px;
      font-size: 1.5rem;
    }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th, td {
      padding: 12px;
      text-align: left;
      border-bottom: 1px solid #eee;
    }
    th {
      background: #f8f9fa;
      color: #667eea;
      font-weight: 600;
    }
    tr:hover {
      background: #f8f9fa;
    }
    .info-banner {
      background: rgba(255, 255, 255, 0.95);
      color: #333;
      padding: 15px 25px;
      border-radius: 8px;
      margin-bottom: 20px;
      text-align: center;
      font-weight: 500;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .status-indicator {
      display: inline-block;
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #10b981;
      margin-right: 8px;
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    .footer {
      text-align: center;
      color: white;
      margin-top: 30px;
      opacity: 0.8;
    }
    .pie-chart {
      display: flex;
      justify-content: center;
      align-items: center;
      margin: 20px 0;
    }
  </style>
  <script>
    // Auto-refresh every 10 seconds
    setTimeout(() => location.reload(), 10000);
  </script>
</head>
<body>
  <div class="container">
    <h1><span class="status-indicator"></span>Draughts Multiplayer Server</h1>

    ${supabase ? '<div class="info-banner">📊 Stats powered by Supabase (all-time data)</div>' : '<div class="info-banner">⚠️ In-memory stats only (current session)</div>'}

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-value">${totalGames}</div>
        <div class="stat-label">Total Games</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.activeGames}</div>
        <div class="stat-label">Active Games</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${supabaseStats ? totalGames - stats.activeGames : stats.completedGames}</div>
        <div class="stat-label">Completed Games</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${clients.size}</div>
        <div class="stat-label">Connected Players</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.totalConnections}</div>
        <div class="stat-label">Total Connections (Session)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.peakConcurrentGames}</div>
        <div class="stat-label">Peak Games (Session)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${uptimeStr}</div>
        <div class="stat-label">Uptime</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${rooms.size}</div>
        <div class="stat-label">Active Rooms</div>
      </div>
    </div>

    <div class="chart-card">
      <h2>Games by Variant</h2>
      ${variantRows ? `
        <table>
          <thead>
            <tr>
              <th>Variant</th>
              <th>Games</th>
              <th>Percentage</th>
            </tr>
          </thead>
          <tbody>
            ${variantRows}
          </tbody>
        </table>
      ` : '<p style="text-align: center; color: #999;">No games played yet</p>'}
    </div>

    <div class="chart-card">
      <h2>Game Results</h2>
      <table>
        <thead>
          <tr>
            <th>Result</th>
            <th>Count</th>
            <th>Percentage</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Red Wins</td>
            <td>${supabaseStats ? (supabaseStats.red_wins || 0) : stats.gamesByResult.red_wins}</td>
            <td>${totalGames > 0 ? (((supabaseStats ? (supabaseStats.red_wins || 0) : stats.gamesByResult.red_wins) / totalGames) * 100).toFixed(1) : 0}%</td>
          </tr>
          <tr>
            <td>Black Wins</td>
            <td>${supabaseStats ? (supabaseStats.black_wins || 0) : stats.gamesByResult.black_wins}</td>
            <td>${totalGames > 0 ? (((supabaseStats ? (supabaseStats.black_wins || 0) : stats.gamesByResult.black_wins) / totalGames) * 100).toFixed(1) : 0}%</td>
          </tr>
          <tr>
            <td>Draws</td>
            <td>${supabaseStats ? (supabaseStats.draws || 0) : stats.gamesByResult.draw}</td>
            <td>${totalGames > 0 ? (((supabaseStats ? (supabaseStats.draws || 0) : stats.gamesByResult.draw) / totalGames) * 100).toFixed(1) : 0}%</td>
          </tr>
          <tr>
            <td>Resignations</td>
            <td>${supabaseStats ? (supabaseStats.resignations || 0) : stats.gamesByResult.resignation}</td>
            <td>${totalGames > 0 ? (((supabaseStats ? (supabaseStats.resignations || 0) : stats.gamesByResult.resignation) / totalGames) * 100).toFixed(1) : 0}%</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="footer">
      <p>Server Version 2.0.0 | Auto-refreshes every 10 seconds</p>
    </div>
  </div>
</body>
</html>
  `;
}

// Create HTTP server
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      rooms: rooms.size,
      clients: clients.size,
      uptime: process.uptime()
    }));
  } else if (req.url === '/stats') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    generateStatsHTML().then(html => res.end(html));
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

// Create WebSocket server
const wss = new WebSocket.Server({ server });

console.log(`🎮 Draughts Multiplayer Server starting...`);

wss.on('connection', (ws) => {
  let clientId = null;
  let isReconnecting = false;

  // Track total connections
  stats.totalConnections++;

  // Wait for initial message to get session ID
  const handleFirstMessage = (data) => {
    try {
      const message = JSON.parse(data.toString());
      console.log(`📨 First message received - Type: ${message.type}, Version: ${message.version || 'not provided'}`);

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
        console.log(`❌ Client rejected due to version mismatch: ${clientVersion} < ${REQUIRED_VERSION}`);
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
          existingClient.ws = ws;
          existingClient.disconnected = false;
          existingClient.disconnectTime = null;
          console.log(`🔄 Client reconnected: ${clientId}`);

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

              // Include all moves in the GAME_STARTED message for proper state restoration
              const movesToRestore = room.moves ? room.moves.map(m => m.move) : [];

              send(ws, {
                type: 'game_started',
                variant: room.variant,
                your_color: existingClient.playerColor,
                opponent_name: opponentName,
                room_code: existingClient.roomCode,
                moves: movesToRestore  // Include moves for restoration
              });

              console.log(`🎮 Restored game session for ${clientId} - ${room.variant} as ${existingClient.playerColor} with ${movesToRestore.length} moves`);
            }
          }
        } else {
          // Session expired or invalid
          clientId = Math.random().toString(36).substring(7);
          console.log(`✅ Client connected (expired session): ${clientId}`);
          clients.set(clientId, { ws, roomCode: null, playerName: null, playerColor: null });
          send(ws, { type: 'connected', session_id: clientId });
        }
      } else {
        // New connection
        clientId = Math.random().toString(36).substring(7);
        console.log(`✅ Client connected: ${clientId}`);
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
          console.error(`❌ Error parsing message from ${clientId}:`, error);
          sendError(ws, 'PARSE_ERROR', 'Invalid JSON');
        }
      });

      // If not a reconnect message, handle it normally
      if (message.type !== 'reconnect') {
        handleMessage(clientId, message);
      }

    } catch (error) {
      console.error(`❌ Error in initial connection:`, error);
      ws.close();
    }
  };

  ws.on('message', handleFirstMessage);

  ws.on('close', () => {
    if (clientId) {
      console.log(`❌ Client disconnected: ${clientId}`);
      handleDisconnect(clientId);
    }
  });

  ws.on('error', (error) => {
    if (clientId) {
      console.error(`❌ WebSocket error for ${clientId}:`, error);
    }
  });
});

/**
 * Handle incoming messages from clients
 */
function handleMessage(clientId, message) {
  const { type, timestamp } = message;
  const client = clients.get(clientId);

  console.log(`📨 Message from ${clientId}: ${type}`);

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
      console.warn(`⚠️  Unknown message type: ${type}`);
      sendError(client.ws, 'UNKNOWN_TYPE', `Unknown message type: ${type}`);
  }
}

/**
 * Handle room creation
 */
function handleCreateRoom(clientId, message) {
  const client = clients.get(clientId);
  const { variant, use_timer, minutes_per_side, increment_seconds, clock_type, player_name } = message;

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
    hostName: player_name || 'Host',
    guestName: null,
    gameStarted: false,
    moves: [],
    lastActivityTime: Date.now(),
    inactivityTimer: null
  });

  client.roomCode = roomCode;
  client.playerName = player_name;
  client.playerColor = playerColor;

  send(client.ws, {
    type: 'room_created',
    room_code: roomCode,
    player_color: playerColor,
    timestamp: Date.now()
  });

  console.log(`🏠 Room created: ${roomCode} by ${player_name}`);
}

/**
 * Handle joining a room
 */
function handleJoinRoom(clientId, message) {
  const client = clients.get(clientId);
  const { room_code, player_name } = message;

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
  room.guestName = player_name || 'Guest';
  client.roomCode = room_code;
  client.playerName = player_name;
  client.playerColor = 'Black'; // Guest is always Black

  // Notify host that opponent joined
  const hostClient = clients.get(room.host);
  if (hostClient) {
    send(hostClient.ws, {
      type: 'opponent_joined',
      opponent_name: player_name,
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
    console.error(`❌ Cannot start game: Room ${room_code} not found`);
    return;
  }

  if (room.gameStarted) {
    console.warn(`⚠️ Game already started in room ${room_code}`);
    return;
  }

  room.gameStarted = true;
  room.startedAt = Date.now();

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

  const hostClient = clients.get(room.host);
  const guestClient = clients.get(room.guest);

  if (!hostClient || !guestClient) {
    console.error(`❌ Cannot start game: Missing players in room ${room_code}`);
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

  console.log(`🎮 Game started in room ${room_code}: ${room.hostName} vs ${room.guestName}`);
}

/**
 * Handle move made
 */
function handleMove(clientId, message) {
  const client = clients.get(clientId);
  const room = rooms.get(client.roomCode);

  if (!room) {
    sendError(client.ws, 'NO_ROOM', 'Not in a room');
    return;
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

  // Forward move to opponent
  const opponentId = (clientId === room.host) ? room.guest : room.host;
  const opponentClient = clients.get(opponentId);

  if (opponentClient) {
    send(opponentClient.ws, {
      type: 'move_made',
      move: message.move,
      timestamp: Date.now()
    });
  }

  console.log(`♟️  Move in room ${client.roomCode}`);
}

/**
 * Handle resign
 */
function handleResign(clientId) {
  const client = clients.get(clientId);
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

  console.log(`🏳️  ${client.playerName} resigned in room ${client.roomCode}`);
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

  console.log(`🤝 Draw offered in room ${client.roomCode}`);
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

  console.log(`🤝 Draw accepted in room ${client.roomCode}`);
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

  console.log(`❌ Draw rejected in room ${client.roomCode}`);
}

/**
 * Handle game ended (natural end - checkmate, no moves, etc.)
 */
function handleGameEnded(clientId, message) {
  const client = clients.get(clientId);
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

  console.log(`🏁 Game ended in room ${client.roomCode}: ${result} (${reason})`);
  cleanupRoom(room.code);
}

/**
 * Handle ping
 */
function handlePing(clientId, timestamp) {
  const client = clients.get(clientId);
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
        console.log(`⏱️  Client session expired after ${DISCONNECT_TIMEOUT / 1000}s: ${clientId}`);
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
      console.error('❌ Failed to save game to Supabase:', error.message);
      return null;
    }

    console.log(`💾 Game saved to Supabase: ${room.code} (ID: ${data.id})`);

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
        console.error('❌ Failed to save moves to Supabase:', movesError.message);
      }
    }

    return data;
  } catch (err) {
    console.error('❌ Exception saving game to Supabase:', err);
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
  // Clear existing timer if any
  if (room.inactivityTimer) {
    clearTimeout(room.inactivityTimer);
  }

  // Set new timer
  room.inactivityTimer = setTimeout(() => {
    const timeSinceLastActivity = Date.now() - room.lastActivityTime;

    if (timeSinceLastActivity >= GAME_INACTIVITY_TIMEOUT) {
      console.log(`⏱️  Game in room ${room.code} timed out due to inactivity (${Math.floor(timeSinceLastActivity / 60000)} minutes)`);

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

    console.log(`🧹 Cleaning up room ${roomCode}`);
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
  const { variant, player_name } = message;
  const client = clients.get(clientId);

  if (!client) return;

  console.log(`🎲 Quick match request from ${player_name} for ${variant}`);

  // Check if someone is already waiting for this variant
  if (!quickMatchQueue.has(variant)) {
    quickMatchQueue.set(variant, []);
  }

  const queue = quickMatchQueue.get(variant);

  // First, remove this client from queue if they're already in it (prevent duplicates)
  const existingIndex = queue.findIndex(entry => entry.clientId === clientId);
  if (existingIndex !== -1) {
    queue.splice(existingIndex, 1);
    console.log(`🔄 Removed duplicate entry for ${player_name} from queue`);
  }

  if (queue.length > 0) {
    // Match found! Pair with first waiting player
    const waitingClient = queue.shift();

    // Prevent self-matching
    if (waitingClient.clientId === clientId) {
      console.log(`⚠️  Prevented self-match for ${player_name}`);
      // Put them back in queue
      queue.push({
        clientId: clientId,
        playerName: player_name,
        ws: client.ws
      });
      return;
    }

    console.log(`✅ Match found! ${waitingClient.playerName} vs ${player_name}`);

    // Create a room for them
    const room_code = generateRoomCode();
    rooms.set(room_code, {
      code: room_code,
      host: waitingClient.clientId,
      hostName: waitingClient.playerName,
      guest: clientId,
      guestName: player_name,
      variant: variant,
      gameStarted: false,
      moves: [],
      lastActivityTime: Date.now(),
      inactivityTimer: null
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

    console.log(`⏳ ${player_name} added to ${variant} queue (${queue.length} waiting)`);

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
      console.log(`❌ Client ${clientId} removed from ${variant} quick match queue`);
    }
  }
}

// Start server
server.listen(PORT, () => {
  console.log(`🚀 Draughts Multiplayer Server running on port ${PORT}`);
  console.log(`📡 WebSocket endpoint: ws://localhost:${PORT}`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});
