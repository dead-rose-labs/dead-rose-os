import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "@dead-rose/ui/styles.css";
import { Installer } from "./Installer";
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Installer />
  </StrictMode>,
);
