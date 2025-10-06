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
const REQUIRED_VERSION = '2.0.1'; // Minimum client version required
const GAME_INACTIVITY_TIMEOUT = 30 * 60 * 1000; // 30 minutes of inactivity
const DISCONNECT_TIMEOUT = 60 * 1000; // 60 seconds to reconnect

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
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <script>
    // Auto-refresh every 30 seconds (increased to let charts render)
    setTimeout(() => location.reload(), 30000);
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
        <div class="stat-label">Connections (Session)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.totalConnectionsAllTime.toLocaleString()}</div>
        <div class="stat-label">Connections (All-Time)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.peakConcurrentGames}</div>
        <div class="stat-label">Peak Games (Session)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">${stats.peakConcurrentGamesAllTime}</div>
        <div class="stat-label">Peak Games (All-Time)</div>
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

    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(500px, 1fr)); gap: 20px; margin-bottom: 20px;">
      <div class="chart-card">
        <h2>Games by Variant</h2>
        ${totalGames > 0 ? '<canvas id="variantChart" style="max-height: 300px;"></canvas>' : '<p style="text-align: center; color: #999;">No games played yet</p>'}
      </div>

      <div class="chart-card">
        <h2>Game Results Distribution</h2>
        ${totalGames > 0 ? '<canvas id="resultsChart" style="max-height: 300px;"></canvas>' : '<p style="text-align: center; color: #999;">No games played yet</p>'}
      </div>
    </div>

    <div class="chart-card">
      <h2>Win Rate Comparison</h2>
      ${totalGames > 0 ? '<canvas id="winRateChart" style="max-height: 250px;"></canvas>' : '<p style="text-align: center; color: #999;">No games played yet</p>'}
    </div>

    <div class="chart-card">
      <h2>Connection Statistics</h2>
      <canvas id="connectionChart" style="max-height: 250px;"></canvas>
    </div>

    <div class="footer">
      <p>Server Version 2.0.0 | Auto-refreshes every 30 seconds</p>
    </div>
  </div>

  <script>
    // Prepare data
    const totalGames = ${totalGames};
    const redWins = ${supabaseStats ? (supabaseStats.red_wins || 0) : stats.gamesByResult.red_wins};
    const blackWins = ${supabaseStats ? (supabaseStats.black_wins || 0) : stats.gamesByResult.black_wins};
    const draws = ${supabaseStats ? (supabaseStats.draws || 0) : stats.gamesByResult.draw};
    const resignations = ${supabaseStats ? (supabaseStats.resignations || 0) : stats.gamesByResult.resignation};
    const timeouts = ${supabaseStats ? (supabaseStats.timeouts || 0) : (stats.gamesByResult.timeout || 0)};

    // Variant data
    const variantData = ${JSON.stringify(
      supabaseVariantStats && supabaseVariantStats.length > 0
        ? supabaseVariantStats.map(v => ({ variant: v.variant, count: v.game_count }))
        : Object.entries(stats.gamesByVariant).map(([variant, count]) => ({ variant, count }))
    )};

    // Chart.js default config
    Chart.defaults.font.family = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif';
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = true;

    // Color palette
    const colors = {
      purple: '#667eea',
      pink: '#764ba2',
      blue: '#3b82f6',
      green: '#10b981',
      yellow: '#f59e0b',
      red: '#ef4444',
      orange: '#f97316',
      teal: '#14b8a6',
      indigo: '#6366f1'
    };

    if (totalGames > 0) {
      // 1. Variant Distribution (Doughnut Chart)
      const variantCtx = document.getElementById('variantChart');
      if (variantCtx) {
        new Chart(variantCtx, {
          type: 'doughnut',
          data: {
            labels: variantData.map(v => v.variant),
            datasets: [{
              data: variantData.map(v => v.count),
              backgroundColor: [
                colors.purple,
                colors.blue,
                colors.green,
                colors.yellow,
                colors.red,
                colors.orange,
                colors.teal,
                colors.indigo
              ],
              borderWidth: 2,
              borderColor: '#fff'
            }]
          },
          options: {
            plugins: {
              legend: {
                position: 'bottom',
                labels: {
                  padding: 15,
                  font: { size: 12 }
                }
              },
              tooltip: {
                callbacks: {
                  label: function(context) {
                    const label = context.label || '';
                    const value = context.parsed;
                    const percentage = ((value / totalGames) * 100).toFixed(1);
                    return label + ': ' + value + ' (' + percentage + '%)';
                  }
                }
              }
            }
          }
        });
      }

      // 2. Game Results Distribution (Pie Chart)
      const resultsCtx = document.getElementById('resultsChart');
      if (resultsCtx) {
        new Chart(resultsCtx, {
          type: 'pie',
          data: {
            labels: ['Red Wins', 'Black Wins', 'Draws', 'Resignations', 'Timeouts'],
            datasets: [{
              data: [redWins, blackWins, draws, resignations, timeouts],
              backgroundColor: [
                colors.red,
                '#1f2937',
                colors.yellow,
                colors.orange,
                colors.purple
              ],
              borderWidth: 2,
              borderColor: '#fff'
            }]
          },
          options: {
            plugins: {
              legend: {
                position: 'bottom',
                labels: {
                  padding: 15,
                  font: { size: 12 }
                }
              },
              tooltip: {
                callbacks: {
                  label: function(context) {
                    const label = context.label || '';
                    const value = context.parsed;
                    const percentage = ((value / totalGames) * 100).toFixed(1);
                    return label + ': ' + value + ' (' + percentage + '%)';
                  }
                }
              }
            }
          }
        });
      }

      // 3. Win Rate Comparison (Horizontal Bar Chart)
      const winRateCtx = document.getElementById('winRateChart');
      if (winRateCtx) {
        const totalDecisiveGames = redWins + blackWins;
        const redWinRate = totalDecisiveGames > 0 ? ((redWins / totalDecisiveGames) * 100).toFixed(1) : 0;
        const blackWinRate = totalDecisiveGames > 0 ? ((blackWins / totalDecisiveGames) * 100).toFixed(1) : 0;

        new Chart(winRateCtx, {
          type: 'bar',
          data: {
            labels: ['Red Win Rate', 'Black Win Rate', 'Draw Rate'],
            datasets: [{
              label: 'Percentage',
              data: [
                redWinRate,
                blackWinRate,
                totalGames > 0 ? ((draws / totalGames) * 100).toFixed(1) : 0
              ],
              backgroundColor: [colors.red, '#1f2937', colors.yellow],
              borderColor: [colors.red, '#1f2937', colors.yellow],
              borderWidth: 2
            }]
          },
          options: {
            indexAxis: 'y',
            scales: {
              x: {
                beginAtZero: true,
                max: 100,
                ticks: {
                  callback: function(value) {
                    return value + '%';
                  }
                }
              }
            },
            plugins: {
              legend: {
                display: false
              },
              tooltip: {
                callbacks: {
                  label: function(context) {
                    return context.parsed.x + '%';
                  }
                }
              }
            }
          }
        });
      }
    }

    // 4. Connection Statistics (Bar Chart)
    const connectionCtx = document.getElementById('connectionChart');
    if (connectionCtx) {
      new Chart(connectionCtx, {
        type: 'bar',
        data: {
          labels: ['Session Connections', 'All-Time Connections', 'Session Peak Games', 'All-Time Peak Games'],
          datasets: [{
            label: 'Count',
            data: [
              ${stats.totalConnections},
              ${stats.totalConnectionsAllTime},
              ${stats.peakConcurrentGames},
              ${stats.peakConcurrentGamesAllTime}
            ],
            backgroundColor: [colors.blue, colors.purple, colors.green, colors.teal],
            borderColor: [colors.blue, colors.purple, colors.green, colors.teal],
            borderWidth: 2
          }]
        },
        options: {
          scales: {
            y: {
              beginAtZero: true
            }
          },
          plugins: {
            legend: {
              display: false
            }
          }
        }
      });
    }
  </script>
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

              // Include all moves in the GAME_STARTED message for proper state restoration
              const movesToRestore = room.moves ? room.moves.map(m => m.move) : [];

              // Prepare reconnection message with timer settings
              const reconnectMessage = {
                type: 'game_started',
                variant: room.variant,
                your_color: existingClient.playerColor,
                opponent_name: opponentName,
                room_code: existingClient.roomCode,
                moves: movesToRestore  // Include moves for restoration
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

              log(`🎮 Restored game session for ${clientId} - ${room.variant} as ${existingClient.playerColor} with ${movesToRestore.length} moves`);
            }
          }
        } else {
          // Session expired or invalid
          clientId = Math.random().toString(36).substring(7);
          log(`✅ Client connected (expired session): ${clientId}`);
          clients.set(clientId, { ws, roomCode: null, playerName: null, playerColor: null });
          send(ws, { type: 'connected', session_id: clientId });
        }
      } else {
        // New connection
        clientId = Math.random().toString(36).substring(7);
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

      // If not a reconnect message, handle it normally
      if (message.type !== 'reconnect') {
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
    inactivityTimer: null,
    // Timer state (server-tracked)
    redTimeRemaining: use_timer ? minutes_per_side * 60 * 1000 : null, // milliseconds
    blackTimeRemaining: use_timer ? minutes_per_side * 60 * 1000 : null,
    activePlayerColor: 'red', // Who's timer is running
    lastMoveTime: null // When the last move was made
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

  log(`🏠 Room created: ${roomCode} by ${player_name}`);
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

  // Reject moves from disconnected clients
  if (client.disconnected) {
    log(`⚠️  Rejected move from disconnected client: ${clientId}`);
    return;
  }

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
      room.redTimeRemaining -= timeElapsed;
      // Add increment if using Fischer clock
      if (room.clock_type === 'Fischer' && room.increment_seconds) {
        room.redTimeRemaining += room.increment_seconds * 1000;
      }
    } else {
      room.blackTimeRemaining -= timeElapsed;
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
  const { variant, player_name } = message;
  const client = clients.get(clientId);

  if (!client) return;

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
  log(`🚀 Draughts Multiplayer Server running on port ${PORT}`);
  log(`📡 WebSocket endpoint: ws://localhost:${PORT}`);
  log(`🏥 Health check: http://localhost:${PORT}/health`);

  // Load all-time stats from database
  await loadServerStats();
});

// Graceful shutdown
process.on('SIGTERM', () => {
  log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    log('HTTP server closed');
  });
});
