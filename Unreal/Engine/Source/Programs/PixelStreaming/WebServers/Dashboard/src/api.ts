import axios from "axios";
import { each } from "lodash";
import { Account } from "./containers/Accounts";
import { Setting } from "./containers/Header";
import {
  getQueryTimespan,
  metricIntervals,
  MetricResponse,
  summaryMetricNames,
} from "./metrics";

export type Config = {
  enableAuthentication?: boolean;
};

export interface AADUser {
  name?: string;
  family_name?: string;
  given_name?: string;
  email?: string;
}

export type MetricResults = { [metric: string]: { [region: string]: number } };

export const getConfig = async () => {
  const response = await axios.get("/api/config");
  return response.data;
};

export const addAccount = async (account: Account) => {
  const response = await axios.post("/api/authuser", account);
  return response.data;
};

export const deleteAccount = async (account: Account) => {
  const response = await axios.delete(`/api/authuser/${account.username}`);
  return response.data;
};

export const updateAccount = async (account: Account) => {
  const response = await axios.post(
    `/api/authuser/${account.username}`,
    account
  );
  return response.data;
};

export const getAccounts = async () => {
  const response = await axios.get("/api/authuser");
  return response.data;
};

export const getSettings = async (latest: boolean = true) => {
  const uri = `/api/settings/${latest ? "latest" : ""}`;
  const response = await axios.get(uri);
  return response.data;
};

export const addSettings = async (settings: Setting) => {
  const response = await axios.post("/api/settings", settings);
  return response.data;
};

export const getBlobs = async () => {
  const uri = "/api/uploads";
  const response = await axios.get(uri);
  return response.data;
};

export const getUser = async (): Promise<AADUser> => {
  const uri = "/api/user";
  try {
    const response = await axios.get(uri);
    return response.data;
  } catch {
    return {};
  }
};

export const getMetrics = async (
  metric: string,
  interval?: string,
  timespan: string = "PT12H",
  aggregation: string = "avg"
) => {
  const mInterval = interval || metricIntervals[timespan];
  const baseUri = "api/insights/metrics";
  const params = {
    metric,
    timespan,
    interval: mInterval,
    aggregation,
    segment: "customDimensions/region",
  };
  const response = await axios.get(baseUri, { params });
  return response.data.value as MetricResponse;
};

export const getRegions = async () => {
  const query = `customMetrics
| where timestamp > ago(8d)
| where customDimensions != ""
| distinct tostring(customDimensions.region)`;
  const baseUri = "api/insights/query";
  const params = {
    query,
  };
  const response = await axios.get(baseUri, {
    params,
  });

  return response.data.tables[0].rows.map((r: any[]) => r[0] as string);
};

export const getStreamingMetrics = async () => {
  const inList = `"${summaryMetricNames.join('","')}"`;
  const query = `customMetrics
| where timestamp > ago(5m)
| where name in (${inList})
| project timestamp, region=tostring(customDimensions.region), name, value
| order by timestamp asc, region, name`;
  const baseUri = "api/insights/query";
  const params = {
    query,
  };
  const response = await axios.get(baseUri, {
    params,
  });

  const rows = response.data.tables[0].rows || [];
  const data: MetricResults = {};
  each(rows, (row) => {
    const region = row[1];
    const metric = row[2];
    const value = row[3];

    if (data[metric] === undefined) {
      data[metric] = { [region]: value };
    } else {
      data[metric][region] = value;
    }
  });

  return data;
};

export const getErrorCount = async () => {
  const query = `customMetrics
| where timestamp > ago(5m)
| where name == "Errors"
| summarize count() by name`;
  const baseUri = "api/insights/query";
  const params = {
    query,
  };
  const response = await axios.get(baseUri, {
    params,
  });

  const rows = response.data.tables[0].rows || [];

  if (rows.length === 0) {
    return 0;
  }

  return rows[0][1];
};

export const getErrors = async (timespan: string = "1d") => {
  const ts = getQueryTimespan(timespan);
  const query = `exceptions
| where timestamp > ago(${ts})
| project timestamp, type, severityLevel, region=customDimensions.region, message=details[0].message`;
  const baseUri = "api/insights/query";
  const params = {
    query,
  };
  const response = await axios.get(baseUri, {
    params,
  });

  return response.data.tables[0] || [];
};
