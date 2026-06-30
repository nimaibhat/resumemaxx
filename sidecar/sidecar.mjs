#!/usr/bin/env node
// resumemaxx assistant sidecar.
// Newline-delimited JSON with the macOS app:
//   in:  {"type":"config","cwd":..,"texPath":..|null,"name":..}
//        {"type":"user","text":..}
//   out: {"type":"ready"} {"type":"turn_start"} {"type":"delta","text":..}
//        {"type":"tool","name":..,"summary":..} {"type":"turn_done",..}
//        {"type":"error","message":..}

import { query, tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import { createInterface } from "node:readline";
import { spawn } from "node:child_process";
import { basename, dirname, join } from "node:path";
import { z } from "zod";

let cfg = { cwd: process.cwd(), texPath: null, name: "your resume" };
let sessionId = null;
let busy = false;
const queue = [];

function send(obj) { process.stdout.write(JSON.stringify(obj) + "\n"); }

function run(cmd, args, cwd) {
  return new Promise((res) => {
    const p = spawn(cmd, args, { cwd });
    let out = "", err = "";
    p.stdout.on("data", (d) => (out += d));
    p.stderr.on("data", (d) => (err += d));
    p.on("error", (e) => res({ code: 1, out, err: String(e) }));
    p.on("close", (code) => res({ code, out, err }));
  });
}

// ---- custom resume tool: compile + measure page / line counts -------------
const resumeReport = tool(
  "resume_report",
  "Compile the current resume and report its page count and the number of text " +
    "lines on each page. Use this after edits to keep the resume to one page and " +
    "to judge how many lines a change adds or removes.",
  {},
  async () => {
    const tex = cfg.texPath;
    if (!tex) return { content: [{ type: "text", text: "No resume file is set." }] };
    const dir = dirname(tex);
    const out = join(dir, ".resumemaxx", "build");
    await run("latexmk", ["-pdf", "-interaction=nonstopmode", "-halt-on-error", "-silent",
      `-outdir=${out}`, `-auxdir=${out}`, basename(tex)], dir);
    const pdf = join(out, basename(tex).replace(/\.tex$/i, ".pdf"));
    const info = await run("pdfinfo", [pdf]);
    const pm = info.out.match(/Pages:\s+(\d+)/);
    const pages = pm ? Number(pm[1]) : 0;
    const txt = await run("pdftotext", ["-layout", pdf, "-"]);
    const perPage = (txt.out || "").split("\f")
      .map((p) => p.split("\n").filter((l) => l.trim().length).length);
    while (perPage.length > pages && perPage[perPage.length - 1] === 0) perPage.pop();
    const report = { pages, linesPerPage: perPage, fitsOnePage: pages <= 1 };
    report.advice = pages > 1
      ? `Resume is ${pages} pages; page ${pages} has ${perPage[perPage.length - 1] || 0} lines. ` +
        `Trim roughly that many lines or tighten spacing to fit one page.`
      : `Resume is one page with ${perPage[0] || 0} lines of content.`;
    return { content: [{ type: "text", text: JSON.stringify(report) }] };
  }
);
const resumeServer = createSdkMcpServer({ name: "resume", version: "1.0.0", tools: [resumeReport] });

// ---------------------------------------------------------------------------
function persona() {
  if (cfg.texPath) {
    return (
      `You are resumemaxx, a focused resume assistant in a desktop app. You are ALWAYS ` +
      `working on exactly one file: ${cfg.texPath}. Never ask which file to work on. ` +
      `When changes are requested, edit ${cfg.name} directly with your tools; the user ` +
      `sees a live PDF preview that refreshes when you save. ` +
      `Keeping the resume to ONE page is important. You have a tool, resume_report ` +
      `(mcp__resume__resume_report), that compiles the resume and returns its page count ` +
      `and per-page line counts. Call it after making edits to verify the resume still ` +
      `fits one page and to understand how many lines content occupies. ` +
      `Keep replies concise; make bullets impact- and metric-driven and preserve the layout.`
    );
  }
  return (
    `You are resumemaxx, working in the folder ${cfg.cwd}, which contains LaTeX resumes. ` +
    `Help the user organize and manage these resumes as instructed, using shell commands ` +
    `for file operations. Do not modify resume contents unless explicitly asked.`
  );
}

function summarize(block) {
  const i = block.input ?? {};
  if (i.file_path) return basename(String(i.file_path));
  if (i.command) return String(i.command).slice(0, 60);
  if (i.pattern) return String(i.pattern);
  return "";
}

async function runTurn(text) {
  busy = true;
  send({ type: "turn_start" });
  try {
    const options = {
      cwd: cfg.cwd,
      systemPrompt: { type: "preset", preset: "claude_code", append: persona() },
      allowedTools: ["Read", "Edit", "Write", "Bash", "Glob", "Grep", "mcp__resume__resume_report"],
      mcpServers: { resume: resumeServer },
      permissionMode: "acceptEdits",
      includePartialMessages: true,
    };
    if (sessionId) options.resume = sessionId;

    for await (const msg of query({ prompt: text, options })) {
      if (msg.session_id) sessionId = msg.session_id;
      if (msg.type === "stream_event") {
        const ev = msg.event;
        if (ev?.type === "content_block_delta" && ev.delta?.type === "text_delta") {
          send({ type: "delta", text: ev.delta.text });
        }
      } else if (msg.type === "assistant") {
        for (const block of msg.message?.content ?? []) {
          if (block?.type === "tool_use") {
            send({ type: "tool", name: block.name, summary: summarize(block) });
          }
        }
      } else if (msg.type === "result") {
        send({ type: "turn_done", sessionId, error: !!msg.is_error, subtype: msg.subtype });
      }
    }
  } catch (e) {
    send({ type: "error", message: String(e?.message ?? e) });
    send({ type: "turn_done", sessionId, error: true });
  } finally {
    busy = false;
    pump();
  }
}

function pump() { if (!busy && queue.length) runTurn(queue.shift()); }

const rl = createInterface({ input: process.stdin });
rl.on("line", (line) => {
  line = line.trim();
  if (!line) return;
  let m;
  try { m = JSON.parse(line); } catch { return; }
  if (m.type === "config") {
    const newTex = m.texPath ?? null;
    const changed = newTex !== cfg.texPath || (m.cwd && m.cwd !== cfg.cwd);
    cfg = { cwd: m.cwd ?? cfg.cwd, texPath: newTex, name: m.name ?? cfg.name };
    if (changed) sessionId = null; // new file/folder -> fresh conversation
  } else if (m.type === "user" && typeof m.text === "string") {
    queue.push(m.text);
    pump();
  }
});

send({ type: "ready" });
