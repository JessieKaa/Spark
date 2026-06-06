# Spark - Web-based Remote Administration Tool

Fork of [XZB-1248/Spark](https://github.com/XZB-1248/Spark) — a cross-platform, web-based RAT built with Go + React.

## Tech Stack

- **Backend**: Go 1.18, Gin HTTP framework, gorilla/websocket, SQLite (mattn/go-sqlite3)
- **Frontend**: React 17, Ant Design 4, Webpack 5, xterm.js
- **Communication**: AES-CTR encrypted WebSocket between server and clients
- **Build tags**: `jsoniter` (server), `CGO` required (sqlite3)

## Project Structure

```
server/          # Go server — HTTP API + WebSocket hub
  main.go        # Entry point (Gin server, WS handshake)
  common/        # Encryption, session mgmt, device registry, event system
  config/        # Server config (flags + config.json)
  database/      # SQLite persistence for device records
  handler/       # API route handlers (bridge, desktop, file, generate, process, terminal, utility)
client/          # Go client — runs on managed devices
  client.go      # Decrypt embedded config, start core
  core/          # Reconnect loop, device info, command dispatch (20+ commands)
  service/       # Platform-specific implementations (desktop, file, process, screenshot, terminal)
web/             # React SPA frontend
  src/components/  # UI components (terminal, desktop, explorer, procmgr, generate, execute)
  src/locale/      # i18n (EN + ZH)
modules/         # Shared data structures (Packet, Device, CPU, etc.)
utils/           # Crypto (AES-CTR), UUID, time, concurrent map
utils/melody/    # Custom WebSocket hub library
scripts/         # Build scripts for client/server (sh + bat)
docs/            # Architecture, development, deployment, API docs
```

## Build & Run

### Prerequisites
- Go 1.18+, Node.js 16+, `statik` (`go install github.com/rakyll/statik@latest`)

### Full Build
```bash
# 1. Frontend
cd web && npm install && npm run build-prod && cd ..

# 2. Embed frontend into Go binary
statik -m -src="./web/dist" -f -dest="./server/embed" -p web -ns web

# 3. Client binaries (cross-platform, outputs to built/)
mkdir -p built && ./scripts/build.client.sh

# 4. Server binary (outputs to releases/)
mkdir -p releases && ./scripts/build.server.sh
```

### Run Server
```bash
# With config.json in working directory
./releases/server_linux_amd64

# Or with flags
./releases/server_linux_amd64 -listen :8080 -salt YOUR_SALT -username admin -password pass
```

### Docker
```bash
docker-compose up -d --build
```

### Frontend Dev Server
```bash
cd web && npm install && npm start  # webpack-dev-server on :8080
```

## Key Patterns

- **Build tags**: Server uses `-tags=jsoniter` for fast JSON serialization
- **ldflags**: Both server and client inject git commit via `-X 'Spark/{server,client}/config.Commit=$COMMIT'`
- **Client binary generation**: Server patches a pre-built client binary with encrypted config (server address, auth key) via the `/api/client/generate` endpoint
- **WebSocket protocol**: Server acts as bridge between browser (REST API) and client (WS). Event callback system maps requests to responses with timeouts
- **Encryption**: All client-server WS traffic uses AES-CTR with per-session 32-byte secrets. Large data (desktop frames, files) falls back to HTTP bridge
- **Cross-compilation**: Client supports linux/windows on arm/arm64/amd64/i386; server currently builds linux/amd64 only
- **No test suite**: Testing is manual — start server, generate client, test through browser

## Code Conventions

- Go module path is `Spark` (not a URL)
- Platform-specific code uses `_linux.go`, `_windows.go`, `_darwin.go` suffixes
- Client command handlers are registered in `client/core/handler.go` as a dispatch map
- Server API routes are registered in `server/handler/handler.go`
- Frontend uses Ant Design Pro components (ProLayout, ProTable, ProForm)
- i18n keys are in `web/src/locale/`
