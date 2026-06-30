// tmux workspace: Claude Code on the left, live PDF preview on the right.
// Graphics passthrough is enabled so the inline image survives tmux.
//
// Navigation (shown in the bottom status bar):
//   Ctrl-X        back to the file browser (keeps this workspace alive, so
//                 reopening reattaches with Claude's context intact)
//   Ctrl-b ← →    switch panes (or click with the mouse)

import { spawnSync } from "node:child_process";
import { dirname, resolve, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { hex } from "./theme.mjs";

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

// Configure the branded chrome + Ctrl-X navigation for a session.
function configureChrome(name, label) {
  const set = (opt, val) => tmuxQ(["set-option", "-t", name, opt, val]);
  // Truecolor so the baby-blue/purple palette renders accurately.
  tmuxQ(["set-option", "-g", "terminal-overrides", ",*:Tc"]);
  // "all" (not "on") forwards graphics passthrough even for INACTIVE panes —
  // without it the preview only appears once you click/focus its pane.
  tmuxQ(["set-option", "-t", name, "-g", "allow-passthrough", "all"]);

  set("mouse", "on");
  set("status", "on");
  set("status-interval", "0");
  set("status-justify", "left");
  set("status-style", `bg=${hex.bg},fg=${hex.text}`);
  set("message-style", `bg=${hex.bg2},fg=${hex.lilac}`);
  set("window-status-format", "");
  set("window-status-current-format", "");
  set("status-left",
    `#[bg=${hex.blue},fg=${hex.ink},bold] resumemaxx #[bg=${hex.bg},fg=${hex.lilac}] ${label} `);
  set("status-left-length", "60");
  set("status-right",
    `#[fg=${hex.lilac},bold]^X#[fg=${hex.dim}] back to files  ` +
    `#[fg=${hex.lilac},bold]^b ←→#[fg=${hex.dim}] panes  ` +
    `#[fg=${hex.dim}]click preview to zoom `);
  set("status-right-length", "72");

  // Pane border titles reinforce the branding (assistant / preview).
  set("pane-border-status", "top");
  set("pane-border-style", `fg=${hex.dim}`);
  set("pane-active-border-style", `fg=${hex.purple}`);
  set("pane-border-format",
    ` #{?pane_active,#[fg=${hex.purple}#,bold],#[fg=${hex.dim}]}#{pane_title} #[default]`);

  // Ctrl-X -> detach: back to the browser. Session stays alive so reopening
  // reattaches with Claude's context. Quitting the app happens in the browser.
  tmuxQ(["bind-key", "-n", "C-x", "detach-client"]);
}

/**
 * Launch (or reattach) the split workspace for a .tex file.
 * Blocks until the user presses Ctrl-X (back to the browser).
 */
export function launchWorkspace(texPath) {
  const tex = resolve(texPath);
  const dir = dirname(tex);
  const name = sessionName(tex);

  if (!haveTmux()) {
    console.error(
      "resumemaxx needs tmux for the split workspace.\n" +
      "  Run:  resumemaxx setup        (installs everything on macOS)\n" +
      "  or:   brew install tmux"
    );
    return;
  }

  const label = basename(tex);

  if (sessionExists(name)) {
    // Reattach — keeps the existing assistant session and its context.
    configureChrome(name, label);
    tmux(["attach-session", "-t", name]);
    return;
  }

  // Commands run directly as the pane processes (no visible "claude" typed) so
  // the workspace opens straight into the branded assistant + preview.
  const q = (s) => JSON.stringify(s);
  const assistantCmd = `node ${q(CLI)} _assistant ${q(tex)}`;
  const previewCmd = `node ${q(CLI)} _preview ${q(tex)}`;
  const bannerCmd = `node ${q(CLI)} _bannerpane ${q(label)}`;

  // Initial pane = the resumemaxx assistant.
  const r = tmuxQ(["new-session", "-d", "-s", name, "-c", dir, "-P", "-F", "#{pane_id}", assistantCmd]);
  if (r.status !== 0) {
    console.error("failed to create tmux session:\n" + (r.stderr || ""));
    return;
  }
  const aid = (r.stdout || "").trim();
  configureChrome(name, label);

  // Right column = live preview (full height).
  const pid = (tmuxQ(["split-window", "-h", "-p", "52", "-t", aid, "-c", dir, "-P", "-F", "#{pane_id}", previewCmd]).stdout || "").trim();
  // Banner strip above the assistant (left column) — the resumemaxx wordmark.
  const bid = (tmuxQ(["split-window", "-v", "-b", "-l", "7", "-t", aid, "-c", dir, "-P", "-F", "#{pane_id}", bannerCmd]).stdout || "").trim();

  // Pane titles for the borders.
  tmuxQ(["select-pane", "-t", aid, "-T", " ✦ resumemaxx · assistant "]);
  if (pid) tmuxQ(["select-pane", "-t", pid, "-T", " ▤ preview · " + label + " "]);
  if (bid) tmuxQ(["select-pane", "-t", bid, "-T", " "]);
  tmuxQ(["select-pane", "-t", aid]); // focus the assistant

  tmux(["attach-session", "-t", name]);
}

/** Kill any lingering resumemaxx workspaces (called when the app exits). */
export function killWorkspaces() {
  const r = tmuxQ(["list-sessions", "-F", "#{session_name}"]);
  if (r.status !== 0 || !r.stdout) return;
  for (const s of r.stdout.split("\n")) {
    if (s.startsWith("resumemaxx-")) tmuxQ(["kill-session", "-t", s]);
  }
}
