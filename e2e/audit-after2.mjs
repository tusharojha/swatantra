import { chromium } from "playwright";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const BASE = (process.env.E2E_BASE || "http://127.0.0.1:8088/swatantra").replace(/\/$/, "");
const OUT = process.env.AUDIT_DIR || resolve("artifacts/audit/after2");
const PUNE = "0x698bd7bb49fbf40011ae55248c7ee9b4b80a5a86be112598d2bfb3593020363c";

const routes = [
  ["feed", "/"],
  ["article-pune", `/s/${PUNE}`],
  ["article-fold", `/s/${PUNE}?preview=fold`],
  ["verify", "/verify"],
  ["post", "/post"],
  ["tracker", "/takedowns"],
  ["me", "/me"],
  ["journalist", "/journalist"],
  ["journalist-proving", "/journalist?preview=proving"],
  ["journalist-verified", "/journalist?preview=verified"],
];

const sheets = [
  ["sheet-signin", "/?preview=signin"],
  ["sheet-tip", `/?preview=tip`],
  ["sheet-tip-custom", `/?preview=tip-custom`],
  ["sheet-tip-pending", `/?preview=tip-pending`],
  ["sheet-tip-success", `/?preview=tip-success`],
  ["sheet-tip-error", `/?preview=tip-error`],
  ["sheet-report", "/takedowns?preview=report"],
  ["sheet-filters", "/?preview=filters"],
];

mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({
  args: ["--no-sandbox", "--disable-gpu"],
});

async function waitApp(page) {
  await page.waitForSelector("flutter-view, flt-glass-pane, canvas", { timeout: 45000 }).catch(() => {});
  await page.waitForTimeout(3600);
  await page.evaluate(() => {
    const el = document.querySelector("flt-semantics-placeholder");
    if (el instanceof HTMLElement) el.click();
  }).catch(() => {});
}

async function shoot(name, size, extra = []) {
  const context = await browser.newContext({
    viewport: { width: size.w, height: size.h },
    deviceScaleFactor: 2,
    userAgent: "Mozilla/5.0 SwatantraAudit",
  });
  const page = await context.newPage();
  page.setDefaultTimeout(45000);
  for (const [label, path] of [...routes, ...extra]) {
    const url = `${BASE}${path}`;
    await page.goto(url, { waitUntil: "networkidle", timeout: 60000 }).catch(() => {});
    await waitApp(page);
    const file = resolve(OUT, `${name}-${label}.png`);
    await page.screenshot({ path: file });
    console.log("wrote", file);
  }
  await context.close();
}

await shoot("phone", { w: 390, h: 844 }, sheets);
await shoot("desktop", { w: 1440, h: 900 }, sheets);
await browser.close();
console.log("audit after2 done", OUT);
