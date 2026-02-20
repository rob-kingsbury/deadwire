# Session Handoff

Execute the full session end procedure to ensure clean handoff.

## When to Use

Run `/handoff` at the end of every session, or when the user says "handoff" or "end session".

## What This Skill Does

1. **Persists incomplete work** - Creates GitHub Issues for unfinished tasks
2. **Updates context.md** - Records what was done this session
3. **Updates HANDOFF.md** - Records current state for next session
4. **Cleans workspace** - Removes temp files, checks for stray data
5. **Commits and pushes** - Saves all changes to GitHub
6. **Provides next step** - Tells user what to continue with

## Instructions

Execute these steps in order:

### Step 1: Check Git Status

```bash
git status
```

Note uncommitted changes for the commit step.

### Step 2: Persist Todos to GitHub Issues

Check for any incomplete work or mentioned "todos" from this session. For each:

```bash
gh issue create --title "[Task title]" --body "[Description of what remains]" --label "enhancement"
```

Record issue numbers created.

### Step 3: Clean Workspace

```bash
# Find temp/test directories
find . -type d \( -name "temp_*" -o -name "test_*" -o -name "*_temp" -o -name "*_old" \) -not -path "./.git/*" 2>/dev/null

# Find empty directories
find . -type d -empty -not -path "./.git/*" -not -path "*/common/*" 2>/dev/null

# Find temp/backup files
find . \( -name "*.bak" -o -name "*.tmp" -o -name "*~" -o -name "*.orig" \) -not -path "./.git/*" 2>/dev/null

# Find stray data files
ls *.zip *.csv *.log 2>/dev/null
```

Ask user before deleting anything found.

### Step 4: Update context.md

Edit `.claude/context.md`:

1. Increment `last_session:` in YAML header
2. Update `continue_with:` to reflect next priority
3. Add session notes under "Recent Changes" with:
   - Date and session number
   - Summary of what was completed
   - Files modified/created
   - Issues created/closed
4. Keep only the last 3-5 session entries to prevent bloat

### Step 5: Update HANDOFF.md

Update `HANDOFF.md` with:
- Current Priority (what to work on next)
- Status table (phase progress)
- Any blockers or decisions made
- Files modified this session
- Next steps

### Step 6: Commit and Push

Stage specific files (not `git add -A`):

```bash
git add [specific files]
git status
```

Review staged files. If sensitive files are staged, unstage them.

Then commit:

```bash
git commit -m "$(cat <<'EOF'
Session [N]: [Summary of work]

- [Change 1]
- [Change 2]

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

Then push:

```bash
git push origin HEAD
```

### Step 7: Output Summary

```
=== HANDOFF COMPLETE ===

Session [N] finished.
- [X] files modified
- [X] issues created
- [X] issues closed

Next session: Continue with [priority]

To resume: "Deadwire - [continue_with value]"
```

## Important Rules

- **Never skip documentation updates** - Next session depends on accurate state
- **Always check for sensitive data** before committing
- **Create issues for incomplete work** - Don't lose track of tasks
- **Push changes** - Don't leave uncommitted work

## If There's Nothing to Commit

If no changes were made this session:

```
Session complete. No changes to commit.
Continue with: [priority]
```
