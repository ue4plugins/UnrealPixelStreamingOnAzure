import { DateTime } from "luxon";

export const validateInteger = (value: string) => {
  const intValue = parseInt(value);
  if (isNaN(intValue)) {
    return "Value must be an integer.";
  }

  return "";
};

export const bytesToSize = (bytes: number) => {
  const sizes = ["Bytes", "KB", "MB", "GB", "TB"];
  if (bytes === 0) {
    return "0 Byte";
  }

  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const v = bytes / Math.pow(1024, i);
  return `${v.toFixed(2)} ${sizes[i]}`;
};

export const getTimeIntervals = (
  start: string,
  end: string,
  unit: string,
  increment: number
) => {
  const to = DateTime.fromISO(end);

  const intervals = [];
  let curr = DateTime.fromISO(start);
  while (curr < to) {
    intervals.push(curr);
    curr = curr.plus({ [unit]: increment });
  }
  intervals.push(to);

  return intervals;
};

export const validatePassword = (pw: string) => {
  if (pw.length < 8) {
    return "Must be at least 8 characters long";
  }
  
  if (pw.toUpperCase() === pw || pw.toLowerCase() === pw) {
    return "Must contain at least 1 uppercase and 1 lowercase character";
  }

  if (!/\d/.test(pw)) {
    return "Must contain at least 1 number";
  }
};
