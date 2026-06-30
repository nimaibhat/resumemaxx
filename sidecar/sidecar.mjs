#!/usr/bin/env node
// resumemaxx assistant sidecar. Provider-aware: Claude (Agent SDK) or OpenAI
// (function-calling agent loop). Newline-delimited JSON IPC with the macOS app.
//   in:  {"type":"config","cwd","texPath"|null,"name","provider","openaiKey","openaiModel"}
//        {"type":"user","text"}
//   out: {"type":"ready"} {"type":"turn_start"} {"type":"delta","text"}
//        {"type":"tool","name","summary"} {"type":"turn_done",..} {"type":"error","message"}

import { query, tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import OpenAI from "openai";
import { createInterface } from "node:readline";
import { spawn } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { basename, dirname, join, isAbsolute, resolve as resolvePath } from "node:path";
import { z } from "zod";

let cfg = {
  cwd: process.cwd(), texPath: null, name: "your resume",
  provider: "claude", openaiKey: null, openaiModel: "gpt-4o",
};
let claudeSession = null;
let oaiMessages = null; // multi-turn history for the OpenAI provider
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

// ---- shared resume metrics (compile + count pages/lines) ------------------
async function resumeReportImpl() {
  const tex = cfg.texPath;
  if (!tex) return { error: "No resume file is set." };
  const dir = dirname(tex);
  const out = join(dir, ".resumemaxx", "build");
  await run("latexmk", ["-pdf", "-interaction=nonstopmode", "-halt-on-error", "-silent",
    `-outdir=${out}`, `-auxdir=${out}`, basename(tex)], dir);
  const pdf = join(out, basename(tex).replace(/\.tex$/i, ".pdf"));
  const info = await run("pdfinfo", [pdf]);
  const pm = info.out.match(/Pages:\s+(\d+)/);
  const pages = pm ? Number(pm[1]) : 0;
  const txt = await run("pdftotext", ["-layout", pdf, "-"]);
  const perPage = (txt.out || "").split("\f").map((p) => p.split("\n").filter((l) => l.trim().length).length);
  while (perPage.length > pages && perPage[perPage.length - 1] === 0) perPage.pop();
  const advice = pages > 1
    ? `Resume is ${pages} pages; page ${pages} has ${perPage[perPage.length - 1] || 0} lines. Trim to fit one page.`
    : `Resume is one page with ${perPage[0] || 0} lines.`;
  return { pages, linesPerPage: perPage, fitsOnePage: pages <= 1, advice };
}

function resolveInCwd(p) { return isAbsolute(p) ? p : resolvePath(cfg.cwd, p); }

function persona() {
  if (cfg.texPath) {
    return (
      `You are resumemaxx, a focused resume assistant in a desktop app. You are ALWAYS ` +
      `working on exactly one file: ${cfg.texPath}. Never ask which file to work on. ` +
      `When changes are requested, edit ${cfg.name} directly; the user sees a live PDF ` +
      `preview that refreshes when you save. Keeping the resume to ONE page is important: ` +
      `use the resume_report tool after edits to verify page count and per-page line counts. ` +
      `Keep replies concise; make bullets impact- and metric-driven and preserve the layout.`
    );
  }
  return (
    `You are resumemaxx, working in the folder ${cfg.cwd}, which contains LaTeX resumes. ` +
    `Help organize and manage these resumes as instructed using shell commands. ` +
    `Do not modify resume contents unless explicitly asked.`
  );
}

// =========================== Claude (Agent SDK) ============================
const resumeReportTool = tool(
  "resume_report",
  "Compile the current resume and report page count and per-page line counts.",
  {},
  async () => ({ content: [{ type: "text", text: JSON.stringify(await resumeReportImpl()) }] })
);
const resumeServer = createSdkMcpServer({ name: "resume", version: "1.0.0", tools: [resumeReportTool] });

function summarize(block) {
  const i = block.input ?? {};
  if (i.file_path) return basename(String(i.file_path));
  if (i.command) return String(i.command).slice(0, 60);
  if (i.pattern) return String(i.pattern);
  return "";
}

async function runClaude(text) {
  const options = {
    cwd: cfg.cwd,
    systemPrompt: { type: "preset", preset: "claude_code", append: persona() },
    allowedTools: ["Read", "Edit", "Write", "Bash", "Glob", "Grep", "mcp__resume__resume_report"],
    mcpServers: { resume: resumeServer },
    permissionMode: "acceptEdits",
    includePartialMessages: true,
  };
  if (claudeSession) options.resume = claudeSession;
  for await (const msg of query({ prompt: text, options })) {
    if (msg.session_id) claudeSession = msg.session_id;
    if (msg.type === "stream_event") {
      const ev = msg.event;
      if (ev?.type === "content_block_delta" && ev.delta?.type === "text_delta") {
        send({ type: "delta", text: ev.delta.text });
      }
    } else if (msg.type === "assistant") {
      for (const block of msg.message?.content ?? []) {
        if (block?.type === "tool_use") send({ type: "tool", name: block.name, summary: summarize(block) });
      }
    } else if (msg.type === "result") {
      send({ type: "turn_done", error: !!msg.is_error });
    }
  }
}

// =============================== OpenAI ====================================
const OAI_TOOLS = [
  { type: "function", function: { name: "read_file", description: "Read a UTF-8 file.",
    parameters: { type: "object", properties: { path: { type: "string" } }, required: ["path"] } } },
  { type: "function", function: { name: "write_file", description: "Overwrite a UTF-8 file with new contents.",
    parameters: { type: "object", properties: { path: { type: "string" }, content: { type: "string" } }, required: ["path", "content"] } } },
  { type: "function", function: { name: "resume_report", description: "Compile the current resume and return page count + per-page line counts.",
    parameters: { type: "object", properties: {} } } },
  { type: "function", function: { name: "run_bash", description: "Run a shell command in the working directory (for file moves, mkdir, etc.).",
    parameters: { type: "object", properties: { command: { type: "string" } }, required: ["command"] } } },
];

async function callOAITool(name, args) {
  if (name === "read_file") {
    try { return await readFile(resolveInCwd(args.path), "utf8"); } catch (e) { return `error: ${e.message}`; }
  }
  if (name === "write_file") {
    try { await writeFile(resolveInCwd(args.path), args.content, "utf8"); return "ok"; } catch (e) { return `error: ${e.message}`; }
  }
  if (name === "resume_report") {
    return JSON.stringify(await resumeReportImpl());
  }
  if (name === "run_bash") {
    const r = await run("/bin/zsh", ["-lc", String(args.command)], cfg.cwd);
    return (r.out + r.err).slice(0, 4000) || "(no output)";
  }
  return "unknown tool";
}

function toolSummary(name, args) {
  if (args?.path) return basename(String(args.path));
  if (args?.command) return String(args.command).slice(0, 60);
  return "";
}

async function runOpenAI(text) {
  const apiKey = cfg.openaiKey || process.env.OPENAI_API_KEY;
  if (!apiKey) {
    send({ type: "error", message: "No OpenAI API key. Add one in Settings." });
    send({ type: "turn_done", error: true });
    return;
  }
  const client = new OpenAI({ apiKey });
  if (!oaiMessages) oaiMessages = [{ role: "system", content: persona() }];
  else oaiMessages[0] = { role: "system", content: persona() };
  oaiMessages.push({ role: "user", content: text });

  for (let step = 0; step < 25; step++) {
    const stream = await client.chat.completions.create({
      model: cfg.openaiModel || "gpt-4o",
      messages: oaiMessages,
      tools: OAI_TOOLS,
      stream: true,
    });
    let content = "";
    const calls = {}; // index -> {id, name, args}
    for await (const chunk of stream) {
      const d = chunk.choices[0]?.delta;
      if (d?.content) { content += d.content; send({ type: "delta", text: d.content }); }
      for (const tc of d?.tool_calls ?? []) {
        const c = (calls[tc.index] ||= { id: "", name: "", args: "" });
        if (tc.id) c.id = tc.id;
        if (tc.function?.name) c.name = tc.function.name;
        if (tc.function?.arguments) c.args += tc.function.arguments;
      }
    }
    const toolCalls = Object.values(calls);
    if (toolCalls.length === 0) {
      oaiMessages.push({ role: "assistant", content });
      send({ type: "turn_done", error: false });
      return;
    }
    oaiMessages.push({
      role: "assistant",
      content: content || null,
      tool_calls: toolCalls.map((c) => ({ id: c.id, type: "function", function: { name: c.name, arguments: c.args || "{}" } })),
    });
    for (const c of toolCalls) {
      let args = {};
      try { args = JSON.parse(c.args || "{}"); } catch {}
      send({ type: "tool", name: c.name, summary: toolSummary(c.name, args) });
      const result = await callOAITool(c.name, args);
      oaiMessages.push({ role: "tool", tool_call_id: c.id, content: String(result) });
    }
  }
  send({ type: "turn_done", error: false });
}

// ============================== dispatch ===================================
async function runTurn(text) {
  busy = true;
  send({ type: "turn_start" });
  try {
    if (cfg.provider === "openai") await runOpenAI(text);
    else await runClaude(text);
  } catch (e) {
    send({ type: "error", message: String(e?.message ?? e) });
    send({ type: "turn_done", error: true });
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
    const changed = newTex !== cfg.texPath || (m.cwd && m.cwd !== cfg.cwd) ||
      (m.provider && m.provider !== cfg.provider);
    cfg = {
      cwd: m.cwd ?? cfg.cwd, texPath: newTex, name: m.name ?? cfg.name,
      provider: m.provider ?? cfg.provider, openaiKey: m.openaiKey ?? cfg.openaiKey,
      openaiModel: m.openaiModel ?? cfg.openaiModel,
    };
    if (changed) { claudeSession = null; oaiMessages = null; } // fresh conversation
  } else if (m.type === "user" && typeof m.text === "string") {
    queue.push(m.text);
    pump();
  }
});

send({ type: "ready" });
