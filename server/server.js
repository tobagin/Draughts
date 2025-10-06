#!/usr/bin/env node

/**
 * Draughts Multiplayer WebSocket Server
 *
 * A lightweight relay server for real-time multiplayer draughts games.
 * Handles room creation, matchmaking, and move synchronization.
 */

const WebSocket = require('ws');
const http = require('http');

const PORT = process.env.PORT || 8123;
const ROOM_CODE_LENGTH = 6;
const REQUIRED_VERSION = '2.0.0'; // Minimum client version required

// Game rooms storage
const rooms = new Map();

// Client connections storage
const clients = new Map();

// Quick match queue (variant -> array of waiting clients)
const quickMatchQueue = new Map();

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
    moves: []
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

  const hostClient = clients.get(room.host);
  const guestClient = clients.get(room.guest);

  if (!hostClient || !guestClient) {
    console.error(`❌ Cannot start game: Missing players in room ${room_code}`);
    return;
  }

  // Send game_started to both players
  send(guestClient.ws, {
    type: 'game_started',
    your_color: 'Black',
    variant: room.variant,
    opponent_name: room.hostName,
    timestamp: Date.now()
  });

  send(hostClient.ws, {
    type: 'game_started',
    your_color: 'Red',
    variant: room.variant,
    opponent_name: room.guestName,
    timestamp: Date.now()
  });

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

          // After 60 seconds, if still disconnected, end game
          setTimeout(() => {
            const currentClient = clients.get(clientId);
            if (currentClient && currentClient.disconnected) {
              const winner = (clientId === room.host) ? 'black_wins' : 'red_wins';
              send(opponentClient.ws, {
                type: 'game_ended',
                result: winner,
                reason: 'opponent_timeout',
                timestamp: Date.now()
              });
              cleanupRoom(room.code);
              clients.delete(clientId); // Now fully remove client
            }
          }, 60000);
        }
      }
    }

    // Always give 60 seconds to reconnect, regardless of room state
    setTimeout(() => {
      const currentClient = clients.get(clientId);
      if (currentClient && currentClient.disconnected) {
        console.log(`⏱️  Client session expired after 60s: ${clientId}`);
        clients.delete(clientId);
      }
    }, 60000);
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
 * Clean up a room
 */
function cleanupRoom(roomCode) {
  const room = rooms.get(roomCode);
  if (room) {
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
      moves: []
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
