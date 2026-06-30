#!/usr/bin/env bash
# resumemaxx — macOS setup.
# Installs everything needed: Homebrew, tmux, chafa, poppler, a LaTeX
# distribution (BasicTeX) with the packages resumemaxx needs, and wires the
# TeX binaries onto your PATH. Safe to re-run — it skips what's already there.
set -uo pipefail

bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; yellow=$'\033[33m'
red=$'\033[31m'; cyan=$'\033[36m'; reset=$'\033[0m'

say()  { printf '%s\n' "${cyan}==>${reset} ${bold}$*${reset}"; }
ok()   { printf '%s\n' "  ${green}✓${reset} $*"; }
warn() { printf '%s\n' "  ${yellow}!${reset} $*"; }
err()  { printf '%s\n' "  ${red}✗${reset} $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if [[ "$(uname)" != "Darwin" ]]; then
  err "This script is for macOS. On Linux, install: tmux chafa poppler texlive-full (or texlive + latexmk)."
  exit 1
fi

say "resumemaxx setup for macOS"

# ---------------------------------------------------------------- Homebrew ---
if ! have brew; then
  say "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    err "Homebrew install failed. See https://brew.sh and re-run."; exit 1; }
  # Put brew on PATH for the rest of this script (Apple Silicon vs Intel).
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
else
  ok "Homebrew present"
fi

# ------------------------------------------------------------ brew formulae ---
for pkg in tmux chafa poppler node; do
  if brew list --formula "$pkg" >/dev/null 2>&1 || have "${pkg/node/node}"; then
    ok "$pkg present"
  else
    say "Installing $pkg"
    brew install "$pkg" && ok "$pkg installed" || err "failed to install $pkg"
  fi
done

# ------------------------------------------------------------------- LaTeX ---
TEXBIN="/Library/TeX/texbin"
if have latexmk; then
  ok "LaTeX (latexmk) present"
else
  say "Installing BasicTeX (smaller than full MacTeX; ~100 MB)"
  warn "This step needs your admin password (installs a system .pkg)."
  brew install --cask basictex || err "BasicTeX install failed"
  # BasicTeX lands in /Library/TeX/texbin — add it for the rest of this run.
  if [[ -d "$TEXBIN" ]]; then export PATH="$TEXBIN:$PATH"; fi
fi

# Make sure the TeX bin dir is on PATH now (for tlmgr below).
[[ -d "$TEXBIN" ]] && export PATH="$TEXBIN:$PATH"

# ----------------------------------------------- LaTeX packages for resumes ---
if have tlmgr; then
  say "Installing the LaTeX packages resume templates commonly use"
  warn "tlmgr needs your admin password."
  sudo tlmgr update --self 2>/dev/null || true
  # Packages referenced by the bundled/typical resume templates.
  sudo tlmgr install \
    latexmk titlesec marvosym enumitem fullpage tabularx \
    fontawesome fontawesome5 preprint xcolor lm 2>/dev/null \
    && ok "LaTeX packages installed" \
    || warn "Some packages may already be present (that's fine)."
else
  warn "tlmgr not found — if a resume fails to compile, install its package with: sudo tlmgr install <pkg>"
fi

# ------------------------------------------------------------- PATH wiring ---
PROFILE=""
case "${SHELL:-}" in
  */zsh)  PROFILE="$HOME/.zshrc" ;;
  */bash) PROFILE="$HOME/.bash_profile" ;;
  *)      PROFILE="$HOME/.profile" ;;
esac
LINE="export PATH=\"$TEXBIN:\$PATH\""
if [[ -d "$TEXBIN" ]]; then
  if [[ -f "$PROFILE" ]] && grep -qF "$TEXBIN" "$PROFILE"; then
    ok "TeX already on PATH in $(basename "$PROFILE")"
  else
    say "Adding TeX to PATH in $(basename "$PROFILE")"
    printf '\n# Added by resumemaxx setup\n%s\n' "$LINE" >> "$PROFILE"
    ok "Wrote PATH entry — open a new terminal (or 'source $PROFILE') to pick it up."
  fi
fi

# ------------------------------------------------------------ Claude Code ---
if have claude; then
  ok "Claude Code (claude) present"
else
  warn "Claude Code not found. Install it from https://claude.com/claude-code"
  warn "  (resumemaxx runs 'claude' in the left pane)."
fi

# --------------------------------------------------------------- summary ----
say "Verifying"
allgood=1
for b in tmux chafa pdftoppm latexmk; do
  if have "$b"; then ok "$b"; else err "$b still missing"; allgood=0; fi
done
echo
if [[ $allgood -eq 1 ]]; then
  printf '%s\n' "${green}${bold}Setup complete.${reset} Run ${bold}resumemaxx${reset} to start."
else
  printf '%s\n' "${yellow}Some tools are still missing.${reset} Re-run this script, or open a new terminal first (PATH changes)."
fi
