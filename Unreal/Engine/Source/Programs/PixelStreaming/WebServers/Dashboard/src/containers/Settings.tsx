import {
  ChoiceGroup,
  DefaultButton,
  Depths,
  DetailsList,
  FontSizes,
  FontWeights,
  IChoiceGroupOption,
  IColumn,
  IconButton,
  Label,
  mergeStyleSets,
  Modal,
  Panel,
  PanelType,
  PrimaryButton,
  SelectionMode,
  Slider,
  SpinButton,
  Stack,
  TextField,
} from "@fluentui/react";
import { isString } from "lodash";
import React, { useEffect, useState } from "react";
import { addSettings, getSettings } from "src/api";
import BlobBrowser, { BlobItem } from "./BlobBrowser";
import { Setting } from "./Header";

const contentStyles = mergeStyleSets({
  container: {
    display: "flex",
    flexFlow: "column nowrap",
    alignItems: "stretch",
    padding: "12px 12px 14px 24px",
  },
  header: [
    {
      display: "flex",
      alignItems: "center",
      fontSize: FontSizes.large,
      fontWeight: FontWeights.semibold,
      justifyContent: "space-between",
    },
  ],
});

const DEFAULT_SETTINGS: Setting = {
  instancesPerNode: 1,
  resolutionWidth: 1920,
  resolutionHeight: 1080,
  fps: 60,
  unrealApplicationDownloadUri: "",
  enableAutoScale: true,
  instanceCountBuffer: 1,
  percentBuffer: 25,
  minMinutesBetweenScaledowns: 60,
  scaleDownByAmount: 1,
  minInstanceCount: 1,
  maxInstanceCount: 20,
  stunServerAddress: "",
  turnServerAddress: "",
  turnUsername: "",
  turnPassword: "",
};

const autoscaleOptions: IChoiceGroupOption[] = [
  { key: "enable", text: "Enable" },
  { key: "disable", text: "Disable" },
];

const columns: IColumn[] = [
  {
    key: "version",
    name: "Version",
    ariaLabel: "Version",
    fieldName: "version",
    minWidth: 64,
    maxWidth: 64,
  },
  {
    key: "instancesPerNode",
    name: "Instances",
    ariaLabel: "Instances per node",
    fieldName: "instancesPerNode",
    minWidth: 80,
  },
  {
    key: "resolution",
    name: "Resolution",
    ariaLabel: "Resolution",
    minWidth: 100,
    onRender: (item: Setting) => {
      return (
        <span>
          {item.resolutionWidth} x {item.resolutionHeight}
        </span>
      );
    },
  },
  {
    key: "fps",
    name: "FPS",
    ariaLabel: "FPS",
    fieldName: "fps",
    minWidth: 48,
    maxWidth: 48,
  },
  {
    key: "unrealApplicationDownloadUri",
    name: "Download URI",
    ariaLabel: "Download URI",
    fieldName: "unrealApplicationDownloadUri",
    minWidth: 300,
  },
];

const getDefaultSettings = (settings: Setting[]) => {
  if (settings.length === 0) {
    return DEFAULT_SETTINGS;
  }

  const lastSetting = settings[0];
  const formSettings = {
    instancesPerNode: lastSetting.instancesPerNode || 1,
    resolutionWidth: lastSetting.resolutionWidth || 1920,
    resolutionHeight: lastSetting.resolutionHeight || 1080,
    fps: lastSetting.fps || 60,
    unrealApplicationDownloadUri: "",
    enableAutoScale: isString(lastSetting.enableAutoScale)
      ? (lastSetting.enableAutoScale as string).toLowerCase() === "true"
      : lastSetting.enableAutoScale,
    instanceCountBuffer: lastSetting.instanceCountBuffer || 1,
    percentBuffer: lastSetting.percentBuffer || 25,
    minMinutesBetweenScaledowns: lastSetting.minMinutesBetweenScaledowns || 60,
    scaleDownByAmount: lastSetting.scaleDownByAmount || 1,
    minInstanceCount: lastSetting.minInstanceCount || 1,
    maxInstanceCount: lastSetting.maxInstanceCount || 20,
    stunServerAddress: lastSetting.stunServerAddress || "",
    turnServerAddress: lastSetting.turnServerAddress || "",
    turnUsername: lastSetting.turnUsername || "",
    turnPassword: lastSetting.turnPassword || "",
  };

  return formSettings;
};

const Settings = () => {
  const [settings, setSettings] = useState<Setting[]>([]);
  const [newSettings, setNewSettings] = useState<Setting>(
    getDefaultSettings(settings)
  );
  const [uploadFormOpen, setUploadFormOpen] = useState(false);
  const [blobBrowserOpen, setBlobBrowserOpen] = useState(false);

  const handleUploadClick = () => {
    setNewSettings(getDefaultSettings(settings));
    setUploadFormOpen(true);
  };

  const handleUploadDismiss = () => {
    setUploadFormOpen(false);
  };

  const handleUpdateBooleanSetting = (
    key: string,
    ev?: any,
    option?: IChoiceGroupOption
  ) => {
    if (option === undefined) {
      return;
    }

    const enabled = option.key === "enable";
    const updatedSetting = { ...newSettings, [key]: enabled };
    setNewSettings(updatedSetting);
  };

  const handleSliderUpdateSetting = (key: string, value: number) => {
    if (value === undefined || value === null) {
      return;
    }
    const updatedSetting = { ...newSettings, [key]: value };
    setNewSettings(updatedSetting);
  };

  const handleUpdateNumberSetting = (key: string, ev?: any, value?: string) => {
    if (value === undefined || value === null) {
      return;
    }
    const numberValue = parseInt(value);
    const newValue = isNaN(numberValue) ? value : numberValue;
    const updatedSetting = { ...newSettings, [key]: newValue };
    setNewSettings(updatedSetting);
  };

  const handleUpdateStringSetting = (key: string, ev?: any, value?: string) => {
    if (value === undefined || value === null) {
      return;
    }
    const updatedSetting = { ...newSettings, [key]: value };
    setNewSettings(updatedSetting);
  };

  const handleUpload = async () => {
    try {
      await addSettings(newSettings);

      const response = await getSettings(false);
      setSettings(response);

      handleUploadDismiss();
    } catch (err) {
      console.log(err);
    }
  };

  const handleBlobSelect = (blob: BlobItem) => {
    const updatedSetting = {
      ...newSettings,
      unrealApplicationDownloadUri: blob.name,
    };
    setNewSettings(updatedSetting);
    setBlobBrowserOpen(false);
  };

  const handleOuterClick = (ev?: React.MouseEvent) => {
    ev?.preventDefault();
  };

  useEffect(() => {
    getSettings(false).then((response) => setSettings(response));
  }, []);

  return (
    <div>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          color: "#3b3a39",
          fontSize: FontSizes.size42,
        }}
      >
        Settings
        <PrimaryButton text="Add New Version" onClick={handleUploadClick} />
      </div>
      <div
        style={{
          marginTop: 40,
          boxShadow: Depths.depth4,
          borderRadius: 2,
          minHeight: 200,
          padding: 10,
          background: "white",
        }}
      >
        <DetailsList
          selectionMode={SelectionMode.none}
          columns={columns}
          items={settings}
        />
      </div>
      <Panel
        headerText="Add New Version"
        isBlocking={true}
        isLightDismiss={false}
        isOpen={uploadFormOpen}
        type={PanelType.medium}
        onDismiss={handleUploadDismiss}
        onOuterClick={handleOuterClick}
      >
        <Stack tokens={{ childrenGap: 8, padding: "20px 0" }}>
          <Stack.Item>
            <Label>Application Blob</Label>
            <Stack horizontal={true} tokens={{ childrenGap: 5 }}>
              <Stack.Item>
                <DefaultButton
                  text="Select blob"
                  onClick={() => setBlobBrowserOpen(true)}
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Label>Streams Per GPU VM</Label>
            <Slider
              min={1}
              max={2}
              step={1}
              showValue
              snapToStep
              value={newSettings.instancesPerNode}
              onChange={handleSliderUpdateSetting.bind(
                this,
                "instancesPerNode"
              )}
            />
          </Stack.Item>
          <Stack horizontal={true} tokens={{ childrenGap: 20 }}>
            <Stack.Item grow={2}>
              <Label>Resolution</Label>
              <div style={{ display: "flex", alignItems: "center" }}>
                <SpinButton
                  min={1}
                  step={1}
                  incrementButtonAriaLabel={"Increase resolution width by 1"}
                  decrementButtonAriaLabel={"Decrease resolution width by 1"}
                  value={newSettings.resolutionWidth.toString()}
                  onChange={handleUpdateNumberSetting.bind(
                    this,
                    "resolutionWidth"
                  )}
                />
                <span style={{ padding: "0 8px" }}>X</span>
                <SpinButton
                  min={1}
                  step={1}
                  incrementButtonAriaLabel={"Increase resolution height by 1"}
                  decrementButtonAriaLabel={"Decrease resolution height by 1"}
                  value={newSettings.resolutionHeight.toString()}
                  onChange={handleUpdateNumberSetting.bind(
                    this,
                    "resolutionHeight"
                  )}
                />
              </div>
            </Stack.Item>
            <Stack.Item grow={1}>
              <Label>FPS</Label>
              <SpinButton
                min={1}
                step={1}
                incrementButtonAriaLabel={"Increase FPS by 1"}
                decrementButtonAriaLabel={"Decrease FPS by 1"}
                value={newSettings.fps.toString()}
                onChange={handleUpdateNumberSetting.bind(this, "fps")}
              />
            </Stack.Item>
          </Stack>
          <Stack.Item>
            <Label>Enable Autoscale</Label>
            <ChoiceGroup
              options={autoscaleOptions}
              onChange={handleUpdateBooleanSetting.bind(
                this,
                "enableAutoScale"
              )}
              selectedKey={newSettings.enableAutoScale ? "enable" : "disable"}
              required={true}
            />
          </Stack.Item>
          <Stack horizontal={true} tokens={{ childrenGap: 20 }}>
            <Stack.Item grow={1}>
              <Label>Instance Count Buffer</Label>
              <SpinButton
                min={0}
                step={1}
                incrementButtonAriaLabel={"Increase instance count buffer by 1"}
                decrementButtonAriaLabel={"Decrease instance count buffer by 1"}
                value={newSettings.instanceCountBuffer?.toString()}
                onChange={handleUpdateNumberSetting.bind(
                  this,
                  "instanceCountBuffer"
                )}
              />
            </Stack.Item>
            <Stack.Item grow={3}>
              <Label>Percent Buffer</Label>
              <Slider
                min={0}
                max={100}
                step={1}
                showValue
                snapToStep
                value={newSettings.percentBuffer}
                onChange={handleSliderUpdateSetting.bind(this, "percentBuffer")}
              />
            </Stack.Item>
          </Stack>
          <Stack.Item>
            <Label>Idle Minutes</Label>
            <SpinButton
              min={1}
              step={1}
              incrementButtonAriaLabel={"Increase idle minutes by 1"}
              decrementButtonAriaLabel={"Decrease idle minutes by 1"}
              value={newSettings.minMinutesBetweenScaledowns?.toString()}
              onChange={handleUpdateNumberSetting.bind(this, "minMinutesBetweenScaledowns")}
            />
          </Stack.Item>
          <Stack.Item>
            <Label>Scale Down by amount</Label>
            <SpinButton
              min={1}
              step={1}
              incrementButtonAriaLabel={"Increase scale down by amount by 1"}
              decrementButtonAriaLabel={"Decrease scale down by amount by 1"}
              value={newSettings.scaleDownByAmount?.toString()}
              onChange={handleUpdateNumberSetting.bind(this, "scaleDownByAmount")}
            />
          </Stack.Item>
          <Stack horizontal={true} tokens={{ childrenGap: 20 }}>
            <Stack.Item grow={1}>
              <Label>Min Idle Instance Count</Label>
              <SpinButton
                min={1}
                step={1}
                incrementButtonAriaLabel={
                  "Increase minimum idle instance count by 1"
                }
                decrementButtonAriaLabel={
                  "Decrease minimum idle instance count by 1"
                }
                value={newSettings.minInstanceCount?.toString()}
                onChange={handleUpdateNumberSetting.bind(
                  this,
                  "minInstanceCount"
                )}
              />
            </Stack.Item>
            <Stack.Item grow={1}>
              <Label>Max Instance Scale Count</Label>
              <SpinButton
                min={1}
                step={1}
                incrementButtonAriaLabel={
                  "Increase maximum instance scale count by 1"
                }
                decrementButtonAriaLabel={
                  "Decrease maximum instance scale count by 1"
                }
                value={newSettings.maxInstanceCount?.toString()}
                onChange={handleUpdateNumberSetting.bind(
                  this,
                  "maxInstanceCount"
                )}
              />
            </Stack.Item>
          </Stack>
          <Stack.Item>
            <Label>STUN Server Address</Label>
            <TextField
              value={newSettings.stunServerAddress}
              onChange={handleUpdateStringSetting.bind(
                this,
                "stunServerAddress"
              )}
            />
          </Stack.Item>
          <Stack.Item>
            <Label>TURN Server Address</Label>
            <TextField
              value={newSettings.turnServerAddress}
              onChange={handleUpdateStringSetting.bind(
                this,
                "turnServerAddress"
              )}
            />
          </Stack.Item>
          <Stack horizontal={true} tokens={{ childrenGap: 20 }}>
            <Stack.Item grow={1}>
              <Label>TURN Server Username</Label>
              <TextField
              value={newSettings.turnUsername}
              onChange={handleUpdateStringSetting.bind(
                this,
                "turnUsername"
              )}
            />
            </Stack.Item>
            <Stack.Item grow={1}>
              <Label>TURN Server Password</Label>
              <TextField
              value={newSettings.turnPassword}
              onChange={handleUpdateStringSetting.bind(
                this,
                "turnPassword"
              )}
            />
            </Stack.Item>
          </Stack>
          <Stack.Item style={{ marginTop: 100 }}>
            <PrimaryButton text="Add Version" onClick={handleUpload} />
            <DefaultButton
              text="Cancel"
              onClick={handleUploadDismiss}
              style={{ marginLeft: 8 }}
            />
          </Stack.Item>
        </Stack>
      </Panel>
      <Modal
        containerClassName={contentStyles.container}
        isOpen={blobBrowserOpen}
        onDismiss={() => setBlobBrowserOpen(false)}
        isBlocking={true}
      >
        <div className={contentStyles.header}>
          <span>Select Blob</span>
          <IconButton
            iconProps={{ iconName: "Cancel" }}
            ariaLabel="Close blob browser"
            onClick={() => setBlobBrowserOpen(false)}
          />
        </div>
        <BlobBrowser onSelect={handleBlobSelect} />
      </Modal>
    </div>
  );
};

export default Settings;
