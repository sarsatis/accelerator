var express = require('express');
var router = express.Router();

// Require controller modules.
const controller_amster = require("../controllers/amster");

router.get('/', function(req, res, next) {
  res.render('amster', { title: 'Midships FACE' });
});

router.get('/export', controller_amster.exportAppsAndPolicies);

router.post('/import', controller_amster.importAppsAndPolicies);

module.exports = router;
