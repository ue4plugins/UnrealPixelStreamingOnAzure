const ApplicationInsightsLogger = (function () {
  let appInsights;
  let metricAggregatorList = {};

  const initialize = (instrumentationKey, appInsightsMetricFlushInterval) => {
    try {
      const ai = new Microsoft.ApplicationInsights.ApplicationInsights({
        config: {
          instrumentationKey: instrumentationKey
        },
      });
      appInsights = ai.loadAppInsights();
      setInterval(function () { metricFlusher() }, appInsightsMetricFlushInterval);
    } catch {
      console.error("Unable to initialize Application Insights instance.");
    }
  };

  const metricFlusher = () => { // this function is periodically called by an interval from the initialize
    logMetrics(metricAggregatorList);
    console.log('logged aggregated metrics to Application Insights');
    // reset the metric aggregator list
    metricAggregatorList = {};
    return;
  };

  const trace = (severityLevel, message, properties) => {
    if (!appInsights) {
      return;
    }

    try {
      appInsights.trackTrace({
        message: message,
        severityLevel: severityLevel,
        properties: properties,
      });
    } catch (ex) {
      console.error(ex);
    }
  };



  const metricsAggregator = (stats) => {
    // this function loops through all k:v pairs in a dict containing metrics and adds
    // it to the metricAggregatorList to be sent to AppInsights after logging.
    for (const [key, value] of Object.entries(stats)) {
      if (metricAggregatorList.hasOwnProperty(key)) {
        metricAggregatorList[key].push(value);
      } else {
        metricAggregatorList[key] = [value];
      };
    };
  };

  const logMetrics = (metricdictlist) => {
    if (!appInsights) {
      return;
    }
    // sends the count, avg, max and min of the aggregated metrics to appInsights metrics. 
    try {
      for (const [key, value] of Object.entries(metricdictlist)) {
        let sampleCount = value.length;
        let avg = value.reduce((a, b) => (a + b)) / sampleCount;
        let maxVal = Math.max.apply(Math, value);
        let minVal = Math.min.apply(Math, value);

        appInsights.trackMetric({
          name: key,
          average: avg,
          sampleCount: sampleCount,
          max: maxVal,
          min: minVal
        });
      };
    } catch (ex) {
      console.error(ex);
    };
  };

  const logInfo = (message, properties) => {
    trace(
      Microsoft.ApplicationInsights.Telemetry.SeverityLevel.Information,
      message,
      properties
    );
  };

  const logWarning = (message, properties) => {
    trace(
      Microsoft.ApplicationInsights.Telemetry.SeverityLevel.Warning,
      message,
      properties
    );
  };

  const logError = (message, properties) => {
    trace(
      Microsoft.ApplicationInsights.Telemetry.SeverityLevel.Error,
      message,
      properties
    );
  };

  const logException = (exception) => {
    if (!appInsights) {
      return;
    }

    try {
      appInsights.trackException({ exception: exception });
    } catch (ex) {
      console.error(ex);
    }
  };

  const logEvent = (name) => {
    if (!appInsights) {
      return;
    }

    try {
      appInsights.trackEvent({ name: name });
    } catch (ex) {
      console.error(ex);
    }
  };

  return {
    initialize,
    logInfo,
    logWarning,
    logError,
    logException,
    logEvent,
    logMetrics,
    metricsAggregator,
  };
});
