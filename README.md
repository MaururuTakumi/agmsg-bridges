# agmsg Bridges

Local bridge scripts for connecting `agmsg` teams to OpenClaw and Hermes without modifying agmsg internals or OpenClaw/Hermes config files.

## Flow

```text
reply path:
claude/codex -> agmsg -> bridge agent inbox -> OpenClaw/Hermes -> agmsg reply -> claude/codex

window-origin path:
user -> OpenClaw/Hermes -> agmsg send -> claude/codex -> agmsg reply -> bridge -> OpenClaw/Hermes -> user
```

## Setup

Run the helper from this repository. It uses the official agmsg `join.sh` script and registers `claude`, `openclaw`, and `hermes` for the selected team.

```sh
cd /Users/takumihayashi/projects/agmsg-bridges
./bin/setup.sh agmsg-bridges
```

Install the `agmsg-protocol` skill/instructions into the OpenClaw workspace and Hermes local skills area. Do not edit OpenClaw or Hermes config bodies.

```text
OpenClaw: ~/.openclaw/workspace/skills/agmsg-protocol/SKILL.md
Hermes:   ~/.hermes/skills/devops/agmsg-protocol/SKILL.md
```

The skill should teach the agent to use the global `agmsg` command, inspect teams, and send work with:

```sh
/opt/homebrew/bin/agmsg send <team> <from-agent> <to-agent> "<message>"
```

## Bridge Startup

Run a bridge in the foreground for each window agent that should receive replies from agmsg.
The Hermes adapter preloads `agmsg-protocol` by default via `HERMES_SKILLS=agmsg-protocol`.

```sh
./bin/agmsg-bridge.sh agmsg-bridges openclaw openclaw --interval 15
./bin/agmsg-bridge.sh agmsg-bridges hermes hermes --interval 15
```

For a single polling pass during tests:

```sh
./bin/agmsg-bridge.sh agmsg-bridges hermes hermes --once
```

Logs and lock directories stay under `bin/`:

```text
bin/.bridge-openclaw.log
bin/.bridge-hermes.log
bin/.bridge-openclaw.lock
bin/.bridge-hermes.lock
```

## Send Examples

Claude to Hermes reply-path test:

```sh
/opt/homebrew/bin/agmsg send agmsg-bridges claude hermes "2+3はいくつですか。agmsgでclaudeへ返信してください。"
./bin/agmsg-bridge.sh agmsg-bridges hermes hermes --once
/opt/homebrew/bin/agmsg inbox agmsg-bridges claude
```

OpenClaw window-origin round trip:

```sh
/opt/homebrew/bin/openclaw agent --agent auto-sns-claude -m 'claudeにagmsgで質問してください: 7+8はいくつですか。返信を待つため、結果はagmsgでopenclawに返すよう依頼してください。' --json
./bin/agmsg-bridge.sh agmsg-bridges openclaw openclaw --once
```

Hermes window-origin send:

```sh
~/.local/bin/hermes -z 'claudeにagmsgで「窓口テスト成功」と送ってください。必ず /opt/homebrew/bin/agmsg send agmsg-bridges hermes claude "窓口テスト成功" を実行してください。' --skills agmsg-protocol --yolo
```

## Constraints

- Use official agmsg scripts or `/opt/homebrew/bin/agmsg`; do not read or write agmsg DB or team data directly.
- Do not modify `~/Documents/openclaw`.
- Do not edit OpenClaw or Hermes config body files for this bridge.
- Pushes are out of scope for this repository task.
