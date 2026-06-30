#!/usr/bin/env node
// Standalone preview tester:  node bin/preview-test.mjs <file.tex>
import { startPreview } from "../lib/preview.mjs";

const tex = process.argv[2];
if (!tex) {
  console.error("usage: node bin/preview-test.mjs <file.tex>");
  process.exit(1);
}
startPreview(tex);
