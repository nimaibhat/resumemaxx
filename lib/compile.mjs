// LaTeX compilation with build containment.
// All auxiliary junk (.aux/.log/.fls/.fdb_latexmk/.synctex.gz/.out) is written
// into a hidden build dir, NOT next to the source. The PDF is copied back out.

import { spawn } from "node:child_process";
import { mkdirSync, existsSync, copyFileSync, readdirSync, rmSync } from "node:fs";
import { dirname, basename, join, resolve } from "node:path";

// Aux extensions LaTeX scatters around. Used for hiding + cleaning.
export const JUNK_EXT = new Set([
  ".aux", ".log", ".fls", ".fdb_latexmk", ".synctex.gz", ".out",
  ".toc", ".lof", ".lot", ".bbl", ".blg", ".bcf", ".run.xml",
  ".idx", ".ilg", ".ind", ".nav", ".snm", ".vrb", ".dvi", ".auxlock",
]);

export function isJunk(filename) {
  // handle double ext like .synctex.gz
  for (const ext of JUNK_EXT) {
    if (filename.endsWith(ext)) return true;
  }
  return false;
}

export function buildDir(texPath) {
  return join(dirname(resolve(texPath)), ".resumemaxx", "build");
}

export function pdfPath(texPath) {
  const name = basename(texPath).replace(/\.tex$/, ".pdf");
  return join(buildDir(texPath), name);
}

/**
 * Compile a .tex into the contained build dir.
 * Resolves with { ok, pdf, log } — never rejects (so the watcher keeps running).
 */
export function compile(texPath) {
  return new Promise((res) => {
    const src = resolve(texPath);
    const dir = dirname(src);
    const out = buildDir(src);
    mkdirSync(out, { recursive: true });

    // latexmk keeps every intermediate inside -outdir/-auxdir.
    const args = [
      "-pdf",
      "-interaction=nonstopmode",
      "-halt-on-error",
      "-silent",
      `-outdir=${out}`,
      `-auxdir=${out}`,
      basename(src),
    ];
    const proc = spawn("latexmk", args, { cwd: dir });
    let log = "";
    proc.stdout.on("data", (d) => (log += d));
    proc.stderr.on("data", (d) => (log += d));
    proc.on("error", (err) =>
      res({ ok: false, pdf: null, log: `latexmk not found: ${err.message}` })
    );
    proc.on("close", (code) => {
      const produced = pdfPath(src);
      res({ ok: code === 0 && existsSync(produced), pdf: produced, log });
    });
  });
}

/**
 * Sweep stray aux files that already exist next to a source folder.
 * Returns the list of removed paths. Never touches .tex or .pdf.
 */
export function cleanDir(dir) {
  const removed = [];
  for (const name of readdirSync(dir)) {
    if (name.endsWith(".tex") || name.endsWith(".pdf")) continue;
    if (isJunk(name)) {
      rmSync(join(dir, name), { force: true });
      removed.push(name);
    }
  }
  return removed;
}
