import { readdirSync, mkdirSync, readFileSync, existsSync, writeFileSync } from "node:fs";
import { resolve, basename } from "node:path";
import { chromium } from "playwright";

const afterDir = resolve("../artifacts/audit/after2");
mkdirSync(afterDir, { recursive: true });

const files = existsSync(afterDir)
  ? readdirSync(afterDir).filter((f) => f.endsWith(".png") && !f.startsWith("contact-")).sort()
  : [];

const toData = (p) => {
  if (!existsSync(p)) return "";
  const buf = readFileSync(p);
  return `data:image/png;base64,${buf.toString("base64")}`;
};

function sheetHtml(title, list, columns) {
  return `<!doctype html><html><head><meta charset="utf-8">
<style>
  body { font-family: Inter, sans-serif; background: #111; color: #fff; margin: 20px; }
  h1 { font-family: Georgia, serif; font-size: 24px; margin: 0 0 16px; }
  .grid { display: grid; grid-template-columns: repeat(${columns}, 1fr); gap: 12px; }
  figure { margin: 0; background: #1a1a1a; border-radius: 12px; overflow: hidden; border: 1px solid #2a2a2a; }
  img { width: 100%; display: block; }
  figcaption { font-size: 11px; padding: 8px 10px; color: #bbb; letter-spacing: 0.04em; }
</style></head><body>
<h1>${title}</h1>
<div class="grid">${list
    .map((f) => `<figure><img src="${toData(resolve(afterDir, f))}"/><figcaption>${basename(f).replace(".png", "")}</figcaption></figure>`)
    .join("")}</div>
</body></html>`;
}

const phone = files.filter((f) => f.startsWith("phone-") && !f.includes("sheet-"));
const sheets = files.filter((f) => f.includes("sheet-") && f.startsWith("phone-"));
const desktop = files.filter((f) => f.startsWith("desktop-") && !f.includes("sheet-"));

const browser = await chromium.launch({ args: ["--no-sandbox", "--disable-gpu"] });
const page = await browser.newPage({ viewport: { width: 1600, height: 1100 } });

async function snap(html, width, height, out) {
  await page.setViewportSize({ width, height });
  await page.setContent(html, { waitUntil: "load" });
  await page.waitForTimeout(400);
  const dest = resolve(afterDir, out);
  await page.screenshot({ path: dest, fullPage: true });
  console.log("wrote", dest);
}

await snap(sheetHtml("After 2 · phone", phone, 4), 1600, 1100, "contact-sheet-phone.png");
await snap(sheetHtml("After 2 · sheets and states", sheets, 4), 1600, 900, "contact-sheet-sheets.png");
await snap(sheetHtml("After 2 · desktop 1440", desktop, 2), 1600, 1100, "contact-sheet-desktop.png");

writeFileSync(
  resolve(afterDir, "index.html"),
  `<!doctype html><html><body>
  <p>See contact-sheet-phone.png, contact-sheet-sheets.png, contact-sheet-desktop.png</p>
  </body></html>`,
);

await browser.close();
console.log("contact sheets after2 done");
