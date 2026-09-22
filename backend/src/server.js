'use strict';

require('dotenv').config();

const http = require('http');
const { Server } = require('socket.io');

const { createApp } = require('./app');
const { connectDatabase } = require('./config/db');
const { registerGameSocketHandlers } = require('./sockets/gameSocketHandlers');

const PORT = process.env.PORT || 3000;
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

async function start() {
  await connectDatabase(process.env.MONGODB_URI);

  const app = createApp({ corsOrigin: CORS_ORIGIN });
  const httpServer = http.createServer(app);
  const io = new Server(httpServer, {
    cors: { origin: CORS_ORIGIN },
  });

  io.on('connection', (socket) => {
    registerGameSocketHandlers(io, socket);
  });

  httpServer.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
  });
}

start().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
