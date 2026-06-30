// The resumemaxx wordmark — ASCII art (figlet "slant") rendered with a
// baby-blue → purple vertical+horizontal gradient.

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { rgb, lerp, fg, reset, dim as DIM, bold } from "./theme.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));

let _lines = null;
function artLines() {
  if (_lines) return _lines;
  let raw = "";
  try { raw = readFileSync(join(__dirname, "banner.txt"), "utf8"); } catch { raw = "resumemaxx"; }
  // Trim fully-blank leading/trailing rows.
  _lines = raw.replace(/\s+$/g, "").split("\n").filter((l) => l.trim().length || _lines);
  // drop leading blanks
  while (_lines.length && !_lines[0].trim()) _lines.shift();
  return _lines;
}

/** Big banner string. Diagonal gradient: blue top-left → purple bottom-right. */
export function banner() {
  const lines = artLines();
  const maxW = Math.max(...lines.map((l) => l.length), 1);
  const h = Math.max(1, lines.length - 1);
  return lines.map((line, row) => {
    let out = "";
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (ch === " ") { out += " "; continue; }
      // mix horizontal + vertical position for a diagonal feel
      const t = (i / (maxW - 1 || 1)) * 0.6 + (row / h) * 0.4;
      out += fg(lerp(rgb.blue, rgb.purple, Math.min(1, t))) + ch;
    }
    return out + reset;
  }).join("\n");
}

/** Number of rows the big banner occupies. */
export function bannerHeight() { return artLines().length; }

/** Compact one-line wordmark for tight spaces. */
export function wordmark(text = "resumemaxx") {
  const n = Math.max(1, text.length - 1);
  let out = "";
  for (let i = 0; i < text.length; i++) out += fg(lerp(rgb.blue, rgb.purple, i / n)) + text[i];
  return bold + out + reset;
}

/** Banner + subtitle, returned as a single string. */
export function splash(subtitle = "your résumé copilot") {
  return banner() + "\n" + DIM + fg(rgb.peri) + "  " + subtitle + reset;
}
