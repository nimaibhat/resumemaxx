// tmux workspace: Claude Code on the left, live PDF preview on the right.
// Graphics passthrough is enabled so the inline image survives tmux.
//
// Navigation (shown in the bottom status bar):
//   F2            back to the file browser (keeps this workspace alive)
//   F4            quit resumemaxx
//   Ctrl-b ← →    switch panes (or click with the mouse)

import { spawnSync } from "node:child_process";
import { existsSync, rmSync } from "node:fs";
import { dirname, resolve, basename, join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CLI = resolve(__dirname, "..", "bin", "resumemaxx.mjs");

// Run on a dedicated tmux socket so our options and key bindings never leak
// into the user's normal tmux sessions.
const SOCK = ["-L", "resumemaxx"];

function tmux(args) {
  return spawnSync("tmux", [...SOCK, ...args], { stdio: "inherit" });
}
function tmuxQ(args) {
  return spawnSync("tmux", [...SOCK, ...args], { encoding: "utf8" });
}
function haveTmux() {
  return spawnSync("tmux", ["-V"], { encoding: "utf8" }).status === 0;
}
function sessionExists(name) {
  return spawnSync("tmux", [...SOCK, "has-session", "-t", name]).status === 0;
}

function sessionName(tex) {
  return "resumemaxx-" + basename(tex).replace(/\.tex$/, "").replace(/[^A-Za-z0-9_-]/g, "_");
}

// Configure the bottom status bar + global F-key navigation for a session.
function configureChrome(name, label, sentinel) {
  const set = (opt, val) => tmuxQ(["set-option", "-t", name, opt, val]);
  set("mouse", "on");
  set("status", "on");
  set("status-interval", "0");
  set("status-justify", "left");
  set("status-style", "bg=colour236,fg=colour250");
  set("message-style", "bg=colour236,fg=colour250");
  // Hide the window list so only our help text shows.
  set("window-status-format", "");
  set("window-status-current-format", "");
  set("status-left", `#[bg=colour30,fg=colour255,bold] resumemaxx #[bg=colour236,fg=colour250] ${label} `);
  set("status-left-length", "60");
  set("status-right",
    "#[fg=colour252,bold]F2#[fg=colour245] files  " +
    "#[fg=colour252,bold]F4#[fg=colour245] quit  " +
    "#[fg=colour252,bold]^b ←→#[fg=colour245] panes ");
  set("status-right-length", "60");

  // F2 -> detach (back to browser, session stays alive so Claude persists).
  tmuxQ(["set-option", "-t", name, "-g", "allow-passthrough", "on"]);
  tmuxQ(["bind-key", "-n", "F2", "detach-client"]);
  // F4 -> mark "quit" and tear down. The CLI checks the sentinel after attach.
  tmuxQ(["bind-key", "-n", "F4", "run-shell",
    `touch '${sentinel}'; tmux -L resumemaxx kill-session -t '${name}'`]);
}

/**
 * Launch (or reattach) the split workspace for a .tex file.
 * Blocks until the user leaves. Returns "quit" if they asked to exit the app,
 * otherwise "back" (returned to the browser).
 */
export function launchWorkspace(texPath) {
  const tex = resolve(texPath);
  const dir = dirname(tex);
  const name = sessionName(tex);
  const sentinel = join(tmpdir(), `${name}.quit`);
  if (existsSync(sentinel)) rmSync(sentinel, { force: true });

  if (!haveTmux()) {
    console.error(
      "resumemaxx needs tmux for the split workspace.\n" +
      "  Run:  resumemaxx setup        (installs everything on macOS)\n" +
      "  or:   brew install tmux"
    );
    return "back";
  }

  if (sessionExists(name)) {
    // Reattach — keeps the existing Claude session and its context.
    configureChrome(name, basename(tex), sentinel);
    tmux(["attach-session", "-t", name]);
  } else {
    const r = tmuxQ(["new-session", "-d", "-s", name, "-c", dir]);
    if (r.status !== 0) {
      console.error("failed to create tmux session:\n" + (r.stderr || ""));
      return "back";
    }
    configureChrome(name, basename(tex), sentinel);

    const previewCmd = `node ${JSON.stringify(CLI)} _preview ${JSON.stringify(tex)}`;
    // Right pane (~52%) = live preview.
    tmuxQ(["split-window", "-h", "-p", "52", "-t", `${name}:0`, "-c", dir]);
    tmuxQ(["send-keys", "-t", `${name}:0.1`, previewCmd, "Enter"]);
    // Left pane = Claude Code, focused.
    tmuxQ(["send-keys", "-t", `${name}:0.0`, "claude", "Enter"]);
    tmuxQ(["select-pane", "-t", `${name}:0.0`]);

    tmux(["attach-session", "-t", name]);
  }

  const quit = existsSync(sentinel);
  if (quit) rmSync(sentinel, { force: true });
  return quit ? "quit" : "back";
}

/** Kill any lingering resumemaxx workspaces (called when the app exits). */
export function killWorkspaces() {
  const r = tmuxQ(["list-sessions", "-F", "#{session_name}"]);
  if (r.status !== 0 || !r.stdout) return;
  for (const s of r.stdout.split("\n")) {
    if (s.startsWith("resumemaxx-")) tmuxQ(["kill-session", "-t", s]);
  }
}
