// Copyright Microsoft Corp. All Rights Reserved.

const express = require('express');
const appInsightsLayer = require('./appInsightsLayer.js');
const storagelayer = require('./storagelayer.js');
const userAuthLayer = require('./userAuthLayer.js');

function initApiModule(app, appInsightsSettings) {
    storagelayer.init(process.env.STORAGECONNECTIONSTRING);
    userAuthLayer.init(process.env.STORAGECONNECTIONSTRING);
    appInsightsLayer.init(
        appInsightsSettings.appInsightsApplicationId,
        appInsightsSettings.appInsightsApiKey
    );

    app.use(express.json());
    app.use(
        express.urlencoded({
            extended: false,
        })
    );

    app.get('/api/config', (_, res) => {
      res.json({
        enableAuthentication: process.env.ENABLEAUTHENTICATION === "true"
      });
    });

    app.delete('/api/authuser/:user', async (req, res, next) => {
      var user = await userAuthLayer.DeleteUser(req.params.user);
      res.json(user);
    });

    app.get('/api/authuser', async (req, res) => {
        var users = await userAuthLayer.ListUsers();
        res.json(users);
    });

    app.post('/api/authuser', async (req, res) => {
        var existingUser = await userAuthLayer.GetUser(req.body.username);
        if (existingUser) {
          res.sendStatus(422);
        } else {
          var user = await userAuthLayer.WriteUser(
            req.body.username,
            req.body.password
          );
          res.json(user);
        }
    });

    app.get('/api/settings/latestversion', async (req, res, next) => {
        var version = await storagelayer.GetLatestVersion();
        res.json({ version: version });
    });

    app.get('/api/settings/latest', async (req, res, next) => {
        var latest = await storagelayer.GetSettingsByVersion();
        res.json(latest);
    });

    app.get('/api/settings/:version', async (req, res, next) => {
        var settings = await storagelayer.GetSettingsByVersion(
            req.params.version
        );
        res.json(settings);
    });

    app.get('/api/settings', async (req, res, next) => {
        var settingsList = await storagelayer.GetSettingsList();
        res.json(settingsList);
    });

    app.post('/api/settings', async (req, res, next) => {
        var instancesPerNode = req.body.instancesPerNode;
        var resolutionWidth = req.body.resolutionWidth;
        var resolutionHeight = req.body.resolutionHeight;
        var fps = req.body.fps;
        var unrealApplicationDownloadUri =
            req.body.unrealApplicationDownloadUri;
        var enableAutoScale = req.body.enableAutoScale;
        var instanceCountBuffer = req.body.instanceCountBuffer;
        var percentBuffer = req.body.percentBuffer;
        var minMinutesBetweenScaledowns = req.body.minMinutesBetweenScaledowns;
        var scaleDownByAmount = req.body.scaleDownByAmount;
        var minInstanceCount = req.body.minInstanceCount;
        var maxInstanceCount = req.body.maxInstanceCount;
        var stunServerAddress = req.body.stunServerAddress;
        var turnServerAddress = req.body.turnServerAddress;
        var turnUsername = req.body.turnUsername;
        var turnPassword = req.body.turnPassword;

        if (
            !(
                instancesPerNode &&
                resolutionWidth &&
                resolutionHeight &&
                fps &&
                enableAutoScale &&
                instanceCountBuffer &&
                percentBuffer &&
                minMinutesBetweenScaledowns &&
                scaleDownByAmount &&
                minInstanceCount &&
                maxInstanceCount
            )
        ) {
            res.json({
                success: false,
                error: 'not all manditory fields are present',
            });
            return;
        } else if (
            isNaN(instancesPerNode) ||
            isNaN(resolutionWidth) ||
            isNaN(resolutionHeight) ||
            isNaN(fps) ||
            isNaN(instanceCountBuffer) ||
            isNaN(percentBuffer) ||
            isNaN(minMinutesBetweenScaledowns) ||
            isNaN(scaleDownByAmount) ||
            isNaN(minInstanceCount) ||
            isNaN(maxInstanceCount) ||
            typeof enableAutoScale != 'boolean'
        ) {
            res.json({ success: false, error: 'datatypes dont match' });
            return;
        }

        var version = await storagelayer.WriteNewSettings(
            instancesPerNode,
            resolutionWidth,
            resolutionHeight,
            fps,
            unrealApplicationDownloadUri,
            enableAutoScale,
            instanceCountBuffer,
            percentBuffer,
            minMinutesBetweenScaledowns,
            scaleDownByAmount,
            minInstanceCount,
            maxInstanceCount,
            stunServerAddress,
            turnServerAddress,
            turnUsername,
            turnPassword
        );
        res.json({ success: true, version: version });
    });

    app.get('/api/uploads', async (req, res, next) => {
        var blobs = await storagelayer.GetUploadContainerContents();
        res.json(blobs);
    });

    app.get('/api/insights/events/:eventType', async (req, res, next) => {
        var eventType = req.params.eventType;
        var timespan = req.query.timespan;
        var filter = req.query.$filter;
        var search = req.query.$search;
        var orderby = req.query.$orderby;
        var select = req.query.$select;
        var skip = req.query.$skip;
        var top = req.query.$top;
        var format = req.query.$format;
        var count = req.query.$count;
        var apply = req.query.$apply;

        var events = await appInsightsLayer.GetEvents(
            eventType,
            timespan,
            filter,
            search,
            orderby,
            select,
            skip,
            top,
            format,
            count,
            apply
        );
        res.json(events);
    });

    app.get('/api/insights/metrics', async (req, res, next) => {
        var metric = req.query.metric;
        var timespan = req.query.timespan;
        var interval = req.query.interval;
        var aggregation = req.query.aggregation;
        var segment = req.query.segment;
        var top = req.query.top;
        var orderby = req.query.orderby;
        var filter = req.query.filter;

        var metrics = await appInsightsLayer.GetMetrics(
            metric,
            timespan,
            interval,
            aggregation,
            segment,
            top,
            orderby,
            filter
        );
        res.json(metrics);
    });

    app.get('/api/insights/query', async (req, res, next) => {
        var query = req.query.query;
        var data = await appInsightsLayer.GetData(query);
        res.json(data);
    });
}

module.exports = {
    init: initApiModule,
};
