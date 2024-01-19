import {
  DefaultEffects,
  DetailsList,
  Dropdown,
  FontSizes,
  IDropdownOption,
  SelectionMode,
  Stack,
} from "@fluentui/react";
import { ILineChartPoints, LineChart } from "@fluentui/react-charting";
import { zipObject } from "lodash";
import { DateTime } from "luxon";
import { useEffect, useState } from "react";
import {
  getErrorCount,
  getErrors,
  getMetrics,
  getRegions,
  getStreamingMetrics,
} from "src/api";
import useInterval from "src/hooks/useInterval";
import {
  getAreaChartData,
  getSummaryMetrics,
  metricIncrements,
  metricIntervals,
  metricTimespanOptions,
  metricTimespans,
  summaryMetricNames,
} from "src/metrics";
import { getTimeIntervals } from "src/util";

const errorColumns = [
  { key: "timestamp", name: "Timestamp", fieldName: "timestamp", minWidth: 100, maxWidth: 160, isResizable: true },
  { key: "type", name: "Type", fieldName: "type", minWidth: 80, maxWidth: 100, isResizable: true },
  { key: "severityLevel", name: "Severity", fieldName: "severityLevel", minWidth: 60, maxWidth: 80, isResizable: true },
  { key: "region", name: "Region", fieldName: "region", minWidth: 100, maxWidth: 140, isResizable: true },
  { key: "message", name: "Message", fieldName: "message", minWidth: 100, isResizable: true, isMultiline: true }
];

const Home = () => {
  const [regions, setRegions] = useState<string[]>([]);
  const [regionOptions, setRegionOptions] = useState<IDropdownOption[]>([]);
  const [selectedRegions, setSelectedRegions] = useState<string[]>([]);
  const [selectedTimespan, setSelectedTimespan] = useState<any>(metricTimespanOptions[3]);
  const [summaryMetrics, setSummaryMetrics] = useState<{
    [metric: string]: number;
  }>({});
  const [errorCount, setErrorCount] = useState(0);
  const [errors, setErrors] = useState([]);
  const [streamingTrend, setStreamingTrend] = useState<ILineChartPoints[]>([]);

  const handleRegionChange = (
    _: React.FormEvent<HTMLDivElement>,
    option?: IDropdownOption
  ) => {
    if (option) {
      setSelectedRegions(
        option.selected
          ? [...selectedRegions, option.key as string]
          : selectedRegions.filter((key) => key !== option.key)
      );
    }
  };

  const handleTimespanChange = (
    _: React.FormEvent<HTMLDivElement>,
    option?: IDropdownOption
  ) => {
    if (option) {
      setSelectedTimespan(option);
    }
  };

  useEffect(() => {
    if (regions.length > 0) {
      const mTimespan = metricTimespans[selectedTimespan.key];
      const end = DateTime.now().startOf("hour").toISO();
      const start = DateTime.now().minus({ [mTimespan.unit]: mTimespan.value }).startOf("hour").toISO();
      const mIncrement = metricIncrements[selectedTimespan.key];
      const timeIntervals = getTimeIntervals(start, end, mIncrement.unit, mIncrement.increment);

      getStreamingMetrics().then((results) =>
        setSummaryMetrics(getSummaryMetrics(results, selectedRegions))
      );
      getErrorCount().then(setErrorCount);
      getErrors(selectedTimespan.key).then((response) => {
        const colNames = response.columns.map((c: any) => c.name);
        setErrors(response.rows.map((row: string[]) => {
          return zipObject(colNames, row);
        }));
      });
      getMetrics(
        "customMetrics/TotalConnectedClients",
        metricIntervals[selectedTimespan.key],
        selectedTimespan.key,
        "max"
      ).then((response) => {
        setStreamingTrend(
          getAreaChartData(
            response,
            selectedRegions.length > 0 ? selectedRegions : regions,
            timeIntervals,
            "customMetrics/TotalConnectedClients",
            "max"
          )
        );
      });
    }
  }, [regions, selectedRegions, selectedTimespan]);

  useEffect(() => {
    getRegions().then((regionsResponse: string[]) => {
      setRegions(regionsResponse);
      setRegionOptions(regionsResponse.map((r) => ({ key: r, text: r })));
    });
  }, []);

  useInterval(() => {
    getRegions().then((regionsResponse: string[]) => {
      setRegions(regionsResponse);
      setRegionOptions(regionsResponse.map((r) => ({ key: r, text: r })));
    });
  }, 10000);

  return (
    <div>
      <div
        style={{
          color: "#3b3a39",
          fontSize: FontSizes.size42,
        }}
      >
        Pixel Streaming Dashboard
      </div>
      <Stack tokens={{ childrenGap: 20 }}>
        <Stack.Item align="end" style={{ paddingTop: 20 }}>
          <Dropdown
            options={regionOptions}
            selectedKeys={selectedRegions}
            placeholder="Regions"
            multiSelect
            onChange={handleRegionChange}
            style={{ minWidth: 200 }}
          />
        </Stack.Item>
        <Stack
          horizontal
          tokens={{ childrenGap: 20 }}
          style={{
            boxShadow: DefaultEffects.elevation4,
            marginTop: 20,
            padding: 24,
          }}
        >
          <Stack.Item grow>
            <Stack>
              <span
                style={{
                  fontSize: FontSizes.size16,
                  fontWeight: 600,
                }}
              >
                Users
              </span>
              <span
                style={{
                  color: "#605e5c",
                  fontSize: FontSizes.size68,
                  fontWeight: 300,
                }}
              >
                {summaryMetrics[summaryMetricNames[0]] || 0}
              </span>
            </Stack>
          </Stack.Item>
          <Stack.Item grow>
            <Stack>
              <span style={{ fontSize: FontSizes.size16, fontWeight: 600 }}>
                Available Streams
              </span>
              <span
                style={{
                  color: "#605e5c",
                  fontSize: FontSizes.size68,
                  fontWeight: 300,
                }}
              >
                {summaryMetrics[summaryMetricNames[1]] || 0}
              </span>
            </Stack>
          </Stack.Item>
          <Stack.Item grow>
            <Stack>
              <span
                style={{
                  fontSize: FontSizes.size16,
                  fontWeight: 600,
                }}
              >
                Total Streams
              </span>
              <span
                style={{
                  color: "#605e5c",
                  fontSize: FontSizes.size68,
                  fontWeight: 300,
                }}
              >
                {summaryMetrics[summaryMetricNames[3]] || 0}
              </span>
            </Stack>
          </Stack.Item>
          <Stack.Item grow>
            <Stack>
              <span
                style={{
                  fontSize: FontSizes.size16,
                  fontWeight: 600,
                }}
              >
                Total SS VMs
              </span>
              <span
                style={{
                  color: "#605e5c",
                  fontSize: FontSizes.size68,
                  fontWeight: 300,
                }}
              >
                {summaryMetrics[summaryMetricNames[2]] || 0}
              </span>
            </Stack>
          </Stack.Item>
          <Stack.Item grow>
            <Stack>
              <span
                style={{
                  fontSize: FontSizes.size16,
                  fontWeight: 600,
                }}
              >
                Errors
              </span>
              <span
                style={{
                  color: "#605e5c",
                  fontSize: FontSizes.size68,
                  fontWeight: 300,
                }}
              >
                {errorCount}
              </span>
            </Stack>
          </Stack.Item>
        </Stack>
        <Stack.Item align="end" style={{ paddingTop: 20 }}>
          <Dropdown
            options={metricTimespanOptions}
            selectedKey={selectedTimespan.key}
            placeholder="Time Span"
            onChange={handleTimespanChange}
            style={{ minWidth: 200 }}
          />
        </Stack.Item>
        <Stack>
          <Stack.Item
            style={{
              boxShadow: DefaultEffects.elevation4,
              padding: 20,
            }}
          >
            <Stack tokens={{ childrenGap: 20 }}>
              <span
                style={{
                  fontSize: FontSizes.size16,
                  fontWeight: 600,
                }}
              >
                Streaming Activity
              </span>
              {streamingTrend.length > 0 && (
                <LineChart
                  data={{
                    chartTitle: "Streaming Activity",
                    lineChartData: streamingTrend,
                  }}
                  height={200}
                />
              )}
            </Stack>
          </Stack.Item>
        </Stack>
        <Stack style={{ marginBottom: 40 }}>
          <Stack.Item
            style={{
              boxShadow: DefaultEffects.elevation4,
              padding: 20,
            }}
          >
            <Stack tokens={{ childrenGap: 20 }}>
              <span
                style={{
                  fontSize: FontSizes.size16,
                  fontWeight: 600,
                }}
              >
                Errors ({selectedTimespan.text || "Last 1 day"})
              </span>
              {errors.length > 0 && (
                <DetailsList
                  items={errors}
                  columns={errorColumns}
                  selectionMode={SelectionMode.none}
                />
              )}
            </Stack>
          </Stack.Item>
        </Stack>
      </Stack>
    </div>
  );
};

export default Home;
