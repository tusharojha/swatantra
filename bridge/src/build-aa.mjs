import * as esbuild from "esbuild";
import { polyfillNode } from "esbuild-plugin-polyfill-node";

await esbuild.build({
  entryPoints: ["src/aa-prove.ts"],
  bundle: true,
  format: "iife",
  platform: "browser",
  outfile: "../app/web/aa_prove.js",
  legalComments: "none",
  banner: {
    js: "var process={env:{}};",
  },
  plugins: [polyfillNode()],
  logLevel: "info",
});
