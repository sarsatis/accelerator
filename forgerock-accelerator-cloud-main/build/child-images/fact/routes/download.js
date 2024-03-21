var express = require('express');
var router = express.Router();

// Require controller modules.
const controller_downloads = require("../controllers/download");

router.get("/", function (req, res) {
  res.redirect("/");
});

router.get('/:fileToDownload', controller_downloads.downloadArchive);

module.exports = router;
