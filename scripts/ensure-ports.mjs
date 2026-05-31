/**
 * ensure-ports.mjs: pick free host ports for the published services so
 * `compose up` never crashes with "port already allocated" when another
 * project (or a previous run) is holding a default port.
 *
 * For each published service it keeps the desired port when it is free (or
 * already published by this project's own container), otherwise it scans
 * upward for the next free one. Resolved ports are written back into
 * compose/.env so compose, `just status`, and the README URLs all agree.
 *
 * Only the host-published services are managed here. mongo and redis are
 * internal to the compose network (no host mapping), so they never collide
 * with the host.
 *
 * Usage:  node scripts/ensure-ports.mjs
 */

import { execSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { createServer } from "node:net";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const ENV_PATH = resolve(ROOT, "compose/.env");

const PROJECT = "pin-equipo4";
const MAX_ATTEMPTS = 50;
const PS_TIMEOUT_MS = 10_000;

// envKey -> default host port. Order matters: earlier services resolve
// first and reserve their port so later ones never reuse it.
const SERVICES = [
  { key: "API_HOST_PORT", def: 3000 },
  { key: "PROMETHEUS_HOST_PORT", def: 9090 },
  { key: "GRAFANA_HOST_PORT", def: 3001 },
];

function isPortFree(port) {
  return new Promise((res) => {
    const server = createServer();
    server.once("error", () => res(false));
    server.listen(port, "127.0.0.1", () => server.close(() => res(true)));
  });
}

// Ports already published by this project's own containers, queried across
// both engines so a re-run reuses them (no churn) regardless of whether the
// stack was started with podman or docker.
function ownPublishedPorts() {
  const taken = new Set();
  const engines = [process.env.CONTAINER_ENGINE, "podman", "docker"].filter(Boolean);
  for (const engine of engines) {
    try {
      const out = execSync(`${engine} ps --filter "name=${PROJECT}-" --format "{{.Ports}}"`, {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "pipe"],
        timeout: PS_TIMEOUT_MS,
      });
      for (const m of out.matchAll(/(?:0\.0\.0\.0|\[::\]|127\.0\.0\.1):(\d+)->/g)) {
        taken.add(Number(m[1]));
      }
    } catch {
      // engine missing or daemon off: skip, fall back to the free-port scan
    }
  }
  return taken;
}

async function resolvePort(desired, ours, assigned) {
  for (let i = 0; i < MAX_ATTEMPTS; i++) {
    const port = desired + i;
    if (assigned.has(port)) continue;
    if (ours.has(port) || (await isPortFree(port))) return port;
  }
  throw new Error(`No free port found in range ${desired}..${desired + MAX_ATTEMPTS - 1}`);
}

function readEnvVar(key) {
  if (!existsSync(ENV_PATH)) return null;
  for (const line of readFileSync(ENV_PATH, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq > 0 && trimmed.slice(0, eq).trim() === key) {
      return trimmed.slice(eq + 1).trim();
    }
  }
  return null;
}

function writeEnvVars(updates) {
  let content = readFileSync(ENV_PATH, "utf8");
  for (const [key, value] of Object.entries(updates)) {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regex = new RegExp(`^${escaped}=.*$`, "m");
    content = regex.test(content)
      ? content.replace(regex, `${key}=${value}`)
      : `${content.replace(/\n?$/, "\n")}${key}=${value}\n`;
  }
  writeFileSync(ENV_PATH, content, "utf8");
}

async function main() {
  if (!existsSync(ENV_PATH)) {
    console.error("compose/.env not found. Copy compose/.env.example to compose/.env first.");
    process.exit(1);
  }

  const ours = ownPublishedPorts();
  const assigned = new Set();
  const updates = {};

  for (const { key, def } of SERVICES) {
    const desired = Number(readEnvVar(key)) || def;
    const port = await resolvePort(desired, ours, assigned);
    assigned.add(port);
    updates[key] = String(port);
    console.error(port === desired ? `  ${key}: ${port}` : `  ${key}: ${desired} taken -> ${port}`);
  }

  writeEnvVars(updates);
}

await main();
