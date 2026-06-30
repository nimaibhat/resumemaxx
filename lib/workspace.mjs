// tmux workspace: Claude Code on the left, live PDF preview on the right.
// Graphics passthrough is enabled so the inline kitty image survives tmux.

import { spawnSync } from "node:child_process";
import { dirname, resolve, basename } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CLI = resolve(__dirname, "..", "bin", "resumemaxx.mjs");

function tmux(args, opts = {}) {
  return spawnSync("tmux", args, { stdio: "inherit", ...opts });
}
function tmuxQ(args) {
  return spawnSync("tmux", args, { encoding: "utf8" });
}

function haveTmux() {
  return spawnSync("tmux", ["-V"], { encoding: "utf8" }).status === 0;
}

/**
 * Launch the split workspace for a .tex file. Blocks until the user detaches
 * or the session ends. Returns true on success.
 */
export function launchWorkspace(texPath, { claudeCmd = "claude" } = {}) {
  const tex = resolve(texPath);
  const dir = dirname(tex);
  const name = "resumemaxx-" + basename(tex).replace(/\.tex$/, "").replace(/[^A-Za-z0-9_-]/g, "_");

  if (!haveTmux()) {
    console.error(
      "resumemaxx needs tmux for the split workspace.\n" +
      "  macOS:  brew install tmux\n" +
      "  Debian: sudo apt install tmux"
    );
    return false;
  }

  // Kill any stale session with this name.
  tmuxQ(["kill-session", "-t", name]);

  // Create detached session with the preview pane as the initial window.
  const previewCmd = `node ${JSON.stringify(CLI)} _preview ${JSON.stringify(tex)}`;

  // Window 0, pane 0 = left = Claude. Created detached; attach resizes it to
  // the real client size (the preview redraws on the resize event).
  const r = tmuxQ(["new-session", "-d", "-s", name, "-c", dir]);
  if (r.status !== 0) {
    console.error("failed to create tmux session:\n" + (r.stderr || ""));
    return false;
  }

  // Enable graphics passthrough (kitty protocol) for this session.
  tmuxQ(["set-option", "-t", name, "-g", "allow-passthrough", "on"]);
  tmuxQ(["set-option", "-t", name, "-g", "mouse", "on"]);
  // Give the preview pane a clean status hint.
  tmuxQ(["set-option", "-t", name, "status", "off"]);

  // Right pane (51% so the resume page has room) runs the preview.
  tmuxQ(["split-window", "-h", "-p", "52", "-t", `${name}:0`, "-c", dir]);
  tmuxQ(["send-keys", "-t", `${name}:0.1`, previewCmd, "Enter"]);

  // Left pane runs Claude in the resume's directory.
  tmuxQ(["send-keys", "-t", `${name}:0.0`, claudeCmd, "Enter"]);
  tmuxQ(["select-pane", "-t", `${name}:0.0`]);

  // Attach (takes over the terminal until detach/exit).
  tmux(["attach-session", "-t", name]);

  // After detach, clean up the session.
  tmuxQ(["kill-session", "-t", name]);
  return true;
}
