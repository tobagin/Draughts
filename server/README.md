# Draughts Multiplayer Server

WebSocket relay server for real-time multiplayer draughts games with optional Supabase integration for persistent game history and statistics.

## Features

- **Real-time gameplay**: WebSocket-based relay for instant move synchronization
- **Room-based matchmaking**: Create private rooms with 6-character codes
- **Quick match**: Automatic opponent matching by variant
- **Timer support**: Fischer and Delay clock modes
- **Game persistence**: Optional Supabase integration for game history
- **Statistics dashboard**: Live stats at `/stats` endpoint
- **Reconnection handling**: 60-second grace period for disconnected players
- **Inactivity timeout**: 30-minute automatic cleanup for abandoned games

## Quick Start

### Install Dependencies

```bash
npm install
```

### Running Without Supabase (Memory-Only Mode)

```bash
npm start
```

Server will run on port 8443 with in-memory state only.

### Running With Supabase (Recommended)

1. **Create Supabase Project**:
   - Go to [supabase.com](https://supabase.com)
   - Create a new project
   - Note your project URL and anon key

2. **Set Up Database**:
   - Open Supabase SQL Editor
   - Run the SQL from `supabase-schema.sql`
   - This creates tables, views, and triggers

3. **Configure Environment**:
   ```bash
   cp .env.example .env
   ```

   Edit `.env`:
   ```env
   PORT=8443
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ENABLE_SUPABASE=true
   ```

4. **Start Server**:
   ```bash
   npm start
   ```

## Docker Deployment

### Build Image

```bash
docker build -t draughts-server .
```

### Run Container

```bash
docker run -d \
  -p 8443:8443 \
  -e SUPABASE_URL=https://your-project.supabase.co \
  -e SUPABASE_ANON_KEY=your-anon-key \
  draughts-server
```

### Using Docker Compose

```bash
docker-compose up -d
```

Edit `docker-compose.yml` to add your Supabase credentials.

### Publish to Docker Hub

```bash
./scripts/publish-server.sh 2.0.0 your-dockerhub-username
```

## Endpoints

- **`/`**: Health check (returns JSON status)
- **`/health`**: Health check endpoint for Docker
- **`/stats`**: Live statistics dashboard (HTML)
- **WebSocket**: Main WebSocket server for game connections

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8443` | Server port |
| `SUPABASE_URL` | - | Supabase project URL |
| `SUPABASE_ANON_KEY` | - | Supabase anonymous key |
| `ENABLE_SUPABASE` | `true` | Enable/disable Supabase |
| `NODE_ENV` | `production` | Node environment |

### Constants (in server.js)

| Constant | Value | Description |
|----------|-------|-------------|
| `GAME_INACTIVITY_TIMEOUT` | 30 min | Cleanup abandoned games |
| `DISCONNECT_TIMEOUT` | 60 sec | Reconnection grace period |
| `REQUIRED_VERSION` | `2.0.0` | Minimum client version |

## Database Schema

### Tables

- **games**: Individual game records with metadata
- **moves**: Move-by-move history for replay
- **daily_stats**: Aggregated daily statistics

### Views

- **game_stats_summary**: Overall statistics
- **variant_stats**: Stats grouped by variant
- **recent_games**: Last 100 completed games

See `supabase-schema.sql` for full schema.

## Game Flow

1. **Connection**: Client connects via WebSocket
2. **Create/Join Room**: Host creates room, guest joins with code
3. **Game Start**: Server broadcasts game_started to both players
4. **Move Relay**: Moves forwarded between players in real-time
5. **Game End**: Result saved to Supabase (if configured)
6. **Cleanup**: Room cleaned up, stats updated

## Message Protocol

All messages are JSON with `type` and `timestamp` fields.

### Client → Server

- `create_room`: Create new room
- `join_room`: Join existing room
- `quick_match`: Find random opponent
- `make_move`: Send move
- `resign`: Resign from game
- `game_ended`: Notify game completion

### Server → Client

- `room_created`: Room created successfully
- `opponent_joined`: Opponent joined room
- `game_started`: Game begins (includes timer settings)
- `move_made`: Opponent's move
- `game_ended`: Game finished
- `opponent_disconnected`: Opponent connection lost
- `error`: Error message

## Statistics

The `/stats` dashboard shows:

- **Real-time**: Active games, connected players, current rooms
- **Historical** (with Supabase): Total games, win rates, variant popularity
- **Session**: Uptime, peak concurrent games, connections

## Development

### Development Mode

```bash
npm run dev
```

Uses nodemon for auto-restart on file changes.

### Testing

```bash
# Test connection
wscat -c ws://localhost:8443

# Test with SSL
wscat -c wss://draughts.tobagin.eu
```

## Production Deployment

1. **Set up Cloudflare** (recommended):
   - Add DNS record pointing to server IP
   - Enable WebSocket support
   - Configure SSL/TLS

2. **Deploy with Docker**:
   ```bash
   ./scripts/publish-server.sh 2.0.0
   docker pull tobagin/draughts-server:2.0.0
   docker-compose up -d
   ```

3. **Monitor**:
   - Check `/stats` for live statistics
   - Monitor Docker logs: `docker-compose logs -f`

## Troubleshooting

### "Supabase not configured"

Server will run in memory-only mode. Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` to enable persistence.

### "Version mismatch" errors

Client version must be >= `REQUIRED_VERSION` (2.0.0). Update clients or adjust `REQUIRED_VERSION` in server.js.

### WebSocket connection fails

- Check firewall allows port 8443
- Verify Cloudflare WebSocket support enabled
- Check SSL certificate if using wss://

## License

GPL-3.0+

## Author

Thiago Fernandes
