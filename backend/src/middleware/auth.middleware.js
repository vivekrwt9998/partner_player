'use strict';

const mongoose = require('mongoose');
const { verifyToken } = require('../utils/jwt');
const User = require('../models/User');
const { refreshGuestExpiry } = require('../services/auth.service');

/** Rejects requests to routes that need the database before it's connected. */
function requireDatabase(_req, res, next) {
  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({
      error: 'DATABASE_UNAVAILABLE',
      message: 'Database is not connected yet.',
    });
  }
  next();
}

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'UNAUTHORIZED' });
  }

  try {
    const payload = verifyToken(token);
    const user = await User.findById(payload.sub);
    if (!user) {
      return res.status(401).json({ error: 'UNAUTHORIZED' });
    }

    req.user = user;
    // Fire-and-forget: this request shouldn't wait on it, and a failure
    // here just means the guest's expiry wasn't extended this one time.
    refreshGuestExpiry(user).catch((err) => {
      console.error('Failed to refresh guest expiry:', err.message);
    });
    next();
  } catch {
    return res.status(401).json({ error: 'UNAUTHORIZED' });
  }
}

module.exports = { requireDatabase, requireAuth };
