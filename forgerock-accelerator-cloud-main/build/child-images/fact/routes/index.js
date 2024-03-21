var express = require('express');
var router = express.Router();

router.get('/', function(req, res, next) {
  res.render('index', { title: 'Midships FACE' });
});

// router.get("/", function (req, res) {
//   res.redirect("/diff");
// });

module.exports = router;
