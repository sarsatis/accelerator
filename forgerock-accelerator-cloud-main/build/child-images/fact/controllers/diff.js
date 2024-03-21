const asyncHandler = require("express-async-handler");
const dircompare = require('dir-compare');
const execSync = require('child_process').execSync;
const fs = require('fs');
const types = require('../src/types.js');
const feature = "diff";

exports.getDiffFiles = asyncHandler(async (req, res, next) => {
  const path_tmp = "/tmp";
  const options = { compareContent: true };
  /* Multiple compare strategy can be used simultaneously - compareSize, compareContent, compareDate, compareSymlink.
     If one comparison fails for a pair of files, they are considered distinct.*/
  const diffQueryType = req.query.diffType;
  const executionId = new Date().toISOString().replace(/-/,'').replace(/T/,'-').replace(/:/,'').replace(/\./,'-');//Math.floor(new Date().getTime() / 1000);
  const path_backupConfig = process.env.FACT_HOME+"/base-config/services";
  const tarFilename = diffQueryType+"-"+executionId+".tar";
  const logFilename = "diff-"+executionId+".log";
  const path_diffJson = path_tmp+"/diffs-found-"+executionId+".json";
  const path_diffArchive = path_tmp+'/'+tarFilename;
  const path_diffLog = path_tmp+'/'+logFilename;
  var path_currConfig = process.env.CONFIG_DIR+'/services';
  var tarPathPrefixToRemove = path_currConfig;
  var tarPathPrefixToRemove_delete = process.env.FACT_HOME+'/base-config';
  var errStdouMsg_default = "Error in Diff Process", path_From="", path_To="";
  var err = {}, diffTarDownloadUrl, arrDiffFiles = [], diffFileDetails= {}, download={}, diffs={};
  var diffType = "", tmpStr="", diffFilePath = "", cmd="", diffPayloadStr="", logContent = "";

  try {
    console.log('-- Ignoring AMADMIN config changes ...');
    path_From=path_currConfig+'/realm/root/sunidentityrepositoryservice/1.0/globalconfig/default/users/amadmin.json';
    if (fs.existsSync(path_From)) {
      path_To=path_backupConfig+'/realm/root/sunidentityrepositoryservice/1.0/globalconfig/default/users/amadmin.json';
      fs.cpSync(path_From, path_To);
    }
    console.log('-- Ignoring Root Realm CORS changes ...');
    path_From=path_currConfig+'/realm/root/corsservice/1.0/globalconfig/default/configuration.json';
    if (fs.existsSync(path_From)) {
      path_To=path_backupConfig+'/realm/root/corsservice/1.0/globalconfig/default/configuration.json';
      fs.cpSync(path_From, path_To);
    }
  } catch (error) { 
    tmpStr = "Failure ignoring AMADMIN config files changes";
    console.log('-- ' + tmpStr);
    err = { stdout: "", stderr: error.message, message: tmpStr }
    res.render('error', { error: err, feature: feature } );
  }

  if (!fs.existsSync(path_backupConfig)) {
    console.log("-- Creating '"+path_backupConfig+"' ...");
    fs.mkdirSync(path_backupConfig, {recursive: true});
  }

  if (!fs.existsSync(path_currConfig) || !fs.existsSync(path_backupConfig)) {
    tmpStr = "Path '"+ path_currConfig +"' or '"+path_backupConfig +"' NOT found.";
    console.log('-- ' + tmpStr);
    err = { stdout: errStdouMsg_default, stderr: "Missing Folder!", message: tmpStr }
    res.render('error', { error: err, feature: feature } );
  } else {
    // Get Diff file(s) details
    const result = dircompare.compareSync(path_currConfig, path_backupConfig, options);
    console.log("-- Compairing '"+path_currConfig+"' to '"+path_backupConfig+"'");
    console.log('-- INFO: Statistics - equal entries: %s, distinct entries: %s, left only entries: %s, right only entries: %s, differences: %s, same: %s',
    result.equal, result.distinct, result.left, result.right, result.differences, result.same);
    result.diffSet.forEach((dif) => {
      var addDiff=true;
      if(dif.state !== "equal" && dif.type1 !== "directory"){
        //console.log('-- INFO: Diff [state: %s] : name1: %s, type1: %s, name2: %s, type2: %s', dif.state, dif.name1, dif.type1, dif.name2, dif.type2)
        if(dif.type2 == "missing") { diffType = "NEW" }
        else { diffType = "UPT" }
        diffFilePath = dif.path1+"/"+dif.name1;
        if(dif.type1 == "missing") { 
          diffType = "DEL"; 
          diffFilePath = dif.path2+"/"+dif.name2;
          tarPathPrefixToRemove = tarPathPrefixToRemove_delete
        }
        if((diffQueryType == types.diff.newAndAmended && (diffType == "NEW" || diffType == "UPT")) ||
          (diffQueryType == types.diff.new && diffType == "NEW") ||
          (diffQueryType == types.diff.amended && diffType == "UPT") ||
          (diffQueryType == types.diff.deleted && diffType == "DEL")){
          var resultUpdates = "";
          var path_tmp1 = "";
          var path_tmp2 = "";
          if((diffFilePath.includes('default/users/amadmin.json') == false) &&
             (diffFilePath.includes('globalconfig/default/com-sun-identity-servers') == false)) {
            diffFileDetails = {
              diffType: diffType,
              path: diffFilePath
            }
            if(diffType == "UPT") {
              try {
                /* Some .json file after update have newline at the end.
                   Below code is to ignore such file if that is the only change */
                var epocTime = Math.floor(new Date().getTime() / 1000)
                path_tmp1 = dif.path1+"/"+dif.name1+epocTime;
                fs.writeFileSync(path_tmp1, JSON.stringify(dif.path1+"/"+dif.name1))
                path_tmp2 = dif.path2+"/"+dif.name2+epocTime;
                fs.writeFileSync(path_tmp2, JSON.stringify(dif.path2+"/"+dif.name2))
                resultUpdates = dircompare.compareSync(path_tmp1, path_tmp2, options);
                if(resultUpdates.equal > 0){ addDiff=false }
                fs.unlinkSync(path_tmp1);
                fs.unlinkSync(path_tmp2);
              } catch (error) {
                console.log('-- ERROR:creating file. ' + error.message);
                err = { stdout: errStdouMsg_default, stderr: error.cause, message: error.name + ' ' +error.message }
                res.render('error', { error: err, feature: feature } );
              }
            }
            if(addDiff == true){
              arrDiffFiles.push(diffFileDetails);
            } else {
              console.log("-- Skipping '"+diffFilePath+"' as only diff is new line");
            }
          }
        }
      }
    });
    
    // Add diff file(s) to archive
    if(arrDiffFiles.length > 0){
      console.log('-- Diffs to be processed: '+arrDiffFiles.length);
      try {
        fs.writeFileSync(path_diffJson, JSON.stringify(arrDiffFiles))
      } catch (error) {
        console.log('-- ERROR:creating file. ' + error.message);
        err = { stdout: errStdouMsg_default, stderr: error.cause, message: error.name + ' ' +error.message }
        res.render('error', { error: err, feature: feature } );
      }
      if (fs.existsSync(path_diffArchive)) { fs.unlinkSync(path_diffArchive); }
      console.log('-- Bash (Export) execution starting ...');
      try {
        cmd='bash ./src/manage-diff.sh "export" "'+path_diffJson+'" "'+diffQueryType+'" "'+tarPathPrefixToRemove+'" "'+path_diffArchive+'" "'+path_diffLog+'"';
        execSync(cmd);
        console.log('-- Bash execution completed successfully');
      } catch (error) {
        tmpStr="-- ERROR:running shell script (Export). " + error.message;
        console.log(tmpStr);
        err = { stdout: errStdouMsg_default, stderr: error.cause + ' ' +error.message, message: tmpStr + ' ' + error.name }
        res.render('error', { error: err, feature: feature  } );
      }

      if (fs.existsSync(path_diffLog)) { logContent = fs.readFileSync(path_diffLog,'utf8'); }
      
      if (fs.existsSync(path_diffArchive)) {
        download = {
          url: "/download/"+tarFilename,
          btnLabel: "Download Diff"
        }
        console.log("-- Found '"+download.url+'"');
      } else {
        tmpStr="-- ERROR: File '"+path_diffArchive+'" missing';
        console.log(tmpStr);
        err = { stdout: errStdouMsg_default, stderr: "File NOT Found " + logContent, message: tmpStr }
        res.render('error', { error: err, feature: feature } );
      }
    }
    console.log('-- Displaying results for '+arrDiffFiles.length+' entries');
    if (fs.existsSync(path_diffLog)) { console.log(logContent); fs.unlinkSync(path_diffLog); }

    // Cleaning up Diff info to display on page
    diffPayloadStr = JSON.stringify(arrDiffFiles).replaceAll(tarPathPrefixToRemove_delete,tarPathPrefixToRemove);
    await diffPayloadStr.replaceAll(tarPathPrefixToRemove, path_currConfig);
    diffs = {
      filesCount: arrDiffFiles.length,
      searchType: diffQueryType,
      data: JSON.parse(diffPayloadStr)
    }
    await res.render('diff', { diffs: diffs, download: download, feature: feature });
    console.log(' ');
  }
});