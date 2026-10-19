import { createServer } from "node:http";
import { existsSync, readFileSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";

const root = process.argv[2] || "/tmp/serve";
const port = Number(process.argv[3] || 8088);
const prefix = "/swatantra";
const mime = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ico": "image/x-icon",
  ".map": "application/json",
};

function safe(p) {
  const n = normalize(p);
  if (!n.startsWith(root)) return join(root, prefix, "index.html");
  return n;
}

createServer((req, res) => {
  const url = decodeURIComponent((req.url || "/").split("?")[0]);
  let file = safe(join(root, url));
  try {
    if (existsSync(file) && statSync(file).isDirectory()) {
      file = join(file, "index.html");
    }
    if (!existsSync(file) || statSync(file).isDirectory()) {
      file = join(root, prefix, "index.html");
    }
    const body = readFileSync(file);
    res.writeHead(200, { "content-type": mime[extname(file)] || "application/octet-stream" });
    res.end(body);
  } catch (e) {
    res.writeHead(500);
    res.end(String(e));
  }
}).listen(port, () => console.log("serving", root, "on", port));
