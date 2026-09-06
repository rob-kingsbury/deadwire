#!/usr/bin/env node
/**
 * Stop hook: `.claude/context.md` may not grow without bound.
 *
 * WHY THIS IS A CONTROL AND NOT A RULE. context.md is loaded into every session
 * by the CLAUDE.md import, so every line in it is a line paid for on every
 * single turn, forever. It only ever grows: each handoff appends a session
 * summary, each review appends findings, and nothing has ever removed anything.
 * It went from 190 lines at session 15 to 440 at session 20. Sembr's, which is
 * a far larger project, is 192, because that repo prunes deliberately.
 *
 * The prose rule "keep context.md tight" has been in this repo's handoff
 * procedure since the start and the file tripled anyway. A written instruction
 * competes with everything else in context at the moment it matters, and it
 * loses, because the model finishing a session is thinking about the session,
 * not about the file's line count. So it gets counted instead of requested.
 *
 * WHAT IT DELIBERATELY DOES NOT DO. It does not ask the model whether the file
 * is too long, or which parts are stale. Both questions get an optimistic
 * answer from the model that just wrote it. Every check below is arithmetic or
 * a `gh` lookup, and every message names the exact lines to move and where.
 *
 * It also does not edit the file itself. A Stop hook that rewrote context.md
 * would do it AFTER the turn's commit, leaving a dirty tree and a commit whose
 * content does not match the file. Blocking with the computed instruction keeps
 * the edit and the commit in the same turn, where they belong.
 *
 * SCOPE. Fires only when the turn actually wrote to context.md. A Stop hook
 * that checks every turn burns a model turn on "hello", and this failure only
 * exists on turns that touch the handoff.
 *
 * FAIL-OPEN. If gh is missing, the transcript is unreadable, or this hook
 * throws, the turn is allowed. The cost of a missed check is a long file, which
 * the next session fixes. The cost of a wedge is a session that cannot end.
 *
 * Tests: node .claude/hooks/context-prune.test.cjs
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const CONTEXT_REL = '.claude/context.md';
const ARCHIVE_REL = '.claude/archive/sessions.md';

/**
 * The budget. 300 lines is roughly twice Sembr's context.md, which covers a
 * project an order of magnitude larger, so it is not a tight cap; it is a cap
 * that only an unpruned file can hit.
 */
const LINE_BUDGET = 300;

/**
 * How many session write-ups stay in the live file. Three is what Sembr keeps.
 * Older ones are not deleted, they move to the archive, because the reason a
 * bug was fixed a certain way is worth keeping and is worth nothing in a file
 * loaded on every turn.
 */
const MAX_SESSIONS = 3;

function readInput() {
    let raw = '';
    try {
        raw = fs.readFileSync(0, 'utf8');
    } catch {
        return null;
    }
    try {
        return JSON.parse(raw);
    } catch {
        return null;
    }
}

function allow() {
    process.exit(0);
}

/**
 * Block the stop with the computed prune.
 *
 * Each problem names what to move and where, so the fix is a cut and paste
 * rather than a judgement call about what matters.
 */
function block(problems) {
    const body = problems.map((p) => `  - ${p}`).join('\n');
    process.stdout.write(JSON.stringify({
        decision: 'block',
        reason:
            `${CONTEXT_REL} is over budget. It is loaded into every session by the CLAUDE.md `
            + `import, so every line costs on every turn. It has only ever grown.\n\n${body}\n\n`
            + `Prune it, then finish. Move, do not delete: session write-ups belong in `
            + `${ARCHIVE_REL}, which nothing loads. Keep the newest ${MAX_SESSIONS} in place. `
            + `The counts above were measured just now, so do not re-estimate them by reading.`,
    }));
    process.exit(0);
}

const GH_BIN = process.env.PRUNE_GH_BIN || 'gh';

/**
 * Did this turn write to context.md?
 *
 * Walks back to the most recent real user prompt and looks for a Write or Edit
 * naming the file. A read does not count: reading the handoff is not what makes
 * it long.
 */
function turnWroteContext(transcriptPath) {
    if (!transcriptPath || !fs.existsSync(transcriptPath)) return false;

    const entries = [];
    for (const line of fs.readFileSync(transcriptPath, 'utf8').split('\n')) {
        if (!line.trim()) continue;
        try {
            entries.push(JSON.parse(line));
        } catch {
            // A malformed line is not evidence either way.
        }
    }

    let turnStart = -1;
    for (let i = entries.length - 1; i >= 0; i--) {
        const e = entries[i];
        if (e.type !== 'user' || !e.message || e.message.role !== 'user') continue;
        const content = e.message.content;
        const isToolResult = Array.isArray(content) && content.length > 0
            && content[0] && content[0].type === 'tool_result';
        if (!isToolResult) {
            turnStart = i;
            break;
        }
    }
    if (turnStart === -1) return false;

    for (let i = turnStart; i < entries.length; i++) {
        const e = entries[i];
        if (e.type !== 'assistant' || !e.message || !Array.isArray(e.message.content)) continue;
        for (const item of e.message.content) {
            if (item.type !== 'tool_use') continue;
            if (!['Write', 'Edit', 'NotebookEdit'].includes(item.name)) continue;
            const p = String((item.input && item.input.file_path) || '').replace(/\\/g, '/');
            if (p.endsWith('.claude/context.md')) return true;
        }
    }
    return false;
}

/**
 * Session write-ups, newest first as they appear in the file.
 *
 * Matches `### Session 18 (2026-08-06): ...` under any heading. The session
 * number is what orders them, not file position, because handoffs have been
 * appended out of order before: session 19's write-up sits after 18's in the
 * current file while 20's sits before both.
 */
function sessionHeadings(text) {
    const out = [];
    const re = /^###\s+Session\s+(\d+)\b[^\n]*/gim;
    let m;
    while ((m = re.exec(text)) !== null) {
        out.push({ n: Number(m[1]), heading: m[0].trim(), index: m.index });
    }
    return out;
}

/** Issue numbers the file lists in a markdown table row, e.g. `| 31 | Title |`. */
function tabledIssues(text) {
    const out = new Set();
    const re = /^\|\s*(\d{1,5})\s*\|/gm;
    let m;
    while ((m = re.exec(text)) !== null) out.add(m[1]);
    return out;
}

function ghIssueState(num, cwd) {
    try {
        const needsShell = process.platform === 'win32' && /\.(cmd|bat)$/i.test(GH_BIN);
        return execFileSync(GH_BIN, ['issue', 'view', num, '--json', 'state', '--jq', '.state'], {
            cwd, encoding: 'utf8', timeout: 20000, stdio: ['ignore', 'pipe', 'ignore'],
            shell: needsShell,
        }).trim().toUpperCase();
    } catch {
        return null; // gh missing, offline, or not an issue. Fail open.
    }
}

function main() {
    const event = readInput();
    if (!event) allow();

    // The re-entry guard. Without it a block would loop forever.
    if (event.stop_hook_active === true) allow();

    const cwd = event.cwd || process.env.CLAUDE_PROJECT_DIR || process.cwd();
    const contextPath = path.join(cwd, CONTEXT_REL);
    if (!fs.existsSync(contextPath)) allow();

    if (!turnWroteContext(event.transcript_path)) allow();

    let text;
    try {
        text = fs.readFileSync(contextPath, 'utf8');
    } catch {
        allow();
    }

    const problems = [];

    // ---- Check 1: total size ----
    // Match what `wc -l` reports, so the number in the block message is the one
    // the reader gets when they check it. A trailing newline is not a line.
    const lines = text.split('\n').length - (text.endsWith('\n') ? 1 : 0);
    if (lines > LINE_BUDGET) {
        problems.push(
            `it is ${lines} lines against a ${LINE_BUDGET} budget, ${lines - LINE_BUDGET} over`
        );
    }

    // ---- Check 2: session write-ups past the keep-window ----
    const sessions = sessionHeadings(text);
    if (sessions.length > MAX_SESSIONS) {
        const byNumber = [...sessions].sort((a, b) => b.n - a.n);
        const stale = byNumber.slice(MAX_SESSIONS).sort((a, b) => b.n - a.n);
        const keep = byNumber.slice(0, MAX_SESSIONS).map((s) => s.n).join(', ');
        problems.push(
            `it holds ${sessions.length} session write-ups; keep the newest ${MAX_SESSIONS} `
            + `(${keep}) and move these to ${ARCHIVE_REL}: `
            + stale.map((s) => `"${s.heading}"`).join('; ')
        );
    }

    // ---- Check 3: closed issues still in the issue table ----
    const issues = tabledIssues(text);
    if (issues.size > 0 && issues.size <= 30) {
        const closed = [];
        for (const num of issues) {
            if (ghIssueState(num, cwd) === 'CLOSED') closed.push(num);
        }
        if (closed.length > 0) {
            problems.push(
                `the issue table still lists ${closed.map((n) => `#${n}`).join(', ')}; `
                + `gh says CLOSED. Drop those rows.`
            );
        }
    }

    if (problems.length > 0) block(problems);
    allow();
}

try {
    main();
} catch {
    // Never wedge a session on this hook's own bug.
    allow();
}
