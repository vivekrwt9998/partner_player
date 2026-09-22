'use strict';

// Convenience entry point for local testing before MongoDB Atlas is set
// up: spins up a throwaway, in-memory MongoDB (via `mongodb-memory-server`,
// a devDependency -- never used in production) and points the real server
// at it, so `/auth/*` works immediately with zero setup.
//
// Data here disappears when this process stops. Once you have a real
// MONGODB_URI (see .env.example / README.md), just use `npm run dev` or
// `npm start` instead -- this file is dev-only.

const { MongoMemoryServer } = require('mongodb-memory-server');

async function start() {
  const mongod = await MongoMemoryServer.create();
  process.env.MONGODB_URI = mongod.getUri();
  console.log('Using a temporary in-memory MongoDB for this run (data will not persist).');

  process.on('SIGINT', async () => {
    await mongod.stop();
    process.exit(0);
  });

  require('./src/server');
}

start().catch((err) => {
  console.error('Failed to start with the in-memory database:', err);
  process.exit(1);
});
