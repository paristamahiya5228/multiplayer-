# Together.js — Multiplayer Web in 10 Lines

> A single-file, zero-dependency client library and realtime Node.js server that turns any web page into a collaborative multiplayer experience. Includes shareable rooms, shared state synchronization (monotonic versioned Last-Write-Wins), live cursors, presence list, automatic reconnect with offline queuing, and built-in server security protections.

---

## ⚡ 10-Line Integration Snippet

Drop this into any HTML page to make it realtime multiplayer:

```html
<script src="/client/together.js"></script>
<script>
  // 1. Join room (reads ?room=... from URL automatically)
  const room = together.join(new URLSearchParams(location.search).get('room') || 'lobby');
  room.renderCursors(); // Automatic colored live cursors with name tags

  // 2. Listen to state changes & presence
  room.on('change', (key, val) => document.getElementById('count').textContent = val);
  room.on('presence', (users) => console.log('Active users:', users));

  // 3. Update shared state on user action
  document.getElementById('btn').onclick = () => {
    room.set('count', (room.get('count') || 0) + 1);
  };
</script>
```

---

## 📖 Full API Reference

The client library exposes a global `together` (or `multiplayer`) object:

```javascript
const room = together.join(roomId, options);
```

### Options (`options` object)
- `server`: WebSocket URL (e.g. `'ws://localhost:3000'`). Inferred automatically from `window.location` if omitted.
- `clientId`: Explicit unique client identifier. Inferred from `sessionStorage` per tab if omitted.
- `user`: Custom user profile object `{ name: string, color: string }`. Auto-generated if omitted.

---

### Methods

| Method | Parameters | Description |
| :--- | :--- | :--- |
| `room.set(key, value)` | `key: string`, `value: any` | Updates a state key. If online, broadcasts immediately. If offline, queues the write and sends upon reconnecting. |
| `room.get(key)` | `key: string` | Returns the current value of a state key, or `undefined` if unset. |
| `room.getState()` | *none* | Returns a plain object snapshot of all keys and values currently in the room. |
| `room.getVersions()` | *none* | Returns a plain object mapping each key to its server monotonic version. |
| `room.renderCursors()` | *none* | Automatically mounts a transparent DOM overlay drawing labeled, colored SVG cursors for other users. Returns an unmount function. |
| `room.disconnect()` | *none* | Manually closes the WebSocket connection (status becomes `'offline'`). |
| `room.reconnect()` | *none* | Re-opens connection, reconciles state with server, and flushes offline writes. |

---

### Events (`room.on(event, callback)`)

```javascript
// 1. State changes
room.on('change', (key, value) => {
  console.log(`Key "${key}" is now:`, value);
});

// 2. Presence list updates
room.on('presence', (users) => {
  // users: Array<{ clientId, name, color, isSelf }>
  console.log(`${users.length} users online`);
});

// 3. Live cursor coordinates
room.on('cursors', (cursors) => {
  // cursors: Object.<clientId, { x, y, name, color }> (x and y in viewport %)
});

// 4. Connection lifecycle
room.on('status', (status) => {
  // status: "connected" | "reconnecting" | "offline"
  console.log('Connection status:', status);
});
```

---

## 🏃 How to Run the Server Locally

### 1. Requirements
- Node.js (v16+)

### 2. Install dependencies & start
```bash
# Navigate to the project directory
cd multiplayer-lib

# Install server dependencies ('ws')
npm install

# Start the server (hosts WebSocket + static files on port 3000)
node server/server.js
```

### 3. Open Demo
Open your browser to:
```
http://localhost:3000
```
- Open multiple tabs or a private window side-by-side to test voting, live cursors, and presence.
- Toggle DevTools **Network -> Offline** to test auto-reconnect and offline queuing.

---

## 🧪 Consistency & Reconnection Tests

The project includes an end-to-end consistency test suite (`tests/sync.test.js`) that tests:
1. Connecting 3 simulated clients concurrently.
2. Concurrent `set()` calls to identical keys.
3. Network disconnection of a client during active writes.
4. Offline optimistic updates and queuing.
5. Reconnection and delta snapshot synchronization.
6. 100% convergence across all 3 client states and versions.
7. Server protection checks (10KB limit, invalid inputs).

Run the tests:
```bash
node tests/sync.test.js
```

Expected output:
```
======================================================
🎉 RESULT: ALL TESTS PASSED (PASS)
======================================================
```

---

## 🌐 How to Deploy

The server is a single Node.js process serving both the WebSocket gateway and static frontend files (`/demo` and `/client`).

### 1. Cloud Platforms (Render / Railway / Fly.io / Heroku)
1. Push this repository to GitHub.
2. Create a new **Web Service** on [Render](https://render.com) (or Railway / Fly.io).
3. If using Render, the included `render.yaml` configures the service automatically.
4. Set **Build Command**: `npm install`
5. Set **Start Command**: `node server/server.js`
6. The server automatically binds to `process.env.PORT` provided by the host.

### 2. Docker Deployment
A production-ready [Dockerfile](file:///C:/Users/paris/.gemini/antigravity-ide/scratch/multiplayer-lib/Dockerfile) is included:
```bash
# Build the container
docker build -t multiplayer-server .

# Run container on port 3000
docker run -d -p 3000:3000 --name multiplayer multiplayer-server
```

### 3. VPS (Ubuntu / Debian + NGINX)
Run the server with PM2:
```bash
npm install -g pm2
pm2 start server/server.js --name "multiplayer-server"
```

Configure NGINX reverse proxy with WebSocket upgrade support:
```nginx
server {
    listen 80;
    server_name multiplayer.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

---

## 🧠 How State Stays Consistent

The synchronization architecture is designed around three principles:

### 1. Versioned Last-Write-Wins (LWW)
- The server is the authority on monotonic versions for each room key.
- Whenever `set(key, value)` is executed, the server increments `version = (current.version || 0) + 1` and broadcasts `{ type: "update", key, value, version }` to everyone in the room.
- Clients update their local state only if `incoming.version >= local.version`, preventing network latency or out-of-order packets from reverting state.

### 2. Delta Snapshots on Reconnect
- When a client loses connection and reconnects, it sends its last confirmed server version for each key:
  `{ type: "join", room: "lobby", versions: { count: 4, poll_opt1: 2 } }`
- The server checks its in-memory room state and only sends keys where `server.version > client.version`.
- This minimizes bandwidth and reconciles missed updates instantly.

### 3. Offline Write Queue
- If a client calls `room.set()` while disconnected or reconnecting:
  - The local UI updates optimistically so user interactions are never blocked.
  - The write is pushed to an internal `_offlineQueue`.
- When connection is restored and the server's snapshot delta is applied, the queued writes are immediately flushed to the server.
- The server sequences the writes, increments versions, and broadcasts the updates so all peers converge.

---

## 🛡️ Server-Side Protections & Security

The server includes defenses against resource exhaustion and abuse:

1. **Message Size Limit (10KB)**: Messages exceeding 10,240 bytes are rejected immediately with `MESSAGE_TOO_LARGE` without parsing.
2. **Key Limit per Room (100 Keys)**: Prevents denial-of-service memory exhaustion. Once a room reaches 100 unique keys, attempts to create new keys are rejected with `KEY_LIMIT_EXCEEDED` (updates to existing keys remain allowed).
3. **Rate Limiting (30 msgs/sec)**: Each client is rate-limited to 30 messages per second. Flooding beyond 50 messages/sec triggers immediate disconnection.
4. **Field & Type Validation**: Strict validation ensures `key` (max 120 chars), `room` (max 100 chars), `clientId` (max 100 chars), and coordinate ranges `(0-100)` are strictly enforced.
5. **Crash Isolation**: All message handlers and JSON deserialization routines are isolated in protective `try...catch` blocks to ensure malformed payloads never crash the server.

---

## ⚠️ Known Limitations

1. **In-Memory Volatility**: Room state is stored in Node.js process memory. Restarting the server resets rooms unless backed by an external store (e.g., Redis or SQLite).
2. **Key-Level Resolution**: State sync operates on distinct keys. Concurrent edits to the exact same key are resolved by Last-Write-Wins; collaborative rich-text or per-character conflict resolution requires CRDTs (e.g., Yjs).
3. **Single Process**: For multi-server horizontal scaling across multiple machines, a Redis pub/sub adapter is required to relay WebSocket broadcasts between server instances.
