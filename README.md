# resumemaxx

A terminal workspace for resumes: **Claude Code on the left, a live PDF preview on the right**, with a built-in file browser. Built for LaTeX résumés.

Stop round-tripping through a slow editor extension. Open a resume, talk to Claude to edit the LaTeX, and watch the compiled PDF update inline the moment you save — all in your terminal.

```
┌─ claude ──────────────┬─ preview ─────────────┐
│ > tighten the bullets │                       │
│   under the Google    │     [ your resume,    │
│   internship          │       rendered as a   │
│ ⏺ done — recompiled   │       live image ]     │
│                       │                       │
└───────────────────────┴───────────────────────┘
```

## Features

- **Split workspace** — Claude Code and a live preview side by side (via tmux).
- **Inline PDF preview** — the compiled resume renders as a real image in the
  terminal (Kitty graphics protocol) and refreshes on every save.
- **File browser** — navigate your folders and open a resume. LaTeX aux junk
  (`.aux`, `.log`, `.fls`, `.synctex.gz`, …) is hidden from view.
- **No clutter** — compilation happens in a contained `.resumemaxx/build/`
  directory, so junk files never land next to your source. `resumemaxx clean`
  sweeps up any strays from older builds.

## Requirements

- [Node.js](https://nodejs.org) ≥ 18
- A terminal with Kitty graphics support — [Ghostty](https://ghostty.org) or
  [kitty](https://sw.kovidgoyal.org/kitty/)
- [`tmux`](https://github.com/tmux/tmux) — `brew install tmux`
- [`chafa`](https://hpjansson.org/chafa/) ≥ 1.14 — `brew install chafa`
  (renders the image as Kitty Unicode placeholders so it stays inside the tmux pane)
- A TeX distribution with `latexmk` (e.g. [TeX Live](https://tug.org/texlive/))
- [`pdftoppm`](https://poppler.freedesktop.org/) — `brew install poppler`
- [Claude Code](https://claude.com/claude-code) on your `PATH` (`claude`)

## Setup

On macOS, one command installs everything (Homebrew, tmux, chafa, poppler,
BasicTeX + the LaTeX packages resumes use, and PATH wiring):

```bash
resumemaxx setup
```

Check your toolchain any time:

```bash
resumemaxx doctor
```

On Linux, install the equivalents with your package manager:
`tmux chafa poppler-utils texlive texlive-latex-extra latexmk`.

## Usage

```bash
# Browse the current folder and pick a resume
resumemaxx

# Browse a specific folder
resumemaxx ~/Documents/resumes

# Jump straight into the workspace for one resume
resumemaxx ~/Documents/resumes/NBhatGoogle.tex

# Sweep stray LaTeX aux files out of a folder
resumemaxx clean ~/Documents/resumes
```

### In the browser

| Key | Action |
| --- | --- |
| `↑` `↓` / `j` `k` | move |
| `↵` | open folder / resume |
| `←` / `h` | parent folder |
| `/` | filter |
| `c` | clean junk in this folder |
| `Ctrl-X` / `q` | quit |

Resumes show a marker: `●` already compiled, `○` not yet built.

### In the workspace

The left pane is Claude Code (running in the resume's folder). The right pane is
the live preview — edit the `.tex` (yourself or by asking Claude), save, and the
PDF re-renders automatically. The current keys are always shown in the bottom bar.

| Key | Action |
| --- | --- |
| `Ctrl-X` | back to the file browser (keeps this workspace open) |
| `Ctrl-b ←/→` | switch panes (or click — mouse is enabled) |

**Zoom & scroll.** Focus the preview pane (click it, or `Ctrl-b →`), then:

| Key | Action |
| --- | --- |
| `+` / `-` | zoom in / out (re-rasterized, stays crisp) |
| `←` `↑` `↓` `→` / `h j k l` | scroll when zoomed |
| `0` | reset to fit |
| `[` / `]` | previous / next page |

Going back with `Ctrl-X` leaves the workspace running, so reopening the same
resume **reattaches** — your Claude conversation is right where you left it. The
tmux server runs on a private socket, so none of this touches your normal tmux.

## How it works

```
.tex  ──▶  latexmk (-outdir=.resumemaxx/build)  ──▶  PDF
                                                       │
                                              pdftoppm │ → PNG
                                                       ▼
                                  chafa → Kitty graphics → terminal pane
```

A file watcher debounces saves, recompiles into the contained build directory,
rasterizes page 1 with `pdftoppm`, and renders it with `chafa`. Inside tmux,
chafa emits the image as **Kitty Unicode placeholders** — the image becomes
real text cells, so tmux positions and clips it to the preview pane instead of
painting over the Claude pane (which is what naive graphics passthrough does).

## Install

```bash
git clone https://github.com/nimaibhat/resumemaxx
cd resumemaxx
npm link        # exposes the `resumemaxx` command
```

## License

MIT
