// Copyright Microsoft Corp. All Rights Reserved.

const express = require('express');
const storagelayer = require('./storagelayer.js');
const userAuthLayer = require('./userAuthLayer');

const app = express();
const http = require('http').Server(app);

var config;
var ai;

function initApiModule(configObj, aiObj) {
  config = configObj;
  ai = aiObj;

  // Required to access request body for POST requests
  app.use(express.json());
  app.use(
    express.urlencoded({
      extended: false,
    })
  );

  storagelayer.init(config.storageConnectionString);
  userAuthLayer.init(config.storageConnectionString);

  app.get('/api/settings/latestversion', async (req, res, next) => {
    var version = await storagelayer.GetLatestVersion();
    res.json({ version: version });
  });

  app.get('/api/settings/latest', async (req, res, next) => {
    var latest = await storagelayer.GetSettingsByVersion();
    res.json(latest);
  });

  if (config.enableAuthentication) {
    app.get('/api/authuser', async (req, res, next) => {
      var users = await userAuthLayer.ListUsers();
      res.json(users);
    });

    app.get('/api/authuser/:user', async (req, res, next) => {
      var user = await userAuthLayer.GetUser(req.params.user);
      res.json(user);
    });
  }

  http.listen(config.matchmakerInternalApiPort, () => {
    console.log(
      'Admin API HTTP listening on *:' + config.matchmakerInternalApiPort
    );
  });
}

module.exports = {
  init: initApiModule,
};
