# LAN Server Setup Guide

This guide enables multi-user access from other devices on the internal network
with shared data, authentication, and safe concurrent updates.

## 1) Server machine

Run the API on the machine that hosts the shared database file.

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_server.ps1 `
  -Host 0.0.0.0 `
  -Port 8080 `
  -Device windows `
  -DbPath "D:\RailwayServerData\secretariat.db" `
  -StorageRoot "\\SERVER\secretariat_data"
```

Notes:
- `SECRETARIAT_DB_PATH` is used to preserve existing records in one central DB.
- `SECRETARIAT_STORAGE_ROOT` is optional but recommended for shared attachments.
- `0.0.0.0` allows access from any internal device.

Production option (Windows server):

```powershell
flutter build windows --release -t lib/server_main.dart
```

Then run the produced EXE from:
`build\windows\x64\runner\Release\`

## 2) Open firewall on the server

```powershell
New-NetFirewallRule `
  -DisplayName "Railway Secretariat API 8080" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 8080
```

## 3) Client machines

Start each client with server base URL:

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_client_remote.ps1 `
  -ApiBaseUrl "http://192.168.1.10:8080"
```

Or manually:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

## 4) Authentication and permissions

- All routes require login token except:
  - `POST /api/auth/login`
  - `GET /api/health`
- API now enforces role/permission checks for:
  - users management
  - warid/sadir operations
  - import/OCR templates
  - database reset (admin only)
  - attachment upload/download

## 4.1) Automatic attachments over API

Attachments are now synchronized automatically through the API:

- `POST /api/attachments/upload`
- `POST /api/attachments/download`

This means:

- Mobile and desktop users can open the same attachment without manual ZIP transfer.
- Clients upload selected/scanned files directly to the server storage.
- Clients download files on demand when opening attachments.
- `SECRETARIAT_STORAGE_ROOT` is still recommended on the server to keep attachment files in a stable location.

## 5) Concurrency behavior

The system uses two protections for simultaneous access:

- SQLite busy retry on write operations.
- Optimistic concurrency check using `updated_at`.

If two users edit the same record at the same time, the second stale update is
rejected with HTTP `409 Conflict`, and the client should refresh then retry.

## 6) Health check

```powershell
Invoke-RestMethod -Method Get -Uri "http://192.168.1.10:8080/api/health"
```

Expected response contains:
- `status: ok`
- current server `time`
- `version` (app version)
- `uptime` (server uptime in seconds)

## 6.1) Additional API endpoints

### Single record by ID

- `GET /api/documents/warid/{id}` — fetch a single warid record
- `GET /api/documents/sadir/{id}` — fetch a single sadir record

### Audit log (admin only)

- `GET /api/audit-log?tableName=warid&recordId=123` — query audit trail

### Request body limits

The server rejects request bodies larger than 50 MB with HTTP 413.

## 7) Operational recommendation

- Keep regular backups of `secretariat.db`.
- Keep server and clients on the same app version to avoid schema mismatch.
- Configure `SECRETARIAT_STORAGE_ROOT` on the server machine so uploaded attachments
  are kept outside temporary build folders.
