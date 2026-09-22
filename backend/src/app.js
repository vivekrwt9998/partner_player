'use strict';

const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth.routes');

function createApp({ corsOrigin } = {}) {
  const app = express();

  app.use(cors({ origin: corsOrigin || '*' }));
  app.use(express.json());

  // Also doubles as the endpoint a free-tier keep-alive pinger (e.g.
  // UptimeRobot / cron-job.org) hits every few minutes so the host doesn't
  // spin the service down after 15 minutes of inactivity.
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', uptime: process.uptime(), timestamp: Date.now() });
  });

  app.use('/auth', authRoutes);

  app.use((_req, res) => {
    res.status(404).json({ error: 'NOT_FOUND' });
  });

  return app;
}

module.exports = { createApp };
