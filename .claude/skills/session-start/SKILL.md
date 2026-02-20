# Session Start

Initialize a new working session with full project context.

## When to Use

Run `/session-start` at the beginning of every session, or when you need to refresh context.

## What This Skill Does

1. **Loads context files** - Reads project state, handoff notes, and rules
2. **Checks GitHub Issues** - Gets open issues and identifies priority
3. **Outputs confirmation** - Shows readiness status with next action

## Instructions

Execute these steps in order:

### Step 1: Read Context Files

Read these files in parallel to understand current project state:

```
.claude/context.md
HANDOFF.md
.claude/rules/development-workflow.md
```

If any file is missing, note it but don't fail.

### Step 2: Check GitHub Issues

Run this command to see open issues:

```bash
gh issue list --state open --limit 10
```

Count the total open issues and identify the highest priority item based on:
- Issues labeled `priority-high`
- Issues in the current phase (check context.md for `current_phase`)
- Bug issues (take precedence over features)

### Step 3: Extract Context

From `context.md`, extract:
- `project:` field (project name)
- `continue_with:` field (next priority)
- `last_session:` field (session number)

### Step 4: Output Confirmation

Display this confirmation format:

```
Deadwire ready. [X] open issues. Priority: [continue_with value]
Session: [last_session + 1]
Files loaded: [list of files read]

Open Issues:
#XX - Title [label]
...
```

If no issues exist yet:

```
Deadwire ready. No open issues. Priority: [continue_with value]
Session: [last_session + 1]
Files loaded: [list of files read]
```

## After Session Start

You are now ready to:
- Work on the priority item
- Ask the user what they'd like to focus on
- Run `gh issue list --label <label>` to filter by category

Do NOT begin coding until the user confirms what to work on.
