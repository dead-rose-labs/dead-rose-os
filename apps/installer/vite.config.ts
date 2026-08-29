import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { resolve } from "node:path";
export default defineConfig({
  plugins: [react(), tailwindcss()],
  publicDir: resolve(__dirname, "../../assets/brand"),
  server: { port: 1421, strictPort: true },
  build: { target: "es2022", sourcemap: false },
});
