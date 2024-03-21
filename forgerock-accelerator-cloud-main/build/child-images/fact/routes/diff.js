var express = require('express');
var router = express.Router();

// Require controller modules.
const controller_diff = require("../controllers/diff");

// router.get('/', function(req, res, next) {
//   res.render('diff', { title: 'Midships FACE' });
// });

router.get('/', controller_diff.getDiffFiles);

module.exports = router;
