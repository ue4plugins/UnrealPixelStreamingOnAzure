import { initializeIcons } from "@uifabric/icons";
import React from "react";
import ReactDOM from "react-dom";
import App from "./App";
import "./index.css";

initializeIcons();

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById("root")
);
