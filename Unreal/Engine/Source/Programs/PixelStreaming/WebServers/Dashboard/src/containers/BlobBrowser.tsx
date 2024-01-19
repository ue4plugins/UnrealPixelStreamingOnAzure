import {
  DetailsList,
  IColumn,
  PrimaryButton,
  Selection,
  SelectionMode,
  Stack,
} from "@fluentui/react";
import { useEffect, useState } from "react";
import { getBlobs } from "src/api";
import { bytesToSize } from "src/util";

export interface BlobItem {
  name: string;
  lastModified: string;
  contentLength: number;
}

interface IBlobBrowser {
  onSelect: (blob: BlobItem) => void;
}

const columns: IColumn[] = [
  {
    key: "name",
    name: "Name",
    fieldName: "name",
    minWidth: 200,
    isResizable: true,
  },
  {
    key: "lastModified",
    name: "Last Modified",
    fieldName: "lastModified",
    minWidth: 100,
    maxWidth: 200,
    isResizable: true,
  },
  {
    key: "contentLength",
    name: "Size",
    fieldName: "contentLength",
    minWidth: 100,
    maxWidth: 100,
    isResizable: true,
    onRender: (item) => {
      return bytesToSize(item.contentLength);
    },
  },
];

const BlobBrowser = ({ onSelect }: IBlobBrowser) => {
  const [blobs, setBlobs] = useState<BlobItem[]>([]);
  const [selectedBlob, setSelectedBlob] = useState<BlobItem>();
  const selection = new Selection({
    onSelectionChanged: () => {
      setSelectedBlob(selection.getSelection()[0] as BlobItem);
    },
  });

  const handleSelect = () => {
    if (selectedBlob) {
      onSelect(selectedBlob);
    }
  };

  useEffect(() => {
    getBlobs().then((items) => setBlobs(items));
  }, []);

  return (
    <Stack tokens={{ childrenGap: 20 }}>
      <DetailsList
        columns={columns}
        items={blobs}
        selection={selection}
        selectionMode={SelectionMode.single}
      />
      <Stack.Item align="end">
        <PrimaryButton onClick={handleSelect}>Select</PrimaryButton>
      </Stack.Item>
    </Stack>
  );
};

export default BlobBrowser;
