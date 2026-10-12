#!/usr/bin/env bash
set -euo pipefail
# Marina Hotel static preview server.
# Serves prebuilt static directory inside PROJECT_DIR on PORT (default 3000).
cd "$(dirname "$0")"
/usr/bin/time -p pwd
export PORT="${PORT:-3000}"
/usr/bin/time -p bash -c 'echo "PORT=$PORT"'
PROJECT_DIR="$(pwd)"
/usr/bin/time -p echo "PROJECT_DIR=$PROJECT_DIR"
export DIST_DIR="$PROJECT_DIR/dist"
/usr/bin/time -p echo "DIST_DIR=$DIST_DIR"
OPENCODE_WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
/usr/bin/time -p echo "OPENCODE_WEB_DIR=$OPENCODE_WEB_DIR"
/usr/bin/time -p mkdir -p "$DIST_DIR" "$OPENCODE_WEB_DIR"
# Source lives inside PROJECT_DIR (App/ when present); built output is DIST_DIR.
# Do not require App/: dist/ is already committed and valid after App deletion.
/usr/bin/time -p ls -lh "$PROJECT_DIR"
/usr/bin/time -p ls -lh "$DIST_DIR" || true
# Install dependencies when a root package.json exists (no-op for static dist).
if [ -f "$PROJECT_DIR/package.json" ]; then
  /usr/bin/time -p bash -c 'if [ -f "$0/package-lock.json" ]; then npm --prefix "$0" ci --no-audit --no-fund; else npm --prefix "$0" install --no-audit --no-fund; fi' "$PROJECT_DIR"
else
  /usr/bin/time -p echo "no root package.json; skipping npm install"
fi
# Build static output inside PROJECT_DIR when missing or stale.
# If App/ source exists, sync from it; otherwise reuse committed dist/ as-is.
/usr/bin/time -p bash -c '
  set -euo pipefail
  PROJECT_DIR="$0"
  DIST_DIR="$1"
  if [ -f "$PROJECT_DIR/App/index_static.html" ]; then
    if [ ! -f "$DIST_DIR/index.html" ] || [ "$PROJECT_DIR/App/index_static.html" -nt "$DIST_DIR/index.html" ]; then
      cp "$PROJECT_DIR/App/index_static.html" "$DIST_DIR/index.html"
      [ -f "$PROJECT_DIR/App/complete-dashboard.html" ] && cp "$PROJECT_DIR/App/complete-dashboard.html" "$DIST_DIR/complete-dashboard.html" || true
      [ -f "$PROJECT_DIR/App/marina_hotel_offline.html" ] && cp "$PROJECT_DIR/App/marina_hotel_offline.html" "$DIST_DIR/marina_hotel_offline.html" || true
      [ -f "$PROJECT_DIR/App/offline.html" ] && cp "$PROJECT_DIR/App/offline.html" "$DIST_DIR/offline.html" || true
      if [ -d "$PROJECT_DIR/App/includes" ]; then
        rm -rf "$DIST_DIR/includes"
        cp -r "$PROJECT_DIR/App/includes" "$DIST_DIR/includes"
      fi
      echo "rebuilt dist from App source"
    else
      echo "dist up to date; skipping rebuild"
    fi
  else
    if [ -f "$DIST_DIR/index.html" ]; then
      echo "no App source; reusing committed dist"
    else
      echo "error: no App source and dist/index.html missing" >&2
      exit 1
    fi
  fi
' "$PROJECT_DIR" "$DIST_DIR"
/usr/bin/time -p ls -lh "$DIST_DIR"
/usr/bin/time -p test -f "$DIST_DIR/index.html"
# Publish deployment output for the controller (worker metadata only).
/usr/bin/time -p printf '{"project":"%s","directory":"%s"}' "$PROJECT_DIR" "$DIST_DIR"
/usr/bin/time -p bash -c 'printf "{\"project\":\"%s\",\"directory\":\"%s\"}" "$0" "$1" > "$2/deployment-output.json"' "$PROJECT_DIR" "$DIST_DIR" "$OPENCODE_WEB_DIR"
/usr/bin/time -p cat "$OPENCODE_WEB_DIR/deployment-output.json"
# Serve the built static directory in the foreground.
/usr/bin/time -p node --input-type=module -e '
import { createServer } from "node:http";
import { readFileSync, existsSync, statSync } from "node:fs";
import { resolve, join, extname } from "node:path";
const root = process.env.DIST_DIR || resolve(process.cwd(), "dist");
const port = Number(process.env.PORT || 3000);
const mime = { ".html":"text/html; charset=utf-8", ".js":"application/javascript; charset=utf-8", ".css":"text/css; charset=utf-8", ".json":"application/json", ".svg":"image/svg+xml", ".png":"image/png", ".jpg":"image/jpeg", ".jpeg":"image/jpeg", ".webp":"image/webp", ".woff":"font/woff", ".woff2":"font/woff2", ".ttf":"font/ttf", ".ico":"image/x-icon" };
const server = createServer((req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    let path = resolve(root, "." + decodeURIComponent(url.pathname));
    if (path !== resolve(root) && !path.startsWith(resolve(root) + "/")) { res.writeHead(404); res.end("Not found"); return; }
    if (existsSync(path) && statSync(path).isDirectory()) path = join(path, "index.html");
    if (!existsSync(path)) { res.writeHead(404); res.end("Not found"); return; }
    res.setHeader("Content-Type", mime[extname(path)] || "application/octet-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.end(readFileSync(path));
  } catch { res.writeHead(404); res.end("Not found"); }
});
server.listen(port, "0.0.0.0", () => console.log(`serving ${root} on :${port}`));
'
