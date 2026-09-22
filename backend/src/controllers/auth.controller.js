'use strict';

const authService = require('../services/auth.service');

function handleAuthError(res, err) {
  if (err instanceof authService.AuthError) {
    return res.status(400).json({ error: err.code, message: err.message });
  }
  console.error('Unexpected auth error:', err);
  return res.status(500).json({ error: 'INTERNAL_ERROR' });
}

async function signup(req, res) {
  try {
    const { name, emailOrPhone, country, password } = req.body || {};
    const { user, token } = await authService.signup({ name, emailOrPhone, country, password });
    res.status(201).json({ token, user: user.toPublicJSON() });
  } catch (err) {
    handleAuthError(res, err);
  }
}

async function login(req, res) {
  try {
    const { emailOrPhone, password } = req.body || {};
    const { user, token } = await authService.login({ emailOrPhone, password });
    res.json({ token, user: user.toPublicJSON() });
  } catch (err) {
    handleAuthError(res, err);
  }
}

async function guest(req, res) {
  try {
    const { name } = req.body || {};
    const { user, token } = await authService.continueAsGuest({ name });
    res.status(201).json({ token, user: user.toPublicJSON() });
  } catch (err) {
    handleAuthError(res, err);
  }
}

async function me(req, res) {
  res.json({ user: req.user.toPublicJSON() });
}

module.exports = { signup, login, guest, me };
