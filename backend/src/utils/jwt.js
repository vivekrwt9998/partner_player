'use strict';

const jwt = require('jsonwebtoken');

// Falls back to an insecure dev-only value so the server still runs before
// JWT_SECRET is configured, the same non-fatal-missing-config pattern as
// config/db.js. This fallback must never be relied on outside local dev.
const JWT_SECRET = process.env.JWT_SECRET || 'dev-only-insecure-secret-change-me';
const JWT_EXPIRES_IN = '30d';

function signToken(user) {
  return jwt.sign({ sub: user._id.toString(), isGuest: user.isGuest }, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN,
  });
}

function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

module.exports = { signToken, verifyToken };
