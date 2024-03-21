const asyncHandler = require("express-async-handler");
const dircompare = require('dir-compare');
const execSync = require('child_process').execSync;
const types = require('../src/types.js');
const fs = require('fs');
var multer = require('multer');
const feature = "amster";

exports.exportAppsAndPolicies = asyncHandler(async (req, res, next) => {
  const path_tmp = "/tmp"
  const amServerUrl = process.env.AM_SERVER_URL;
  const executionId = new Date().toISOString().replace(/-/g,'').replace(/_/g,'').replace(/T/g,'-').replace(/:/g,'').replace(/\./g,'-');//Math.floor(new Date().getTime() / 1000);
  const tarFilename = "app-policy-amster-export-"+executionId+".tar";
  const logFilename = "amster-export-"+executionId+".log";
  const path_amsterExportArchive = path_tmp + '/' + tarFilename;
  const path_amsterExportLog = path_tmp + '/' + logFilename;
  const path_currConfig = process.env.CONFIG_DIR+"/amster";
  const errStdouMsg_default = "Error in Amster Export Process";
  var err = {}, download = {}, logContent = "";

  if (!fs.existsSync(path_currConfig)) {
    tmpStr = "Path '"+ path_currConfig +"' NOT found.";
    err = { stdout: errStdouMsg_default, stderr: "Missing Folder!", message: tmpStr }
    res.render('error', { error: err, feature: feature } );
  } else {
    console.log('-- Bash execution starting ...');
    try {
      cmd='bash ./src/manage-amster.sh "'+types.amster.export+'" "'+amServerUrl+'" "'+path_currConfig+'" "'+path_amsterExportArchive+'" "'+path_amsterExportLog+'"';
      execSync(cmd);
      console.log('-- Bash execution completed successfully');
    } catch (error) {
      tmpStr="-- ERROR:executing bash export file";
      console.log(tmpStr);
      logContent = fs.readFileSync(path_amsterExportLog,'utf8');
      console.log(logContent);
      err = { stdout: errStdouMsg_default, 
        stderr: error.cause + ' *** ' +error.message + ' *** ' + logContent,
        message: tmpStr + ' ' + error.name 
      }
      res.render('error', { error: err, feature: feature } );
    }
    
    logContent = fs.readFileSync(path_amsterExportLog,'utf8');
    if (fs.existsSync(path_amsterExportArchive)) {
      download = {
        url: "/download/"+tarFilename,
        btnLabel: "Download Amster Export"
      }
      console.log("-- Found '"+path_amsterExportArchive+'"');
    } else {
      tmpStr="-- ERROR: File '"+path_amsterExportArchive+'" Not found';
      console.log(tmpStr);
      err = { stdout: errStdouMsg_default, stderr: "File NOT Found " + logContent, message: tmpStr }
      res.render('error', { error: err, feature: feature } );
    }
    console.log('-- Displaying results for '+path_amsterExportArchive+'');
    console.log(logContent);
    if (fs.existsSync(path_amsterExportLog)) { fs.unlinkSync(path_amsterExportLog); }
    await res.render('amster', { download: download, feature: feature });
    console.log(' ');
  }
});

exports.importAppsAndPolicies = asyncHandler(async (req, res, next) => {
  const path_tmp = "/tmp";
  const amServerUrl = process.env.AM_SERVER_URL;
  const executionId = new Date().toISOString().replace(/-/g,'').replace(/_/g,'').replace(/T/g,'-').replace(/:/g,'').replace(/\./g,'-');//Math.floor(new Date().getTime() / 1000);
  const logFilename = "amster-import-"+executionId+".log";
  const path_amsterExportLog = path_tmp + '/' + logFilename;
  const path_currConfig = process.env.CONFIG_DIR+"/amster";
  const errStdouMsg_default = "Error in Amster Import"
  var logContent="";
  var amsterStatus={
    files: 0,
    message:{
      error:"",
      success:""
    }
  };
  var tmpMsg = "";

  if (!fs.existsSync("/tmp/upload")) { fs.mkdirSync("/tmp/upload", {recursive: true}); }

  const storage = multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, "/tmp/upload");
    },
    filename: (req, file, cb) => {
      cb(null, file.originalname);
    }
  });
  
  // Create the multer instance
  var upload = multer({ storage:storage }).single('amsterArchive');
  upload(req, res, function(error){
    if(error)	{
      console.log('-- ERROR:Uploading File');
      console.log(error);
      var err = { stdout: "Error uploading file", 
        stderr: error.message + ' *** ' + error.cause,
        message: error.name 
      }
      res.render('error', { error: err, feature: feature } );
    } else {
      if(req.file){
        console.log('-- Below File uploaded successfully');
        console.log(req.file);
        console.log("");
        console.log('-- Bash execution starting ...');
        try {
          cmd='bash ./src/manage-amster.sh "'+types.amster.import+'" "'+amServerUrl+'" "'+path_currConfig+'" "'+req.file.path+'" "'+path_amsterExportLog+'"';
          execSync(cmd);
          console.log('-- Bash execution completed successfully');
        } catch (error) {
          tmpStr="-- ERROR:executing bash import file";
          console.log(tmpStr);
          if (fs.existsSync(path_amsterExportLog)) { 
            logContent = fs.readFileSync(path_amsterExportLog,'utf8');
            console.log(logContent);
          }
          err = { stdout: errStdouMsg_default, 
            stderr: error.cause + ' *** ' +error.message + ' *** ' + logContent,
            message: tmpStr + ' ' + error.name 
          }
          res.render('error', { error: err, feature: feature } );
        }
        if (fs.existsSync(path_amsterExportLog)) { 
          console.log('-- Displaying import results for '+req.file.path+'');
          logContent = fs.readFileSync(path_amsterExportLog,'utf8');
          console.log(logContent);
        }
        if (fs.existsSync(path_amsterExportLog)) { fs.unlinkSync(path_amsterExportLog); }
        amsterStatus.files=1;
        amsterStatus.message.success="Successfully imported '"+req.file.originalname+"'"
        console.log(' ');
        res.render('amster', { amsterStatus: amsterStatus, feature: feature });
      } else {
        tmpMsg='No file selected to upload';
        amsterStatus.message.error=tmpMsg;
        console.log('-- ' + tmpMsg);
        res.render('amster', { amsterStatus: amsterStatus, feature: feature });
      }  
    }  
  });
  
});