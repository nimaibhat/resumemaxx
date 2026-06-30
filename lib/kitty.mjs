// Minimal Kitty graphics protocol writer.
// Renders a PNG to the terminal inline. Works in Ghostty, kitty, and
// (with passthrough) inside tmux. Falls back gracefully elsewhere.

import { readFileSync } from "node:fs";

const ESC = "\x1b";
const CHUNK = 4096; // base64 chars per escape, per kitty spec guidance

// Wrap a payload for tmux passthrough if we're inside tmux.
// tmux requires DCS passthrough with doubled ESCs and `allow-passthrough on`.
function wrap(seq) {
  if (process.env.TMUX) {
    return `${ESC}Ptmux;${seq.replace(/\x1b/g, ESC + ESC)}${ESC}\\`;
  }
  return seq;
}

/**
 * Delete all images currently placed by us (clears the pane region).
 */
export function clearImages(out = process.stdout) {
  out.write(wrap(`${ESC}_Ga=d,d=A${ESC}\\`));
}

/**
 * Display a PNG file inline.
 * @param {string} pngPath  path to a PNG on disk
 * @param {object} opts
 * @param {number} [opts.cols]  place into this many terminal columns
 * @param {number} [opts.rows]  place into this many terminal rows
 * @param {WriteStream} [opts.out]
 */
export function renderPng(pngPath, opts = {}) {
  const out = opts.out || process.stdout;
  const data = readFileSync(pngPath);
  const b64 = data.toString("base64");

  // Control keys: f=100 (PNG), a=T (transmit+display), q=2 (suppress responses).
  // c/r place the image into a fixed cell box and scale to fit.
  const ctrl = [`f=100`, `a=T`, `q=2`];
  if (opts.cols) ctrl.push(`c=${opts.cols}`);
  if (opts.rows) ctrl.push(`r=${opts.rows}`);

  if (b64.length <= CHUNK) {
    out.write(wrap(`${ESC}_G${ctrl.join(",")};${b64}${ESC}\\`));
    return;
  }

  // Chunked transfer: first chunk carries control keys + m=1, last has m=0.
  let i = 0;
  let first = true;
  while (i < b64.length) {
    const piece = b64.slice(i, i + CHUNK);
    i += CHUNK;
    const more = i < b64.length ? 1 : 0;
    const keys = first ? `${ctrl.join(",")},m=${more}` : `m=${more}`;
    out.write(wrap(`${ESC}_G${keys};${piece}${ESC}\\`));
    first = false;
  }
}

/**
 * Best-effort detection of whether the terminal supports kitty graphics.
 */
export function graphicsSupported() {
  const tp = process.env.TERM_PROGRAM || "";
  const term = process.env.TERM || "";
  if (/ghostty|kitty|wezterm/i.test(tp)) return true;
  if (/kitty/i.test(term)) return true;
  if (process.env.KITTY_WINDOW_ID) return true;
  // Inside tmux TERM becomes screen/tmux and TERM_PROGRAM may not propagate.
  // resumemaxx only spawns tmux when it intends to render graphics, so the
  // outer terminal is assumed capable; passthrough handles delivery.
  if (process.env.TMUX) return true;
  return false;
}
