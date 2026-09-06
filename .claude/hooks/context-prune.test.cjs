#!/usr/bin/env node
/**
 * Tests for context-prune.cjs.
 *
 * The gh check is stubbed rather than left to fail open. A fixture repo has no
 * GitHub remote, so every real `gh` call throws, the check fails open, and a
 * test asserting "allow" would pass whether or not the logic under it works.
 * Sembr's handoff hook shipped that bug in its first draft and it was caught
 * only by deleting the logic and watching the test still pass. The stub is the
 * difference between testing this and not.
 *
 * Run: node .claude/hooks/context-prune.test.cjs
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const HOOK = path.join(__dirname, 'context-prune.cjs');

let passed = 0;
let failed = 0;

function check(name, condition, detail) {
    if (condition) {
        passed++;
        console.log(`  ok   ${name}`);
    } else {
        failed++;
        console.log(`  FAIL ${name}${detail ? `\n       ${detail}` : ''}`);
    }
}

/** A throwaway project dir with a context.md and a fake transcript. */
function fixture({ context, wroteContext = true, ghClosed = [] }) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'prune-'));
    fs.mkdirSync(path.join(dir, '.claude'), { recursive: true });
    fs.writeFileSync(path.join(dir, '.claude', 'context.md'), context);

    // Minimal transcript: one real user turn, then optionally a Write to the file.
    const entries = [
        { type: 'user', message: { role: 'user', content: 'do the handoff' } },
    ];
    if (wroteContext) {
        entries.push({
            type: 'assistant',
            message: {
                role: 'assistant',
                content: [{
                    type: 'tool_use',
                    name: 'Write',
                    input: { file_path: `${dir}/.claude/context.md` },
                }],
            },
        });
    }
    const transcript = path.join(dir, 'transcript.jsonl');
    fs.writeFileSync(transcript, entries.map((e) => JSON.stringify(e)).join('\n'));

    // A gh stub that reports CLOSED for the listed numbers, OPEN otherwise.
    const stub = path.join(dir, 'gh-stub.js');
    fs.writeFileSync(stub, `
        const n = process.argv[process.argv.indexOf('view') + 1];
        process.stdout.write(${JSON.stringify(ghClosed)}.includes(n) ? 'CLOSED' : 'OPEN');
    `);

    return { dir, transcript, stub };
}

function run({ dir, transcript, stub }, extraEvent = {}) {
    const event = JSON.stringify({ cwd: dir, transcript_path: transcript, ...extraEvent });
    const out = execFileSync(process.execPath, [HOOK], {
        input: event,
        encoding: 'utf8',
        env: { ...process.env, PRUNE_GH_BIN: `${process.execPath} ${stub}` },
    });
    return out.trim() ? JSON.parse(out) : null;
}

/**
 * The stub is a node script, not an executable, so it cannot be spawned by
 * path. Point the hook at a real shim instead.
 */
function shimStub(dir, stub) {
    const isWin = process.platform === 'win32';
    const shim = path.join(dir, isWin ? 'gh.cmd' : 'gh.sh');
    fs.writeFileSync(shim, isWin
        ? `@echo off\r\n"${process.execPath}" "${stub}" %*\r\n`
        : `#!/bin/sh\nexec "${process.execPath}" "${stub}" "$@"\n`);
    if (!isWin) fs.chmodSync(shim, 0o755);
    return shim;
}

function runWithGh(fx, extraEvent = {}) {
    const shim = shimStub(fx.dir, fx.stub);
    const event = JSON.stringify({ cwd: fx.dir, transcript_path: fx.transcript, ...extraEvent });
    const out = execFileSync(process.execPath, [HOOK], {
        input: event,
        encoding: 'utf8',
        env: { ...process.env, PRUNE_GH_BIN: shim },
    });
    return out.trim() ? JSON.parse(out) : null;
}

const SHORT = '# Ctx\n\n## Recent sessions\n\n### Session 20 (2026-09-06): a\n\ntext\n';

console.log('context-prune.cjs');

// A short file with nothing wrong is allowed.
check('allows a short, clean file', run(fixture({ context: SHORT })) === null);

// Size.
{
    const long = `# Ctx\n${'filler\n'.repeat(400)}`;
    const res = run(fixture({ context: long }));
    check('blocks an oversized file', res && res.decision === 'block');
    check('names the actual line count', res && /40\d lines against a 300 budget/.test(res.reason),
        res && res.reason);
}

// Session window.
{
    const many = '# Ctx\n\n## Recent sessions\n\n'
        + [20, 19, 18, 17, 16].map((n) => `### Session ${n} (2026-01-0${1}): thing\n\nbody\n`).join('\n');
    const res = run(fixture({ context: many }));
    check('blocks on too many session write-ups', res && res.decision === 'block');
    check('keeps the newest three by number', res && /keep the newest 3 \(20, 19, 18\)/.test(res.reason),
        res && res.reason);
    check('names only the stale ones to move',
        res && /Session 17/.test(res.reason) && /Session 16/.test(res.reason)
            && !/move these[^]*Session 20/.test(res.reason),
        res && res.reason);
}

// Session ordering is by number, not file position.
{
    const outOfOrder = '# Ctx\n\n## Recent sessions\n\n'
        + [16, 20, 17, 19, 18].map((n) => `### Session ${n} (2026-01-01): thing\n\nbody\n`).join('\n');
    const res = run(fixture({ context: outOfOrder }));
    check('orders sessions by number, not position',
        res && /keep the newest 3 \(20, 19, 18\)/.test(res.reason), res && res.reason);
}

// Closed issues in the table.
{
    const table = `${SHORT}\n| # | Title |\n|---|---|\n| 31 | open one |\n| 26 | closed one |\n`;
    const res = runWithGh(fixture({ context: table, ghClosed: ['26'] }));
    check('blocks on a closed issue still tabled', res && res.decision === 'block');
    check('names the closed issue and not the open one',
        res && /#26/.test(res.reason) && !/#31/.test(res.reason), res && res.reason);
}

// A clean table is allowed. This is the case that would pass vacuously without
// the stub, since a real gh would throw here and fail open.
{
    const table = `${SHORT}\n| # | Title |\n|---|---|\n| 31 | open one |\n`;
    check('allows a table of open issues',
        runWithGh(fixture({ context: table, ghClosed: [] })) === null);
}

// Scope and safety.
check('ignores a turn that did not write context.md',
    run(fixture({ context: `# Ctx\n${'filler\n'.repeat(400)}`, wroteContext: false })) === null);

check('does not re-enter when already blocked once',
    run(fixture({ context: `# Ctx\n${'filler\n'.repeat(400)}` }), { stop_hook_active: true }) === null);

check('allows when context.md does not exist', (() => {
    const fx = fixture({ context: SHORT });
    fs.unlinkSync(path.join(fx.dir, '.claude', 'context.md'));
    return run(fx) === null;
})());

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 1 - 1 : 1);
