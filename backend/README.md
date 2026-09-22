# Partner Game Backend

Backend for the platform: Node.js + Express + Socket.IO + MongoDB (Atlas).
Covers accounts (login/signup/guest) and real-time online multiplayer
(shareable room codes -- no account needed to actually play a match yet).

## Run it locally

```bash
npm install
cp .env.example .env   # fill in MONGODB_URI + JWT_SECRET to enable accounts
npm run dev            # or: npm start
```

The server starts fine with no `.env` at all -- it just skips connecting to
MongoDB and logs a warning. Game rooms/moves work exactly the same either
way (gameplay never depends on the database), but everything under `/auth`
needs `MONGODB_URI` set, since it has nowhere to store accounts otherwise
(it responds `503 DATABASE_UNAVAILABLE` rather than crashing).

**Testing `/auth` before setting up Atlas:** run `npm run dev:local-db`
instead of `npm run dev`. It spins up a throwaway in-memory MongoDB
automatically, so signup/login/guest all work immediately with zero setup
-- data just doesn't survive a restart. Switch to a real `MONGODB_URI` (see
`.env.example`) once you're ready to keep accounts around.

**Testing from a real Android phone over USB:** the app's default backend
URL is `http://localhost:3000`, which the phone can't reach directly. Run
`adb reverse tcp:3000 tcp:3000` once per USB connection so the phone's
`localhost:3000` is forwarded to this machine's over the cable.

`GET /health` returns `{ status, uptime, timestamp }`. This is also the
endpoint a free-tier keep-alive pinger (UptimeRobot, cron-job.org, a
scheduled GitHub Action) should hit every 5-10 minutes once this is
deployed, so the host doesn't spin the service down after 15 minutes idle.

## What's here

```
src/
  server.js                  entry point: connects DB, starts HTTP + Socket.IO
  app.js                     Express app (/health, /auth)
  config/db.js               MongoDB connection (optional, non-fatal if unset)
  routes/auth.routes.js      POST /auth/signup, /login, /guest, GET /auth/me
  controllers/auth.controller.js   request/response glue for the routes above
  services/auth.service.js   the actual signup/login/guest business logic
  middleware/auth.middleware.js    verifies the session token; gates DB-dependent routes
  utils/jwt.js                sign/verify session tokens
  models/User.js              account schema (+ the guest TTL index, see below)
  game/fourInARow/           server-authoritative port of the Dart engine
  game/ticTacToe/            server-authoritative port of the Dart engine
  sockets/roomManager.js     in-memory rooms, room codes, reconnect grace period
  sockets/gameSocketHandlers.js   Socket.IO event handlers (see below)
  models/MatchHistory.js     one more persisted thing: how a finished match ended
```

Game rooms live only in server memory -- restarting the process drops any
in-progress matches. That's a deliberate tradeoff for now: it keeps this
first version simple (AGENTS.md §54, Do Not Over-Engineer), and accounts
aren't wired into gameplay yet anyway. Accounts themselves *are* persisted,
in MongoDB.

## Accounts (`/auth`)

No login is required to play (see Socket.IO events below) -- this is for
the login/signup/guest screens in the app.

| Route | Body | Response |
|---|---|---|
| `POST /auth/signup` | `{ name, emailOrPhone, country, password }` | `201 { token, user }` |
| `POST /auth/login` | `{ emailOrPhone, password }` | `200 { token, user }` |
| `POST /auth/guest` | `{ name? }` | `201 { token, user }` |
| `GET /auth/me` | -- (needs `Authorization: Bearer <token>`) | `200 { user }` |

`emailOrPhone` accepts either -- an `@` makes it treated as an email,
otherwise as a phone number (7-15 digits). `user` is never the password: it's
`{ id, name, email, phone, country, isGuest }`.

Errors come back as `{ error: 'CODE', message: 'human-readable string' }`
with a `400` (bad input, e.g. `WEAK_PASSWORD`, `ACCOUNT_EXISTS`), `401`
(bad/missing token), or `503` (`DATABASE_UNAVAILABLE`, no MongoDB
connected).

### Guest accounts expire automatically

A guest (`POST /auth/guest`) gets `expiresAt` set 10 days out
(`User.GUEST_TTL_DAYS` in `models/User.js`). Every authenticated request
they make pushes it forward another 10 days
(`services/auth.service.js#refreshGuestExpiry`), so an active guest never
expires -- only one that genuinely stops opening the app for 10 straight
days does. Deletion itself is a native MongoDB TTL index on `expiresAt`
(`expireAfterSeconds: 0`): no cron job, no code in this repo does the
deleting. Registered accounts never get `expiresAt` set, so they're never
touched by it.

## Socket.IO events

All client → server events accept an ack callback: `socket.emit(event, payload, (response) => ...)`.

| Event | Payload | Ack response |
|---|---|---|
| `room:create` | `{ gameId, displayName? }` | `{ ok, code, sessionToken, slot, state }` |
| `room:join` | `{ code, displayName? }` | `{ ok, code, sessionToken, slot, state }` |
| `room:rejoin` | `{ code, sessionToken }` | `{ ok, code, slot, state }` |
| `room:leave` | `{ code }` | -- |
| `game:move` | `{ code, sessionToken, move }` -- `move` is `{ col }` for Four in a Row, `{ row, col }` for Tic Tac Toe | `{ ok, error? }` |

`gameId` is `'four_in_a_row'` or `'tic_tac_toe'`.

Server → client broadcasts to everyone in the room:

- `room:state` -- a player joined
- `game:state` -- the full room/game state after any move
- `game:over` -- `{ status, winner }` once the match ends
- `opponent:disconnected` / `opponent:reconnected` / `opponent:left`

`sessionToken` is what lets a player rejoin the same seat after a dropped
connection (`room:rejoin`), since there's no login to identify them by.

## Deploying for free

Matches the earlier free-hosting plan for this project:

- **Server**: Render.com free web service (or similar). Free tier sleeps
  after 15 min idle; a keep-alive pinger hitting `/health` avoids that and
  still fits inside the 750 free hours/month.
- **Database**: MongoDB Atlas free M0 cluster. Set `MONGODB_URI` in the
  host's environment variables.
- Also set `JWT_SECRET` to a long random value on the host. It falls back
  to an insecure default so local dev works without it, but that fallback
  must never be used anywhere real.
