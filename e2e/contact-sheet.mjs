import { readdirSync, mkdirSync } from "node:fs";
import { resolve, basename } from "node:path";
import { chromium } from "playwright";

const root = resolve("..");
const beforeDir = resolve(root, "artifacts/audit/before");
const afterDir = resolve(root, "artifacts/audit/after");
const outDir = resolve(root, "artifacts/audit");
mkdirSync(outDir, { recursive: true });

const afterFiles = readdirSync(afterDir).filter((f) => f.endsWith(".png")).sort();
const pairs = afterFiles
  .map((f) => ({ name: f, before: resolve(beforeDir, f), after: resolve(afterDir, f) }))
  .filter((p) => {
    try {
      readdirSync(beforeDir).includes(p.name);
      return true;
    } catch {
      return false;
    }
  });

const browser = await chromium.launch({ args: ["--no-sandbox", "--disable-gpu"] });
const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });

function grid(files, title) {
  const cells = files
    .map(
      (f) => `<figure>
        <img src="${f}"/>
        <figcaption>${basename(f)}</figcaption>
      </figure>`,
    )
    .join("");
  return `<!doctype html><html><head><meta charset="utf-8"><title>${title}</title>
  <style>
    body { font-family: Inter, sans-serif; background: #f6f5f2; color: #111; margin: 24px; }
    h1 { font-family: Georgia, serif; font-size: 28px; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
    figure { margin: 0; background: #fff; border: 1px solid #e6e4df; border-radius: 12px; overflow: hidden; }
    img { width: 100%; display: block; }
    figcaption { font-size: 12px; padding: 8px 12px; color: #5c5c5c; }
    .pair { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 24px; }
  </style></head><body><h1>${title}</h1>${cells}</body></html>`;
}

const pairHtml = `<!doctype html><html><head><meta charset="utf-8"><title>Before / after</title>
<style>
  body { font-family: Inter, sans-serif; background: #f6f5f2; color: #111; margin: 24px; }
  h1 { font-family: Georgia, serif; }
  h2 { font-size: 14px; letter-spacing: 0.08em; text-transform: uppercase; color: #dc2460; }
  .pair { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 28px; }
  figure { margin: 0; background: #fff; border: 1px solid #e6e4df; border-radius: 12px; overflow: hidden; }
  img { width: 100%; display: block; }
  figcaption { font-size: 12px; padding: 8px 12px; color: #5c5c5c; }
</style></head><body>
<h1>Swatantra — before / after</h1>
${afterFiles
  .map((f) => {
    const b = `before/${f}`;
    const a = `after/${f}`;
    return `<h2>${f.replace(".png", "")}</h2>
    <div class="pair">
      <figure><img src="${b}"/><figcaption>Before</figcaption></figure>
      <figure><img src="${a}"/><figcaption>After</figcaption></figure>
    </div>`;
  })
  .join("")}
</body></html>`;

await page.setContent(pairHtml, { waitUntil: "load" });
for (const img of await page.locator("img").all()) {
  await img.evaluate((el) => {
    const src = el.getAttribute("src");
    if (src && !src.startsWith("file:") && !src.startsWith("http") && !src.startsWith("data:")) {
      /* filled below */
    }
  });
}

const { readFileSync, existsSync } = await import("node:fs");
const toData = (p) => {
  if (!existsSync(p)) return "";
  const buf = readFileSync(p);
  return `data:image/png;base64,${buf.toString("base64")}`;
};

const pairData = `<!doctype html><html><head><meta charset="utf-8"><title>Before / after</title>
<style>
  body { font-family: Inter, sans-serif; background: #f6f5f2; color: #111; margin: 24px; }
  h1 { font-family: Georgia, serif; }
  h2 { font-size: 13px; letter-spacing: 0.1em; text-transform: uppercase; color: #dc2460; margin: 28px 0 8px; }
  .pair { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; page-break-inside: avoid; }
  figure { margin: 0; background: #fff; border: 1px solid #e6e4df; border-radius: 12px; overflow: hidden; }
  img { width: 100%; display: block; }
  figcaption { font-size: 12px; padding: 8px 12px; color: #5c5c5c; }
</style></head><body>
<h1>Swatantra — before / after</h1>
${afterFiles
  .map((f) => {
    const b = toData(resolve(beforeDir, f));
    const a = toData(resolve(afterDir, f));
    return `<h2>${f.replace(".png", "")}</h2>
    <div class="pair">
      <figure><img src="${b}"/><figcaption>Before</figcaption></figure>
      <figure><img src="${a}"/><figcaption>After</figcaption></figure>
    </div>`;
  })
  .join("")}
</body></html>`;

await page.setViewportSize({ width: 1400, height: 900 });
await page.setContent(pairData, { waitUntil: "load" });
await page.waitForTimeout(500);
const contact = resolve(outDir, "contact-sheet.png");
await page.screenshot({ path: contact, fullPage: true });
console.log("wrote", contact);

const phoneAfter = afterFiles.filter((f) => f.startsWith("phone-"));
const phoneData = `<!doctype html><html><head><meta charset="utf-8">
<style>
  body { font-family: Inter, sans-serif; background: #111; color: #fff; margin: 16px; }
  h1 { font-family: Georgia, serif; font-size: 22px; }
  .grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
  figure { margin: 0; background: #1a1a1a; border-radius: 10px; overflow: hidden; }
  img { width: 100%; display: block; }
  figcaption { font-size: 11px; padding: 6px 8px; color: #bbb; }
</style></head><body><h1>After · phone</h1>
<div class="grid">${phoneAfter
  .map((f) => `<figure><img src="${toData(resolve(afterDir, f))}"/><figcaption>${f.replace("phone-", "").replace(".png", "")}</figcaption></figure>`)
  .join("")}</div></body></html>`;
await page.setContent(phoneData, { waitUntil: "load" });
await page.setViewportSize({ width: 1600, height: 1100 });
await page.screenshot({ path: resolve(outDir, "contact-sheet-after-phone.png"), fullPage: true });

await browser.close();
console.log("contact sheets done");
