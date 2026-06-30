// Live preview engine: watch a .tex, recompile on change, and render the PDF
// inline. The pane is interactive — focus it (click, or Ctrl-b →) and:
//   + / -      zoom in / out          0     reset to fit
//   ← ↑ ↓ →    scroll (when zoomed)    [ ]   previous / next page
// hjkl also scroll. View state survives recompiles.

import { spawnSync, spawn } from "node:child_process";
import { watch, mkdtempSync, copyFileSync, renameSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { compile, pdfPath } from "./compile.mjs";
import { graphicsSupported } from "./kitty.mjs";
import { renderImage } from "./render.mjs";

const BASE_DPI = Number(process.env.RESUMEMAXX_DPI || 150); // full page = this DPI
const ZMAX = 4;          // max zoom factor
const ZSTEP = 1.25;      // zoom multiplier per keypress
const PAN = 0.12;        // scroll step as a fraction of the page

function termSize() {
  return { cols: process.stdout.columns || 80, rows: process.stdout.rows || 24 };
}

// Parse `pdfinfo` for page count and the first page's size in points.
function pdfInfo(pdf) {
  const r = spawnSync("pdfinfo", [pdf], { encoding: "utf8" });
  let pages = 1, wPt = 612, hPt = 792;
  if (r.status === 0) {
    const p = r.stdout.match(/Pages:\s+(\d+)/);
    if (p) pages = Number(p[1]);
    const s = r.stdout.match(/Page size:\s+([\d.]+)\s+x\s+([\d.]+)/);
    if (s) { wPt = Number(s[1]); hPt = Number(s[2]); }
  }
  return { pages, wPt, hPt };
}

// Render a region of one page to PNG. zoom=1 renders the whole page.
function renderRegion(pdf, { page, zoom, ox, oy, wPt, hPt }, outBase) {
  return new Promise((res) => {
    const dpi = Math.round(BASE_DPI * zoom);
    const winW = Math.round((wPt / 72) * BASE_DPI); // constant viewport px
    const winH = Math.round((hPt / 72) * BASE_DPI);
    const fullW = Math.round((wPt / 72) * dpi);
    const fullH = Math.round((hPt / 72) * dpi);
    const x = Math.round(ox * Math.max(0, fullW - winW));
    const y = Math.round(oy * Math.max(0, fullH - winH));
    const args = [
      "-png", "-r", String(dpi),
      "-f", String(page), "-l", String(page),
      "-x", String(x), "-y", String(y), "-W", String(winW), "-H", String(winH),
      "-singlefile", pdf, outBase,
    ];
    const proc = spawn("pdftoppm", args);
    proc.on("error", () => res(null));
    proc.on("close", (code) => res(code === 0 ? `${outBase}.png` : null));
  });
}

// Shared interactive viewer over a PDF that may be recompiled underneath it.
function makeViewer(tmp) {
  let st = { page: 1, zoom: 1, ox: 0, oy: 0 };
  let info = { pages: 1, wPt: 612, hPt: 792 };
  let pdf = null;
  let counter = 0;
  let busy = false, again = false;

  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

  function statusLine() {
    const z = Math.round(st.zoom * 100);
    const pg = info.pages > 1 ? `p${st.page}/${info.pages} · ` : "";
    const hint = st.zoom > 1 ? "←↑↓→ scroll · " : "";
    return `\x1b[2m ${pg}${z}%  +/- zoom · ${hint}0 fit${info.pages > 1 ? " · [ ] page" : ""} · click to focus\x1b[0m`;
  }

  async function draw() {
    if (!pdf) return;
    if (busy) { again = true; return; }
    busy = true;
    const png = await renderRegion(pdf, { ...st, wPt: info.wPt, hPt: info.hPt },
      join(tmp, `v${counter++ % 4}`));
    busy = false;
    if (png) {
      const { cols, rows } = termSize();
      process.stdout.write("\x1b[2J\x1b[H");
      renderImage(png, { cols, rows: Math.max(1, rows - 1) });
      process.stdout.write(`\x1b[${rows};1H${statusLine()}`);
    }
    if (again) { again = false; draw(); }
  }

  function setPdf(srcPdf) {
    // Snapshot the PDF atomically (write temp + rename) so a render never reads
    // the build file while latexmk is rewriting it — that's what caused the
    // occasional all-white page during live recompiles.
    const stable = join(tmp, "current.pdf");
    try {
      const tmpf = join(tmp, "current.pdf.new");
      copyFileSync(srcPdf, tmpf);
      renameSync(tmpf, stable);
      pdf = stable;
    } catch {
      pdf = srcPdf; // fall back to the live file if the copy fails
    }
    info = pdfInfo(pdf);
    st.page = clamp(st.page, 1, info.pages);
    draw();
  }

  function onKey(k) {
    if (!pdf) return;
    const before = JSON.stringify(st);
    switch (k) {
      case "+": case "=": st.zoom = clamp(st.zoom * ZSTEP, 1, ZMAX); break;
      case "-": case "_": st.zoom = clamp(st.zoom / ZSTEP, 1, ZMAX); break;
      case "0": st = { ...st, zoom: 1, ox: 0, oy: 0 }; break;
      case "\x1b[D": case "h": st.ox = clamp(st.ox - PAN, 0, 1); break;
      case "\x1b[C": case "l": st.ox = clamp(st.ox + PAN, 0, 1); break;
      case "\x1b[A": case "k": st.oy = clamp(st.oy - PAN, 0, 1); break;
      case "\x1b[B": case "j": st.oy = clamp(st.oy + PAN, 0, 1); break;
      case "]": case ".": case "n": st.page = clamp(st.page + 1, 1, info.pages); st.oy = 0; break;
      case "[": case ",": case "p": st.page = clamp(st.page - 1, 1, info.pages); st.oy = 0; break;
      default: return;
    }
    if (JSON.stringify(st) !== before) draw();
  }

  return { setPdf, draw, onKey };
}

export async function startPreview(texPath) {
  const tmp = mkdtempSync(join(tmpdir(), "resumemaxx-"));
  const viewer = makeViewer(tmp);
  let compiling = false, queued = false;

  if (!graphicsSupported()) {
    console.error("⚠  Inline images need a graphics terminal (Ghostty/kitty).");
  }

  function status(msg) { process.stdout.write("\x1b[H\x1b[2K" + msg + "\n"); }

  async function rebuild() {
    if (compiling) { queued = true; return; }
    compiling = true;
    status("⟳ compiling…");
    const r = await compile(texPath);
    compiling = false;
    if (r.ok) {
      viewer.setPdf(r.pdf);
    } else {
      process.stdout.write("\x1b[2J\x1b[H");
      const tail = (r.log || "").split("\n").filter(Boolean).slice(-15).join("\n");
      process.stdout.write("✗ compile failed:\n\n" + tail + "\n");
    }
    if (queued) { queued = false; rebuild(); }
  }

  process.stdout.write("\x1b[?25l"); // hide cursor
  await rebuild();

  let t = null;
  const w = watch(texPath, () => { clearTimeout(t); t = setTimeout(rebuild, 250); });
  process.stdout.on("resize", () => { if (!compiling) viewer.draw(); });

  // Interactive keys (only delivered when this pane is focused).
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on("data", (b) => {
      const k = b.toString();
      if (k === "\x03") return cleanup(); // Ctrl-C
      viewer.onKey(k);
    });
  }

  function cleanup() {
    process.stdout.write("\x1b[?25h\x1b[2J\x1b[H");
    process.stdin.setRawMode?.(false);
    w.close();
    process.exit(0);
  }
  process.on("SIGINT", cleanup);
  process.on("SIGTERM", cleanup);
}

/**
 * View an already-built PDF interactively (zoom/scroll/pages). Press q or
 * Ctrl-C / Ctrl-X to return. Used when a .pdf is opened from the browser.
 */
export function viewPdf(pdf) {
  return new Promise((res) => {
    const tmp = mkdtempSync(join(tmpdir(), "resumemaxx-"));
    const viewer = makeViewer(tmp);
    process.stdout.write("\x1b[2J\x1b[H\x1b[?25l");
    viewer.setPdf(pdf);
    function finish() {
      process.stdin.setRawMode?.(false);
      process.stdin.pause();
      process.stdin.removeListener("data", onData);
      process.stdout.write("\x1b[2J\x1b[H\x1b[?25h");
      res();
    }
    function onData(b) {
      const k = b.toString();
      if (k === "q" || k === "\x03" || k === "\x18") return finish(); // q / Ctrl-C / Ctrl-X
      viewer.onKey(k);
    }
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(true);
      process.stdin.resume();
      process.stdin.on("data", onData);
    }
    process.stdout.on("resize", () => viewer.draw());
  });
}
