var https = require("https");
var appInsightsAppId;
var appInsightsAppKey;
const appInsightsHost = "api.applicationinsights.io";

function Initialize(appId, appKey) {
  appInsightsAppId = appId;
  appInsightsAppKey = appKey;
}

async function GetEvents(
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
) {
  var path = `/v1/apps/${appInsightsAppId}/events/${eventType}?`;
  if (timespan) path += `timespan=${timespan}&`;
  if (filter) path += `$filter=${filter}&`;
  if (search) path += `$search=${search}&`;
  if (orderby) path += `$orderby=${orderby}&`;
  if (select) path += `$select=${select}&`;
  if (skip) path += `$skip=${skip}&`;
  if (top) path += `$top=${top}&`;
  if (format) path += `$format=${format}&`;
  if (count) path += `$count=${count}&`;
  if (apply) path += `$apply=${apply}&`;

  var optionsget = {
    host: appInsightsHost,
    path: path,
    method: "GET",
    headers: { "x-api-key": appInsightsAppKey },
  };
  var str = "";

  return new Promise(function (resolve, reject) {
    const callback = function (response) {
      response.on("data", function (chunk) {
        str += chunk;
      });

      response.on("end", function () {
        var message = JSON.parse(str);
        resolve(message);
      });
    };

    var req = https.request(optionsget, callback).end();
  });
}
async function GetMetrics(
  metricId,
  timespan,
  interval,
  aggregation,
  segment,
  top,
  orderby,
  filter
) {
  var path = `/v1/apps/${appInsightsAppId}/metrics/${metricId}?`;
  if (timespan) path += `timespan=${timespan}&`;
  if (interval) path += `interval=${interval}&`;
  if (aggregation) path += `aggregation=${aggregation}&`;
  if (segment) path += `segment=${segment}&`;
  if (top) path += `top=${top}&`;
  if (orderby) path += `orderby=${orderby}&`;
  if (filter) path += `filter=${filter}`;

  var optionsget = {
    host: appInsightsHost,
    path: path,
    method: "GET",
    headers: { "x-api-key": appInsightsAppKey },
  };
  var str = "";

  return new Promise(function (resolve, reject) {
    const callback = function (response) {
      response.on("data", function (chunk) {
        str += chunk;
      });

      response.on("end", function () {
        var message = JSON.parse(str);
        resolve(message);
      });
    };

    var req = https.request(optionsget, callback).end();
  });
}

async function GetData(query) {
  var path = `/v1/apps/${appInsightsAppId}/query?query=${encodeURIComponent(
    query
  )}`;
  var optionsget = {
    host: appInsightsHost,
    path: path,
    method: "GET",
    headers: { "x-api-key": appInsightsAppKey },
  };
  var str = "";

  return new Promise(function (resolve, reject) {
    var callback = function (response) {
      response.on("data", function (chunk) {
        str += chunk;
      });

      response.on("end", function () {
        var message = JSON.parse(str);
        resolve(message);
      });
    };

    var req = https.request(optionsget, callback).end();
  });
}

module.exports = {
  init: Initialize,
  GetEvents,
  GetMetrics,
  GetData,
};
