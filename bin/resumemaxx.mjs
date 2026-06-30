#!/usr/bin/env node
// resumemaxx — a terminal workspace for resumes.
//   resumemaxx              open the file browser in the current directory
//   resumemaxx <dir>        open the browser in <dir>
//   resumemaxx <file.tex>   jump straight into the split workspace
//   resumemaxx clean [dir]  sweep stray LaTeX junk from a folder
//   resumemaxx doctor       check that all dependencies are installed
//   resumemaxx setup        install everything (macOS)
//   resumemaxx --help

import { statSync, existsSync } from "node:fs";
import { resolve, extname, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { runBrowser } from "../lib/browser.mjs";
import { launchWorkspace, killWorkspaces } from "../lib/workspace.mjs";
import { startPreview, viewPdf } from "../lib/preview.mjs";
import { cleanDir } from "../lib/compile.mjs";
import { report, check } from "../lib/doctor.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));

const args = process.argv.slice(2);
const cmd = args[0];

function help() {
  process.stdout.write(`
  resumemaxx — Claude Code on the left, your resume on the right.

  Usage:
    resumemaxx                 browse the current folder
    resumemaxx <dir>           browse a folder
    resumemaxx <file.tex>      open the split workspace for a resume
    resumemaxx clean [dir]     remove stray LaTeX aux files (.aux/.log/.fls/…)
    resumemaxx doctor          check dependencies
    resumemaxx setup           install everything (macOS)
    resumemaxx --help

  In the browser:
    ↑↓ / j k   move        ↵ open       ← parent folder
    /          filter      c clean      ^X / q quit

  In the workspace (tmux — Claude left, live preview right):
    ^X         back to the file browser     ^b ←→  switch panes (or click)
    Focus the preview pane (click it), then:
      + / -    zoom            0       reset to fit
      ← ↑ ↓ →  scroll          [ ]     prev / next page

  Requires tmux, chafa, and a graphics terminal (Ghostty/kitty).
`);
}

async function browseLoop(dir) {
  // Loop: browse -> pick -> workspace/preview -> back to browse.
  try {
    for (;;) {
      const pick = await runBrowser(dir);
      if (!pick) break; // Ctrl-X / q quits the app
      if (pick.action === "open-tex") {
        launchWorkspace(pick.path); // returns on Ctrl-X (back to browser)
        dir = resolve(pick.path, "..");
      } else if (pick.action === "preview-pdf") {
        await viewPdf(pick.path);
        dir = resolve(pick.path, "..");
      }
    }
  } finally {
    killWorkspaces(); // tidy up any lingering tmux sessions on exit
  }
}

async function main() {
  if (cmd === "--help" || cmd === "-h") return help();

  // Internal command used by the tmux preview pane.
  if (cmd === "_preview") {
    const tex = args[1];
    if (!tex) { console.error("_preview needs a .tex path"); process.exit(1); }
    return startPreview(resolve(tex));
  }

  // Internal: the branded resumemaxx assistant (Claude Code under the hood).
  if (cmd === "_assistant") {
    const tex = args[1] ? resolve(args[1]) : null;
    const name = tex ? tex.split("/").pop() : "your résumé";
    const persona =
      `You are resumemaxx — a focused résumé assistant embedded in a terminal ` +
      `workspace. You help the user write and refine their LaTeX résumé (${name}). ` +
      `Keep replies concise and concrete: make bullet points impact- and metric-driven, ` +
      `fix LaTeX issues, and preserve the document's clean formatting and one-page layout. ` +
      `The compiled PDF preview is shown live in the pane to the right and refreshes ` +
      `whenever the .tex is saved.`;
    const settings = JSON.stringify({
      statusLine: { type: "command", command: `printf ' ✦ resumemaxx · %s · résumé copilot ' ${JSON.stringify(name)}` },
    });
    const r = spawnSync("claude", [
      "--append-system-prompt", persona,
      "--settings", settings,
    ], { stdio: "inherit" });
    process.exit(r.status ?? 0);
  }

  if (cmd === "doctor") {
    process.exit(report() ? 0 : 1);
  }

  if (cmd === "setup") {
    const script = join(__dirname, "..", "scripts", "setup-macos.sh");
    const r = spawnSync("bash", [script], { stdio: "inherit" });
    process.exit(r.status ?? 1);
  }

  if (cmd === "clean") {
    const dir = resolve(args[1] || ".");
    const removed = cleanDir(dir);
    console.log(removed.length
      ? `Removed ${removed.length} junk file(s):\n  ${removed.join("\n  ")}`
      : "No LaTeX junk found.");
    return;
  }

  // Everything past here is interactive and needs the toolchain.
  const { missingRequired } = check();
  if (missingRequired.length) {
    report();
    process.exit(1);
  }

  // No command, or a path argument.
  if (!cmd) return browseLoop(process.cwd());

  const target = resolve(cmd);
  if (!existsSync(target)) {
    console.error(`not found: ${cmd}`);
    process.exit(1);
  }
  const st = statSync(target);
  if (st.isDirectory()) return browseLoop(target);
  if (extname(target) === ".tex") { launchWorkspace(target); return; }
  if (extname(target) === ".pdf") { await viewPdf(target); return; }
  console.error(`don't know how to open: ${cmd}`);
  process.exit(1);
}

main();
