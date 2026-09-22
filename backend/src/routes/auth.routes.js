'use strict';

const express = require('express');
const authController = require('../controllers/auth.controller');
const { requireAuth, requireDatabase } = require('../middleware/auth.middleware');

const router = express.Router();

router.use(requireDatabase);

router.post('/signup', authController.signup);
router.post('/login', authController.login);
router.post('/guest', authController.guest);
router.get('/me', requireAuth, authController.me);

module.exports = router;
