'use strict';

const mongoose = require('mongoose');

/**
 * Connects to MongoDB Atlas if a connection string is provided.
 *
 * Deliberately non-fatal when `uri` is missing: it lets the server (and its
 * real-time gameplay, which needs no database at all) start and be tested
 * before Atlas is set up, instead of crashing on boot.
 */
async function connectDatabase(uri) {
  if (!uri) {
    console.warn('MONGODB_URI not set -- starting without a database connection.');
    return;
  }

  mongoose.connection.on('error', (err) => {
    console.error('MongoDB connection error:', err.message);
  });

  await mongoose.connect(uri);
  console.log('Connected to MongoDB');
}

module.exports = { connectDatabase };
