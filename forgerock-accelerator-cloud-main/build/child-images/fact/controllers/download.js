const asyncHandler = require("express-async-handler");
const fs = require('fs')

exports.downloadArchive = asyncHandler(async (req, res, next) => {
  const filename_diffArchive=req.params.fileToDownload;
  const path_diffArchive = "/tmp/"+filename_diffArchive;
  var err = {}, tmpStr="";
  console.log("-- File to download is '"+path_diffArchive+'"');
  if (fs.existsSync(path_diffArchive)) {
    console.log("-- Found file");
    res.download(path_diffArchive, filename_diffArchive, (error) => {
      if (error) {
        err = { stdout: error.name, stderr: error.cause, message: error.message }
        res.render('error', { error: err } );
      } else {
        console.log('-- Download completed');
        if (fs.existsSync(path_diffArchive)) { 
          fs.unlinkSync(path_diffArchive); 
          console.log('-- File deleted from server');
        }
        console.log(' ');
      }
    });
  } else {
    tmpStr="-- File '"+path_diffArchive+'" NOT Found!'
    console.log(tmpStr);
    err = { stdout: "", stderr: "File NOT Found", message: tmpStr }
    res.render('error', { error: err } );
  }
});