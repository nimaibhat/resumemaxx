// resumemaxx theme — a baby-blue → purple palette shared across the UI.

export const rgb = {
  blue:   [150, 197, 255], // baby blue
  peri:   [167, 178, 255], // periwinkle
  lilac:  [197, 171, 255], // light purple
  purple: [176, 148, 255], // purple
  dim:    [118, 116, 140],
  text:   [226, 226, 240],
  ink:    [26, 22, 38],     // dark text on light bars
};

// Hex strings for tmux style options.
export const hex = {
  blue: "#96c5ff", peri: "#a7b2ff", lilac: "#c5abff", purple: "#b094ff",
  bg: "#1b1726", bg2: "#262036", dim: "#6f6b85", text: "#e2e2f0", ink: "#1a1626",
};

export const reset = "\x1b[0m";
export const bold = "\x1b[1m";
export const dim = "\x1b[2m";

export const fg = ([r, g, b]) => `\x1b[38;2;${r};${g};${b}m`;
export const bg = ([r, g, b]) => `\x1b[48;2;${r};${g};${b}m`;

export function lerp(a, b, t) {
  return [
    Math.round(a[0] + (b[0] - a[0]) * t),
    Math.round(a[1] + (b[1] - a[1]) * t),
    Math.round(a[2] + (b[2] - a[2]) * t),
  ];
}

// Color a string with a left→right gradient (default blue→lilac).
export function gradient(str, c1 = rgb.blue, c2 = rgb.purple) {
  const n = Math.max(1, str.length - 1);
  let out = "";
  for (let i = 0; i < str.length; i++) {
    out += fg(lerp(c1, c2, i / n)) + str[i];
  }
  return out + reset;
}
