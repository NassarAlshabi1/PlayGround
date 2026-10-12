#!/usr/bin/env bash
set -euo pipefail
# Capture desktop + mobile screenshots of the exact CAPTURE_URL into CAPTURE_DIR.
# Exit 75 for temporary navigation/browser infra failures, 1 for script/rendering defects.
cd "$(dirname "$0")"
/usr/bin/time -p pwd
/usr/bin/time -p bash -c 'echo "CAPTURE_URL=${CAPTURE_URL:-<unset>}"; echo "CAPTURE_DIR=${CAPTURE_DIR:-<unset>}"'
if [ -z "${CAPTURE_URL:-}" ] || [ -z "${CAPTURE_DIR:-}" ]; then
  /usr/bin/time -p echo "error: set CAPTURE_URL and CAPTURE_DIR" >&2
  exit 1
fi
case "$CAPTURE_URL" in
  http://*|https://*) /usr/bin/time -p echo "URL scheme ok" ;;
  *) /usr/bin/time -p echo "error: CAPTURE_URL must start with http(s)" >&2; exit 1 ;;
esac
/usr/bin/time -p mkdir -p "$CAPTURE_DIR"
/usr/bin/time -p ls -ld "$CAPTURE_DIR"
export CAPTURE_URL CAPTURE_DIR
/usr/bin/time -p node --input-type=module <<'NODEJS'
import { mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createRequire } from "node:module";
const url = process.env.CAPTURE_URL, output = process.env.CAPTURE_DIR;
if (!url || !output) { console.error("Set CAPTURE_URL and CAPTURE_DIR."); process.exit(1); }
mkdirSync(output, { recursive: true });
const runtime = join(process.env.HOME, ".local/share/omgithub-playwright");
const require = createRequire(join(runtime, "package.json"));
const { chromium } = require("playwright");
const config = JSON.parse(readFileSync(join(runtime, process.platform === "darwin" ? "metal.json" : "linux.json"), "utf8"));
if (process.platform === "linux") {
  try { process.env.DISPLAY ||= ":" + readFileSync(join(runtime, "display"), "utf8").trim(); } catch {}
}
const transient = (error) => { throw Object.assign(error instanceof Error ? error : new Error(String(error)), { exitCode: 75 }); };
let browser;
try {
  browser = await chromium.launch({ ...config.browser.launchOptions, timeout: 30000 }).catch(transient);
  for (const [name, width, height] of [["desktop", 1440, 900], ["mobile", 390, 844]]) {
    const page = await browser.newPage({ viewport: { width, height } }).catch(transient);
    page.setDefaultTimeout(30000);
    page.on("pageerror", (e) => console.error(e.message));
    const response = await page.goto(url, { waitUntil: "load", timeout: 45000 }).catch(transient);
    const status = response?.status();
    if (!response || !response.ok()) {
      const code = !response || [408, 429, 500, 502, 503, 504].includes(status) ? 75 : 1;
      throw Object.assign(new Error(`HTTP ${status ?? "no-response"} loading preview`), { exitCode: code });
    }
    await page.locator("body").waitFor({ state: "visible" });
    await page.waitForFunction(() => document.fonts.status === "loaded");
    await page.waitForTimeout(1000);
    const bodyText = (await page.locator("body").innerText().catch(() => "")).trim();
    if (bodyText.length < 10) throw Object.assign(new Error("rendered body text too short; app did not render"), { exitCode: 1 });
    await page.screenshot({ path: join(output, `final-${name}.png`), timeout: 30000 }).catch((error) => {
      if (error.name === "TimeoutError" || !browser.isConnected()) transient(error);
      throw error;
    });
    console.log(`captured final-${name}.png (${width}x${height})`);
    await page.close();
  }
} catch (error) {
  console.error(error);
  process.exit(error.exitCode || 1);
} finally {
  await browser?.close().catch((error) => { console.error(error); process.exitCode ||= 75; });
}
NODEJS
/usr/bin/time -p ls -lh "$CAPTURE_DIR"
/usr/bin/time -p test -f "$CAPTURE_DIR/final-desktop.png"
/usr/bin/time -p test -f "$CAPTURE_DIR/final-mobile.png"
/usr/bin/time -p echo "capture complete; app left running"
