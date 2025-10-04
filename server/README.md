# Draughts Multiplayer Server

A lightweight WebSocket relay server for real-time multiplayer draughts games.

## Features

- **Room-based matchmaking** - Players create or join 6-character room codes
- **Real-time move synchronization** - Moves are relayed instantly between players
- **Game state management** - Handles game start, moves, resignation, and draws
- **Connection resilience** - 60-second grace period for disconnections
- **Health monitoring** - Built-in health check endpoint

## Installation

```bash
cd server
npm install
```

## Usage

### Development
```bash
npm run dev
```

### Production
```bash
npm start
```

The server will start on port 8080 by default (configurable via `PORT` environment variable).

## API Endpoints

### WebSocket (ws://localhost:8080)

#### Client → Server Messages

**Create Room**
```json
{
  "type": "create_room",
  "variant": "American Checkers",
  "use_timer": false,
  "minutes_per_side": 5,
  "increment_seconds": 0,
  "clock_type": "Fischer",
  "player_name": "Player1"
}
```

**Join Room**
```json
{
  "type": "join_room",
  "room_code": "ABCD12",
  "player_name": "Player2"
}
```

**Make Move**
```json
{
  "type": "make_move",
  "move": {
    "piece_id": "piece_1",
    "from_row": 2,
    "from_col": 1,
    "to_row": 3,
    "to_col": 2,
    "is_capture": false,
    "promoted": false,
    "captured_pieces": []
  }
}
```

**Resign**
```json
{
  "type": "resign"
}
```

**Offer Draw**
```json
{
  "type": "offer_draw"
}
```

**Ping**
```json
{
  "type": "ping",
  "timestamp": 1234567890
}
```

#### Server → Client Messages

**Room Created**
```json
{
  "type": "room_created",
  "room_code": "ABCD12",
  "player_color": "Red",
  "timestamp": 1234567890
}
```

**Opponent Joined**
```json
{
  "type": "opponent_joined",
  "opponent_name": "Player2",
  "timestamp": 1234567890
}
```

**Game Started**
```json
{
  "type": "game_started",
  "your_color": "Red",
  "variant": "American Checkers",
  "opponent_name": "Player2",
  "timestamp": 1234567890
}
```

**Move Made**
```json
{
  "type": "move_made",
  "move": { /* move object */ },
  "timestamp": 1234567890
}
```

**Game Ended**
```json
{
  "type": "game_ended",
  "result": "red_wins",
  "reason": "resignation",
  "timestamp": 1234567890
}
```

**Error**
```json
{
  "type": "error",
  "error_code": "ROOM_NOT_FOUND",
  "error_description": "Room ABCD12 not found",
  "timestamp": 1234567890
}
```

### HTTP Health Check (http://localhost:8080/health)

```json
{
  "status": "ok",
  "rooms": 5,
  "clients": 10,
  "uptime": 3600
}
```

## Deployment

### Docker

```bash
docker build -t draughts-server .
docker run -p 8080:8080 draughts-server
```

### Cloud Platforms

The server can be deployed to:
- **Heroku**: `heroku create && git push heroku main`
- **Railway**: Connect GitHub repo and deploy
- **Render**: Connect GitHub repo and deploy
- **DigitalOcean App Platform**: Connect GitHub repo and deploy

### Environment Variables

- `PORT` - Server port (default: 8080)
- `NODE_ENV` - Environment (development/production)

## Architecture

```
┌─────────────┐         ┌─────────────┐
│  Client 1   │◄───────►│   Server    │
│  (Host)     │         │             │
└─────────────┘         │   Rooms:    │
                        │   - ABCD12  │
┌─────────────┐         │   - XYZ789  │
│  Client 2   │◄───────►│   ...       │
│  (Guest)    │         └─────────────┘
└─────────────┘
```

## License

GPL-3.0+ - Same as Draughts application
