const express = require('express');
const router = express.Router();
const { getNations, getCities, getWards } = require('../controllers/location.controller');

router.get('/nations', getNations);
router.get('/cities', getCities);
router.get('/wards', getWards);

module.exports = router;
