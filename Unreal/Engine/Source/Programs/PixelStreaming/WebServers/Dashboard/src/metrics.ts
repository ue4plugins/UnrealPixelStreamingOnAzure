import { ILineChartDataPoint } from "@fluentui/react-charting";
import { DefaultPalette } from "@fluentui/style-utilities";
import { each, map, reduce, sortBy, unionWith } from "lodash";
import { DateTime } from "luxon";
import { MetricResults } from "./api";

export interface MetricResponse {
  start: string;
  end: string;
  interval?: string;
  segments: MetricResponseSegment[];
}

interface MetricResponseSegment {
  start: string;
  end: string;
  segments: { [key: string]: any };
}

export const AGGREGATIONS = ["avg", "min", "max", "sum", "count", "unique"];
export const INTERVALS = ["PT30M", "PT1H", "PT3H", "PT1D"];
const REGION_KEY = "customDimensions/region";

export const metricTimespanOptions = [
  { key: "P30D", text: "Last 30 days" },
  { key: "P7D", text: "Last 7 days" },
  { key: "P3D", text: "Last 3 days" },
  { key: "PT24H", text: "Last 1 day" },
  { key: "PT12H", text: "Last 12 hours" },
  { key: "PT6H", text: "Last 6 hours" },
  { key: "PT1H", text: "Last hour" },
  { key: "PT30M", text: "Last 30 minutes" },
];

export const metricIntervals: { [timespan: string]: string } = {
  P30D: "PT12H",
  P7D: "PT6H",
  P3D: "PT1H",
  PT24H: "PT30M",
  PT12H: "PT5M",
  PT6H: "PT5M",
  PT1H: "PT1M",
  PT30M: "PT1M",
};

export const metricTimespans: { [timespan: string]: any } = {
  P30D: { unit: "days", value: 30 },
  P7D: { unit: "days", value: 7 },
  P3D: { unit: "days", value: 3 },
  PT24H: { unit: "days", value: 1 },
  PT12H: { unit: "hours", value: 12 },
  PT6H: { unit: "hours", value: 6 },
  PT1H: { unit: "hours", value: 1 },
  PT30M: { unit: "minutes", value: 30 }
};

export const metricIncrements: { [timespan: string]: any } = {
  P30D: { unit: "hours", increment: 12 },
  P7D: { unit: "hours", increment: 6 },
  P3D: { unit: "hours", increment: 1 },
  PT24H: { unit: "minutes", increment: 30 },
  PT12H: { unit: "minutes", increment: 5 },
  PT6H: { unit: "minutes", increment: 5 },
  PT1H: { unit: "minutes", increment: 1 },
  PT30M: { unit: "minutes", increment: 1 }
};

export const summaryMetricNames = [
  "TotalConnectedClients",
  "AvailableConnections",
  "TotalInstances",
  "TotalStreams"
];

const colors = [
  DefaultPalette.yellow,
  DefaultPalette.orange,
  DefaultPalette.red,
  DefaultPalette.purple,
  DefaultPalette.blue,
  DefaultPalette.teal,
  DefaultPalette.green,
];

export const getQueryTimespan = (timespan: string) => {
  const ts = timespan.toLowerCase();
  if (ts.startsWith("pt")) {
    return ts.substring(2);
  }

  return ts.substring(1);
}

export const getSummaryMetrics = (data: MetricResults, regions?: string[]) => {
  const summaryMetrics: { [metric: string]: number } = {};
  each(summaryMetricNames, (metric) => {
    const metricData = data[metric];
    if (regions && regions.length > 0) {
      summaryMetrics[metric] = 0;
      each(regions, (region) => {
        summaryMetrics[metric] += metricData[region] || 0;
      });
    } else {
      const total = reduce(
        metricData,
        (sum, value) => {
          return sum + value;
        },
        0
      );
      summaryMetrics[metric] = total;
    }
  });

  return summaryMetrics;
};

export const getAreaChartData = (
  response: MetricResponse,
  regions: string[],
  timeIntervals: DateTime[],
  metric: string,
  aggregation: string = "avg"
) => {
  if (response.segments.length === 0) {
    return [];
  }

  const initData = timeIntervals.map((ts) => ({
    x: new Date(ts.toISO()),
    y: 0,
  }));

  const data: { [region: string]: ILineChartDataPoint[] } = {};
  each(regions, (region) => {
    data[region] = response.segments.map((s) => ({
      x: new Date(s.start),
      y: 0,
    }));
  });

  each(response.segments, (tSegment, tIdx) => {
    each(tSegment.segments, (rSegment) => {
      const region = rSegment[REGION_KEY];
      if (data[region]) {
        data[region][tIdx].y = rSegment[metric][aggregation] || 0;
      }
    });
  });

  return map(data, (values, region) => {
    const sortedData = sortBy(
      unionWith(
        values,
        initData,
        (a, b) => (a.x as Date).getTime() === (b.x as Date).getTime()
      ),
      "x"
    );
    return {
      legend: region,
      data: sortedData,
    };
  }).map((point, idx) => ({ ...point, color: colors[idx] }));
};
