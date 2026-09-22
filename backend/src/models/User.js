'use strict';

const mongoose = require('mongoose');

// Guest accounts are deleted automatically by MongoDB itself via a TTL
// index on `expiresAt` -- no cron job needed. Every authenticated request
// from a guest pushes `expiresAt` forward again (see
// services/auth.service.js#refreshGuestExpiry), so an active guest never
// expires; only one that truly stops coming back for GUEST_TTL_DAYS gets
// cleaned up. Registered accounts never get `expiresAt` set, so the TTL
// index -- which skips documents missing the indexed field -- never
// touches them.
const GUEST_TTL_DAYS = 10;

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    // No `default: null` here deliberately: a sparse unique index only
    // excludes documents where the field is *absent*, not ones where it's
    // explicitly `null`. Mongoose would otherwise materialize `email: null`
    // on every guest/phone-only signup, and the second one would collide on
    // the unique index (see the E11000 this used to throw).
    email: { type: String, trim: true, lowercase: true },
    phone: { type: String, trim: true },
    country: { type: String, trim: true, default: null },
    passwordHash: { type: String, default: null },
    isGuest: { type: Boolean, required: true, default: false },
    expiresAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// `sparse` so many users can each have a null email/phone (guests, or
// someone who signed up with only the other contact method) without
// tripping the uniqueness constraint.
userSchema.index({ email: 1 }, { unique: true, sparse: true });
userSchema.index({ phone: 1 }, { unique: true, sparse: true });
userSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

userSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    name: this.name,
    email: this.email ?? null,
    phone: this.phone ?? null,
    country: this.country,
    isGuest: this.isGuest,
  };
};

const User = mongoose.model('User', userSchema);
User.GUEST_TTL_DAYS = GUEST_TTL_DAYS;

module.exports = User;
