#!/usr/bin/env node
// resumemaxx assistant sidecar.
// Speaks newline-delimited JSON with the macOS app:
//   in:  {"type":"config","cwd":..,"texPath":..,"name":..}
//        {"type":"user","text":..}
//   out: {"type":"ready"} | {"type":"turn_start"} | {"type":"delta","text":..}
//        {"type":"tool","name":..,"summary":..} | {"type":"turn_done",..}
//        {"type":"error","message":..}

import { query } from "@anthropic-ai/claude-agent-sdk";
import { createInterface } from "node:readline";
import { basename } from "node:path";

let cfg = { cwd: process.cwd(), texPath: null, name: "your resume" };
let sessionId = null;
let busy = false;
const queue = [];

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

function persona() {
  return (
    `You are resumemaxx, a focused resume assistant embedded in a desktop app. ` +
    `You are ALWAYS working on exactly one file: ${cfg.texPath}. ` +
    `Never ask the user which file to work on; it is always this file. ` +
    `When changes are requested, edit ${cfg.name} directly with your tools. The user ` +
    `sees a live PDF preview that refreshes whenever the file is saved, so your edits ` +
    `appear immediately. Keep replies concise and concrete: make bullet points impact- ` +
    `and metric-driven, fix LaTeX issues, and preserve the clean one-page layout.`
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
      allowedTools: ["Read", "Edit", "Write", "Bash", "Glob", "Grep"],
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

function pump() {
  if (!busy && queue.length) runTurn(queue.shift());
}

const rl = createInterface({ input: process.stdin });
rl.on("line", (line) => {
  line = line.trim();
  if (!line) return;
  let m;
  try { m = JSON.parse(line); } catch { return; }
  if (m.type === "config") {
    const changedFile = m.texPath && m.texPath !== cfg.texPath;
    cfg = { cwd: m.cwd ?? cfg.cwd, texPath: m.texPath ?? cfg.texPath, name: m.name ?? cfg.name };
    if (changedFile) sessionId = null; // new resume -> fresh conversation
  } else if (m.type === "user" && typeof m.text === "string") {
    queue.push(m.text);
    pump();
  }
});

send({ type: "ready" });
