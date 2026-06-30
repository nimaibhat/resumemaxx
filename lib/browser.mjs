// Zero-dependency interactive file browser.
// Navigate the folder tree, hide LaTeX junk, pick a resume to open.
// Resolves with { action: "open-tex" | "preview-pdf", path } or null on quit.

import { readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname, basename, resolve, extname } from "node:path";
import { isJunk, cleanDir, pdfPath } from "./compile.mjs";

const C = {
  reset: "\x1b[0m", dim: "\x1b[2m", bold: "\x1b[1m",
  cyan: "\x1b[36m", blue: "\x1b[34m", green: "\x1b[32m",
  yellow: "\x1b[33m", magenta: "\x1b[35m", gray: "\x1b[90m",
  invCyan: "\x1b[46m\x1b[30m", red: "\x1b[31m",
};

function listDir(dir) {
  let names;
  try { names = readdirSync(dir); } catch { return []; }
  const entries = [];
  for (const name of names) {
    if (name.startsWith(".")) continue;       // hide dotfiles incl .resumemaxx
    if (isJunk(name)) continue;               // hide LaTeX aux junk
    const full = join(dir, name);
    let st;
    try { st = statSync(full); } catch { continue; }
    const isDir = st.isDirectory();
    const ext = extname(name).toLowerCase();
    // In the browser we only surface dirs, .tex and .pdf.
    if (!isDir && ext !== ".tex" && ext !== ".pdf") continue;
    entries.push({ name, full, isDir, ext });
  }
  entries.sort((a, b) => {
    if (a.isDir !== b.isDir) return a.isDir ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
  return entries;
}

function icon(e) {
  if (e.isDir) return `${C.blue}▸ ${C.reset}`;
  if (e.ext === ".tex") {
    const built = existsSync(pdfPath(e.full));
    return built ? `${C.green}● ${C.reset}` : `${C.yellow}○ ${C.reset}`;
  }
  return `${C.magenta}▭ ${C.reset}`;
}

export function runBrowser(startDir = process.cwd()) {
  return new Promise((resolveP) => {
    let cwd = resolve(startDir);
    let entries = listDir(cwd);
    let idx = 0;
    let top = 0;
    let filter = "";
    let filtering = false;
    let message = "";

    const out = process.stdout;
    const view = () => entries.filter((e) =>
      !filter || e.name.toLowerCase().includes(filter.toLowerCase()));

    function rows() { return (out.rows || 24); }

    function render() {
      const v = view();
      if (idx >= v.length) idx = Math.max(0, v.length - 1);
      const listH = rows() - 6;
      if (idx < top) top = idx;
      if (idx >= top + listH) top = idx - listH + 1;

      let s = "\x1b[2J\x1b[H";
      s += `${C.bold}${C.cyan} resumemaxx ${C.reset}${C.dim}— resume workspace${C.reset}\n`;
      s += `${C.gray} ${cwd}${C.reset}\n`;
      s += `${C.gray} ${"─".repeat(Math.min((out.columns || 80) - 2, 78))}${C.reset}\n`;

      const slice = v.slice(top, top + listH);
      if (slice.length === 0) {
        s += `${C.dim}   (empty)${C.reset}\n`;
      }
      slice.forEach((e, i) => {
        const real = top + i;
        const sel = real === idx;
        const label = e.isDir ? e.name + "/" : e.name;
        const line = ` ${icon(e)}${label}`;
        s += sel ? `${C.invCyan}${stripFit(line, out.columns)}${C.reset}\n`
                 : `${line}\n`;
      });

      // pad
      for (let i = slice.length; i < listH; i++) s += "\n";

      s += `${C.gray} ${"─".repeat(Math.min((out.columns || 80) - 2, 78))}${C.reset}\n`;
      if (filtering) {
        s += `${C.yellow} /${filter}${C.reset}${C.dim}  (type to filter · enter/esc done)${C.reset}`;
      } else if (message) {
        s += `${C.green} ${message}${C.reset}`;
      } else {
        s += `${C.dim} ↑↓ move  ↵ open  ← up  / filter  c clean  q quit${C.reset}`;
      }
      out.write(s);
    }

    function stripFit(line, cols) {
      // keep selection bar from wrapping
      const max = (cols || 80) - 1;
      // naive length ignoring ansi (line has no ansi except icon color)
      return line.length > max ? line.slice(0, max) : line;
    }

    function refresh() { entries = listDir(cwd); idx = 0; top = 0; }

    function open() {
      const v = view();
      const e = v[idx];
      if (!e) return;
      if (e.isDir) {
        cwd = e.full; filter = ""; refresh(); message = ""; render(); return;
      }
      if (e.ext === ".tex") { return done({ action: "open-tex", path: e.full }); }
      if (e.ext === ".pdf") { return done({ action: "preview-pdf", path: e.full }); }
    }

    function parent() {
      const up = dirname(cwd);
      if (up !== cwd) { cwd = up; filter = ""; refresh(); message = ""; render(); }
    }

    function teardown() {
      process.stdin.setRawMode?.(false);
      process.stdin.pause();
      process.stdin.removeListener("data", onData);
      out.removeListener("resize", render);
    }

    function done(result) { teardown(); out.write("\x1b[2J\x1b[H"); resolveP(result); }

    function onData(buf) {
      const k = buf.toString();

      if (filtering) {
        if (k === "\r" || k === "\n" || k === "\x1b") { filtering = false; render(); return; }
        if (k === "\x7f") { filter = filter.slice(0, -1); idx = 0; render(); return; }
        if (k >= " " && k.length === 1) { filter += k; idx = 0; render(); return; }
        return;
      }

      switch (k) {
        case "\x03": // Ctrl-C
        case "q":
          return done(null);
        case "\x1b[A": case "k": idx = Math.max(0, idx - 1); break;
        case "\x1b[B": case "j": idx = Math.min(view().length - 1, idx + 1); break;
        case "\x1b[D": case "h": return parent();
        case "\x1b[C": case "\r": case "\n": case "l": return open();
        case "\x7f": return parent();
        case "/": filtering = true; filter = ""; break;
        case "g": idx = 0; break;
        case "G": idx = view().length - 1; break;
        case "c": {
          const removed = cleanDir(cwd);
          message = removed.length
            ? `cleaned ${removed.length} junk file(s)`
            : "nothing to clean";
          refreshKeepCwd();
          break;
        }
        default: return;
      }
      render();
    }

    function refreshKeepCwd() { const i = idx; entries = listDir(cwd); idx = Math.min(i, view().length - 1); }

    process.stdin.setRawMode?.(true);
    process.stdin.resume();
    process.stdin.on("data", onData);
    out.on("resize", render);
    out.write("\x1b[?25l"); // hide cursor
    render();
  });
}
