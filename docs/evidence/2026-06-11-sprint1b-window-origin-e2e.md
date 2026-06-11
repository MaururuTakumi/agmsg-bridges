# Sprint 1b Window-Origin agmsg E2E Evidence

Date: 2026-06-11
Team: agmsg-bridges
Target inbox: claude

## Scope

Sprint 1b changed the primary flow so OpenClaw and Hermes act as the user-facing window and initiate agmsg work:

```text
user -> openclaw/hermes -> agmsg send -> claude/codex
```

No OpenClaw or Hermes config file was edited. Only skill/instruction files were added.

## Added Skill Files

OpenClaw workspace skill:

```text
~/.openclaw/workspace/skills/agmsg-protocol/SKILL.md
```

OpenClaw recognition:

```text
agmsg-protocol ✓ Ready
Source: openclaw-workspace
Path: ~/.openclaw/workspace/skills/agmsg-protocol/SKILL.md
Visible to model: yes
Available as command: yes
```

Hermes local skill:

```text
~/.hermes/skills/devops/agmsg-protocol/SKILL.md
```

Hermes recognition:

```text
│ agmsg-protocol        │ devops               │ local    │ local    │ enabled │
```

## Team Setup

Command:

```sh
~/.agents/skills/agmsg/scripts/team.sh agmsg-bridges
```

Observed result:

```text
Team: agmsg-bridges

  claude (claude-code) — /Users/takumihayashi/projects/agmsg-bridges
  codex (codex) — /Users/takumihayashi/projects/agmsg-bridges
  hermes (codex) — /Users/takumihayashi/projects/agmsg-bridges
  openclaw (codex) — /Users/takumihayashi/projects/agmsg-bridges

4 member(s)
```

Note: this agmsg version accepts `claude-code`, `codex`, `gemini`, and `antigravity` as agent types, so `openclaw` and `hermes` are registered as agent names with compatibility type `codex`.

## OpenClaw E2E

Requested command shape from Sprint 1b:

```sh
/opt/homebrew/bin/openclaw agent -m 'claudeにagmsgで「窓口テスト成功」と送ってください。必ず /opt/homebrew/bin/agmsg send agmsg-bridges openclaw claude "窓口テスト成功" を実行して、結果だけ短く報告してください。' --json
```

Observed result:

```text
Error: No target session selected. Use --agent <id>, --session-key <key>, --session-id <id>, or --to <E.164>. Run openclaw agents list to see agents.
```

Working command with the configured default OpenClaw agent made explicit:

```sh
/opt/homebrew/bin/openclaw agent --agent auto-sns-claude -m 'claudeにagmsgで「窓口テスト成功」と送ってください。必ず /opt/homebrew/bin/agmsg send agmsg-bridges openclaw claude "窓口テスト成功" を実行して、結果だけ短く報告してください。' --json
```

Observed result excerpt:

```json
{
  "runId": "080befe2-c84b-419c-95d9-defef03b7225",
  "status": "ok",
  "summary": "completed",
  "result": {
    "payloads": [
      {
        "text": "Sent to claude in team agmsg-bridges"
      }
    ]
  }
}
```

The OpenClaw run's system prompt report included `agmsg-protocol` in its skills list, and tool summary reported one `bash` call with zero failures.

Claude inbox proof via official script:

```sh
~/.agents/skills/agmsg/scripts/inbox.sh agmsg-bridges claude
```

Observed result:

```text
1 new message(s):

  [2026-06-11T09:19:01Z] openclaw: 窓口テスト成功
```

## Hermes E2E

Planned command shape from the original S1 Hermes adapter used `--max-turns 6`, but the current Hermes CLI rejects that option in one-shot mode:

```text
hermes: error: argument command: invalid choice: '6'
```

Working current-CLI command:

```sh
~/.local/bin/hermes -z 'claudeにagmsgで「窓口テスト成功」と送ってください。必ず /opt/homebrew/bin/agmsg send agmsg-bridges hermes claude "窓口テスト成功" を実行して、結果だけ短く報告してください。' --skills agmsg-protocol --yolo
```

Observed result:

```text
Sent to claude in team agmsg-bridges
```

Claude inbox proof via official script:

```sh
~/.agents/skills/agmsg/scripts/inbox.sh agmsg-bridges claude
```

Observed result:

```text
1 new message(s):

  [2026-06-11T09:19:39Z] hermes: 窓口テスト成功
```

## Result

PASS:

- OpenClaw has a workspace-visible `agmsg-protocol` skill and can initiate `agmsg send` from a natural-language window instruction.
- Hermes has an enabled local `agmsg-protocol` skill and can initiate `agmsg send` from a natural-language window instruction.
- Both messages arrived in `claude`'s `agmsg-bridges` inbox via official agmsg scripts.
- No OpenClaw/Hermes config body edits were required.

## Static Verification

Repository status before committing:

```text
?? docs/evidence/2026-06-11-sprint1b-window-origin-e2e.md
```

Shell syntax check:

```sh
bash -n bin/agmsg-bridge.sh bin/setup.sh
```

Observed result: passed with no output.

Config and added skill mtimes:

```text
Apr  1 16:30:30 2026 /Users/takumihayashi/.openclaw/config.json
Jun 10 18:33:34 2026 /Users/takumihayashi/.openclaw/openclaw.json
Jun 10 18:34:29 2026 /Users/takumihayashi/.hermes/config.yaml
Jun 11 18:16:32 2026 /Users/takumihayashi/.openclaw/workspace/skills/agmsg-protocol/SKILL.md
Jun 11 18:16:32 2026 /Users/takumihayashi/.hermes/skills/devops/agmsg-protocol/SKILL.md
```
