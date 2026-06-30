// Live preview engine: watch a .tex, recompile on change, render the PDF
// inline as an image. Designed to own a single terminal pane.

import { spawn } from "node:child_process";
import { watch } from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { compile, pdfPath } from "./compile.mjs";
import { renderPng, clearImages, graphicsSupported } from "./kitty.mjs";

const DPI = process.env.RESUMEMAXX_DPI || "150";

function termSize() {
  return {
    cols: process.stdout.columns || 80,
    rows: process.stdout.rows || 24,
  };
}

// Render PDF page 1 -> PNG in a temp dir, then draw it.
function pdfToPng(pdf, outBase) {
  return new Promise((res) => {
    const proc = spawn("pdftoppm", [
      "-png", "-r", DPI, "-singlefile", "-f", "1", "-l", "1", pdf, outBase,
    ]);
    proc.on("error", () => res(null));
    proc.on("close", (code) => res(code === 0 ? `${outBase}.png` : null));
  });
}

function status(msg) {
  // Move to home, clear, print a status line at top.
  process.stdout.write("\x1b[H\x1b[2K");
  process.stdout.write(msg + "\n");
}

export async function startPreview(texPath) {
  const tmp = mkdtempSync(join(tmpdir(), "resumemaxx-"));
  let pngCounter = 0;
  let compiling = false;
  let queued = false;

  if (!graphicsSupported()) {
    console.error(
      "⚠  This terminal may not support inline images (kitty graphics).\n" +
        "   Preview works best in Ghostty or kitty."
    );
  }

  async function draw() {
    const png = await pdfToPng(pdfPath(texPath), join(tmp, `p${pngCounter++}`));
    if (!png) return;
    const { rows } = termSize();
    process.stdout.write("\x1b[2J\x1b[H"); // clear screen
    clearImages();
    // Constrain ONLY height -> terminal computes width to preserve the page's
    // true aspect ratio (no stretching). Leave 1 row for status.
    renderPng(png, { rows: Math.max(1, rows - 1) });
  }

  async function rebuild() {
    if (compiling) { queued = true; return; }
    compiling = true;
    status("⟳ compiling…");
    const r = await compile(texPath);
    compiling = false;
    if (r.ok) {
      await draw();
    } else {
      process.stdout.write("\x1b[2J\x1b[H");
      const tail = (r.log || "").split("\n").filter(Boolean).slice(-15).join("\n");
      process.stdout.write("✗ compile failed:\n\n" + tail + "\n");
    }
    if (queued) { queued = false; rebuild(); }
  }

  process.stdout.write("\x1b[?25l"); // hide cursor
  await rebuild();

  // Debounced file watch.
  let t = null;
  const w = watch(texPath, () => {
    clearTimeout(t);
    t = setTimeout(rebuild, 250);
  });

  // Redraw on terminal resize.
  process.stdout.on("resize", () => { if (!compiling) draw(); });

  const cleanup = () => {
    process.stdout.write("\x1b[?25h\x1b[2J\x1b[H"); // show cursor, clear
    w.close();
    process.exit(0);
  };
  process.on("SIGINT", cleanup);
  process.on("SIGTERM", cleanup);
}

/**
 * Render an already-built PDF inline and wait for a keypress to return.
 * Used when a .pdf (not .tex) is opened from the browser.
 */
export function viewPdf(pdf) {
  return new Promise(async (res) => {
    const tmp = mkdtempSync(join(tmpdir(), "resumemaxx-"));
    const png = await pdfToPng(pdf, join(tmp, "view"));
    process.stdout.write("\x1b[2J\x1b[H\x1b[?25l");
    if (png) {
      const { rows } = termSize();
      clearImages();
      renderPng(png, { rows: Math.max(1, rows - 1) });
    } else {
      process.stdout.write("could not render PDF\n");
    }
    const onKey = () => finish();
    function finish() {
      process.stdin.setRawMode?.(false);
      process.stdin.pause();
      process.stdin.removeListener("data", onKey);
      process.stdout.write("\x1b[2J\x1b[H\x1b[?25h");
      res();
    }
    process.stdin.setRawMode?.(true);
    process.stdin.resume();
    process.stdin.once("data", onKey);
  });
}
