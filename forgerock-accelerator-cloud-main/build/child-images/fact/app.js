var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
const fs = require('fs');

if (process.env.NODE_ENV === "development" || process.env.NODE_ENV === "" || !('NODE_ENV' in process.env)){
  require('dotenv').config();
  console.log("** ENVIRONMENT VARS", process.env);
} else {
  console.log("NODE_ENV is '"+process.env.NODE_ENV+"'");
}

var router_index = require('./routes/index');
var router_diff = require('./routes/diff');
var router_download = require('./routes/download');
var router_amster = require('./routes/amster');

var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'pug');

app.use(logger("dev")); //log to console
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());

// Static folders
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, "node_modules/bootstrap/dist/")));

app.use('/', router_index);
app.use('/diff', router_diff);
app.use('/download', router_download);
app.use('/amster', router_amster);

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  //res.render('error');
  res.render('error', { error: err } );
});

module.exports = app;
