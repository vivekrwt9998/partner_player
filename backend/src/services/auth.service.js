'use strict';

const bcrypt = require('bcryptjs');
const User = require('../models/User');
const { signToken } = require('../utils/jwt');

const SALT_ROUNDS = 10;
const GUEST_TTL_MS = User.GUEST_TTL_DAYS * 24 * 60 * 60 * 1000;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_PATTERN = /^[0-9]{7,15}$/;

class AuthError extends Error {
  constructor(code, message) {
    super(message || code);
    this.code = code;
  }
}

function isEmailLike(value) {
  return value.includes('@');
}

function normalizeContact(emailOrPhone) {
  const value = (emailOrPhone || '').trim();
  if (!value) {
    throw new AuthError('CONTACT_REQUIRED', 'Email or phone number is required.');
  }

  if (isEmailLike(value)) {
    if (!EMAIL_PATTERN.test(value)) {
      throw new AuthError('INVALID_EMAIL', 'That email address does not look right.');
    }
    // `undefined`, not `null` -- see the comment on the schema's email/phone
    // fields for why that distinction matters to the sparse unique index.
    return { email: value.toLowerCase(), phone: undefined };
  }

  if (!PHONE_PATTERN.test(value)) {
    throw new AuthError('INVALID_PHONE', 'That phone number does not look right.');
  }
  return { email: undefined, phone: value };
}

async function signup({ name, emailOrPhone, country, password }) {
  if (!name || !name.trim()) {
    throw new AuthError('NAME_REQUIRED', 'Name is required.');
  }
  if (!password || password.length < 6) {
    throw new AuthError('WEAK_PASSWORD', 'Password must be at least 6 characters.');
  }

  const { email, phone } = normalizeContact(emailOrPhone);

  const existing = await User.findOne(email ? { email } : { phone });
  if (existing) {
    throw new AuthError('ACCOUNT_EXISTS', 'An account with that email/phone already exists.');
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await User.create({
    name: name.trim(),
    email,
    phone,
    country: (country || '').trim() || null,
    passwordHash,
    isGuest: false,
  });

  return { user, token: signToken(user) };
}

async function login({ emailOrPhone, password }) {
  if (!emailOrPhone || !password) {
    throw new AuthError('CREDENTIALS_REQUIRED', 'Email/phone and password are required.');
  }

  const { email, phone } = normalizeContact(emailOrPhone);
  const user = await User.findOne(email ? { email } : { phone });
  if (!user || !user.passwordHash) {
    throw new AuthError('INVALID_CREDENTIALS', 'Incorrect email/phone or password.');
  }

  const passwordMatches = await bcrypt.compare(password, user.passwordHash);
  if (!passwordMatches) {
    throw new AuthError('INVALID_CREDENTIALS', 'Incorrect email/phone or password.');
  }

  return { user, token: signToken(user) };
}

async function continueAsGuest({ name } = {}) {
  const user = await User.create({
    name: (name || '').trim() || 'Guest',
    isGuest: true,
    expiresAt: new Date(Date.now() + GUEST_TTL_MS),
  });

  return { user, token: signToken(user) };
}

/**
 * Keeps an active guest from expiring. Called on every authenticated
 * request (see middleware/auth.middleware.js); a no-op for registered
 * accounts, which never carry an `expiresAt` in the first place.
 */
async function refreshGuestExpiry(user) {
  if (!user.isGuest) return;
  user.expiresAt = new Date(Date.now() + GUEST_TTL_MS);
  await user.save();
}

module.exports = {
  AuthError,
  signup,
  login,
  continueAsGuest,
  refreshGuestExpiry,
  GUEST_TTL_MS,
};
