# Multiplayer Quick Start Guide

Quick guide to get multiplayer working in 5 minutes!

## Prerequisites

- Node.js 18+ installed
- Vala compiler and GTK4 development libraries
- Two terminal windows or two computers on same network

## Step 1: Start the Server (Terminal 1)

```bash
cd /home/tobagin/Projects/Dama/server
npm install
npm start
```

You should see:
```
🎮 Draughts Multiplayer Server starting...
🚀 Draughts Multiplayer Server running on port 8080
📡 WebSocket endpoint: ws://localhost:8080
```

## Step 2: Build & Run First Client (Terminal 2)

```bash
cd /home/tobagin/Projects/Dama
./scripts/build.sh --dev
./build/src/draughts
```

## Step 3: Run Second Client (Terminal 3)

```bash
cd /home/tobagin/Projects/Dama
./build/src/draughts
```

## Step 4: Create a Game (Client 1)

1. Click menu button (☰) in top-right
2. Click **"Play Online"** (or press Ctrl+M)
3. Click **"Host Game"** button
4. Select your preferred variant (e.g., "American Checkers")
5. Optional: Enable timer and configure settings
6. Click **"Create Room"**
7. **Copy the room code** that appears (e.g., "ABCD12")

## Step 5: Join the Game (Client 2)

1. Click menu button (☰)
2. Click **"Play Online"** (or press Ctrl+M)
3. Click **"Join Game"** button
4. Enter the room code from Step 4
5. Click **"Join"**

## Step 6: Play!

- Both clients will automatically start the game
- Client 1 (Host) plays as **Red**
- Client 2 (Guest) plays as **Black**
- Make moves - they synchronize instantly!

---

## Troubleshooting

### Server won't start
```bash
# Check if port 8080 is in use
lsof -i :8080

# Kill process if needed
kill -9 <PID>
```

### Can't connect to server
- Ensure server is running in Terminal 1
- Check for error messages in server console
- Verify firewall allows port 8080

### Room code doesn't work
- Room codes are case-sensitive
- Ensure both clients are connected to same server
- Try creating a new room

---

## Testing Checklist

- [ ] Host can create room
- [ ] Guest can join with code
- [ ] Both players see game start
- [ ] Moves sync between clients
- [ ] Timer counts down (if enabled)
- [ ] Game ends correctly (checkmate/resignation)
- [ ] Disconnect shows warning
- [ ] Reconnect works within 60 seconds

---

## Server Logs

Watch server terminal for activity:
```
✅ Client connected: abc123
🏠 Room created: ABCD12 by Player1
🎮 Game started in room ABCD12: Player1 vs Player2
♟️  Move in room ABCD12
```

---

## Network Play on Different Machines

### Find your IP address
```bash
# Linux/Mac
hostname -I

# Windows
ipconfig
```

### On Server Machine
```bash
cd server
PORT=8080 npm start
```

### On Client Machines
1. Edit `src/dialogs/MultiplayerDialog.vala`
2. Change line:
   ```vala
   string server_url = "ws://SERVER_IP:8080";
   ```
3. Replace `SERVER_IP` with actual IP (e.g., `192.168.1.100`)
4. Rebuild application
5. Run and connect!

---

## Common Issues

### "Failed to connect to server"
**Solution:** Start server first, then clients

### "Room not found"
**Solution:** Create new room, old ones expire on disconnect

### Moves don't sync
**Solution:** Check both clients connected (green indicator in dialog)

### Game feels laggy
**Solution:** Check network latency (displayed in connection status)

---

## Advanced Usage

### Change Server Port
```bash
PORT=3000 npm start
```

### Server Health Check
```bash
curl http://localhost:8080/health
```

Output:
```json
{
  "status": "ok",
  "rooms": 1,
  "clients": 2,
  "uptime": 120
}
```

### Server Development Mode (auto-reload)
```bash
npm run dev
```

---

## What's Next?

After testing multiplayer locally:

1. **Deploy Server** to cloud (see [server/README.md](server/README.md))
2. **Share with friends** using deployed server URL
3. **Report bugs** on GitHub issues
4. **Contribute** improvements!

---

## Quick Reference

| Action | Shortcut |
|--------|----------|
| Open Multiplayer | `Ctrl+M` |
| New Game | `Ctrl+N` |
| Undo Move | `Ctrl+Z` (disabled in multiplayer) |
| Show History | `Ctrl+H` |
| Preferences | `Ctrl+,` |
| Help | `F1` |
| Quit | `Ctrl+Q` |

---

**Enjoy playing Draughts online! 🎮**
