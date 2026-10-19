import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const BASE = (process.env.E2E_BASE || "https://tusharojha.github.io/swatantra").replace(/\/$/, "");
const OUT = process.env.AUDIT_DIR || resolve("artifacts/audit/before");
const PUNE = "0x698bd7bb49fbf40011ae55248c7ee9b4b80a5a86be112598d2bfb3593020363c";

const routes = [
  ["feed", "/"],
  ["article-pune", `/s/${PUNE}`],
  ["verify", "/verify"],
  ["post", "/post"],
  ["tracker", "/takedowns"],
  ["me", "/me"],
  ["journalist", "/journalist"],
];

mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({
  args: ["--no-sandbox", "--disable-gpu"],
});

async function waitApp(page) {
  await page.waitForSelector("flutter-view, flt-glass-pane, canvas", { timeout: 45000 }).catch(() => {});
  await page.waitForTimeout(3200);
  await page.evaluate(() => {
    const el = document.querySelector("flt-semantics-placeholder");
    if (el instanceof HTMLElement) el.click();
  }).catch(() => {});
}

async function tap(page, name) {
  const loc = page.getByRole("button", { name, exact: true }).first();
  if (await loc.count()) {
    await loc.click({ force: true });
    return true;
  }
  const any = page.locator(`[aria-label="${name}"]`).first();
  if (await any.count()) {
    await any.click({ force: true });
    return true;
  }
  return false;
}

async function shoot(name, size) {
  const context = await browser.newContext({
    viewport: { width: size.w, height: size.h },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  page.setDefaultTimeout(45000);
  for (const [label, path] of routes) {
    const url = `${BASE}${path}`;
    await page.goto(url, { waitUntil: "networkidle", timeout: 60000 }).catch(() => {});
    await waitApp(page);
    const file = resolve(OUT, `${name}-${label}.png`);
    await page.screenshot({ path: file, fullPage: true });
    console.log("wrote", file);
  }

  await page.goto(`${BASE}/s/${PUNE}`, { waitUntil: "networkidle", timeout: 60000 }).catch(() => {});
  await waitApp(page);
  if (await tap(page, "Tip")) {
    await page.waitForTimeout(900);
    await page.screenshot({ path: resolve(OUT, `${name}-sheet-signin.png`), fullPage: true });
    console.log("wrote", `${name}-sheet-signin.png`);
  }

  await page.goto(`${BASE}/me`, { waitUntil: "networkidle", timeout: 60000 }).catch(() => {});
  await waitApp(page);
  await page.screenshot({ path: resolve(OUT, `${name}-onboard.png`), fullPage: true });

  await context.close();
}

await shoot("phone", { w: 390, h: 844 });
await shoot("desktop", { w: 1440, h: 900 });
await browser.close();
console.log("audit done", OUT);
