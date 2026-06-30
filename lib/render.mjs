// Image rendering. Prefers chafa (Kitty unicode-placeholder output), which
// renders correctly INSIDE tmux panes — the image becomes text cells that tmux
// positions and clips to the pane. Falls back to direct Kitty graphics when
// chafa is absent (only correct outside tmux).

import { spawnSync } from "node:child_process";
import { renderPng, clearImages } from "./kitty.mjs";

let _chafa = null;
export function hasChafa() {
  if (_chafa === null) {
    _chafa = spawnSync("chafa", ["--version"], { encoding: "utf8" }).status === 0;
  }
  return _chafa;
}

/**
 * Render a PNG into a cols x rows cell box, aspect-preserved.
 * @param {string} png
 * @param {{cols:number, rows:number, out?:NodeJS.WriteStream}} opts
 */
export function renderImage(png, { cols, rows, out = process.stdout }) {
  if (hasChafa()) {
    const passthrough = process.env.TMUX ? "tmux" : "none";
    const r = spawnSync(
      "chafa",
      [
        "-f", "kitty",
        "--passthrough", passthrough,
        "--relative", "off",
        "--polite", "on",
        "--align", "top,center",
        "-s", `${cols}x${rows}`,
        png,
      ],
      { maxBuffer: 64 * 1024 * 1024 }
    );
    if (r.status === 0 && r.stdout && r.stdout.length) {
      out.write(r.stdout);
      return true;
    }
    // fall through to direct method on any chafa failure
  }
  // Direct Kitty graphics (correct outside tmux only).
  clearImages(out);
  renderPng(png, { rows, out });
  return false;
}
