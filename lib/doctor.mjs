// Dependency checker. Used at startup (a quick warning) and by `resumemaxx
// doctor` (a full report).

import { spawnSync } from "node:child_process";

const C = {
  reset: "\x1b[0m", bold: "\x1b[1m", dim: "\x1b[2m",
  green: "\x1b[32m", red: "\x1b[31m", yellow: "\x1b[33m", cyan: "\x1b[36m",
};

function has(bin, versionArgs = ["--version"]) {
  const r = spawnSync(bin, versionArgs, { encoding: "utf8" });
  return r.status === 0;
}

// name, check, required?, hint
const DEPS = [
  { name: "latexmk",  ok: () => has("latexmk", ["-version"]), required: true,
    hint: "LaTeX toolchain. macOS: `resumemaxx setup` (installs BasicTeX)." },
  { name: "pdftoppm", ok: () => has("pdftoppm", ["-v"]), required: true,
    hint: "PDF rasterizer (poppler). macOS: `brew install poppler`." },
  { name: "tmux",     ok: () => has("tmux", ["-V"]), required: true,
    hint: "Terminal multiplexer for the split view. macOS: `brew install tmux`." },
  { name: "chafa",    ok: () => has("chafa", ["--version"]), required: true,
    hint: "Inline image renderer (keeps the preview inside its pane). macOS: `brew install chafa`." },
  { name: "claude",   ok: () => has("claude", ["--version"]), required: false,
    hint: "Claude Code CLI for the left pane. See https://claude.com/claude-code." },
];

/** @returns {{missingRequired: string[], missingOptional: string[], results: any[]}} */
export function check() {
  const results = DEPS.map((d) => ({ ...d, present: d.ok() }));
  return {
    results,
    missingRequired: results.filter((r) => !r.present && r.required).map((r) => r.name),
    missingOptional: results.filter((r) => !r.present && !r.required).map((r) => r.name),
  };
}

/** Full, pretty report for `resumemaxx doctor`. */
export function report() {
  const { results, missingRequired } = check();
  let s = `\n  ${C.bold}${C.cyan}resumemaxx doctor${C.reset}\n\n`;
  for (const r of results) {
    const mark = r.present ? `${C.green}✓${C.reset}` : (r.required ? `${C.red}✗${C.reset}` : `${C.yellow}!${C.reset}`);
    s += `  ${mark} ${r.name.padEnd(10)} `;
    s += r.present ? `${C.dim}found${C.reset}\n` : `${C.dim}${r.hint}${C.reset}\n`;
  }
  s += "\n";
  if (missingRequired.length) {
    s += `  ${C.yellow}Missing required tools.${C.reset} On macOS, run:  ${C.bold}resumemaxx setup${C.reset}\n\n`;
  } else {
    s += `  ${C.green}All set — run ${C.bold}resumemaxx${C.reset}${C.green} to start.${C.reset}\n\n`;
  }
  process.stdout.write(s);
  return missingRequired.length === 0;
}
