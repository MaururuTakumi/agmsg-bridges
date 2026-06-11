# Sprint 1 OpenClaw E2E Evidence

Date: 2026-06-11
Team: bridge-e2e
Bridge agent: openclaw
Adapter: openclaw

## Setup

Command:

```sh
./bin/setup.sh
```

Observed result:

```text
Created team: bridge-e2e
Joined team bridge-e2e as claude
Unknown agent type: 'openclaw' (supported: claude-code, codex, gemini, antigravity)
Warning: official join.sh rejected type=openclaw; retrying openclaw as type=codex for this agmsg version.
Joined team bridge-e2e as openclaw
Setup complete: team=bridge-e2e agents=claude,openclaw
```

Note: the installed official `join.sh` rejects `type=openclaw`, so setup first tries the requested type and then falls back to `type=codex` to keep the official-script-only E2E path working.

## Attempt 1

Sent:

```text
claude -> openclaw: 応答テスト: 1+1は? agmsgで返信して
```

Bridge result:

```text
Adapter failed; skipped messages for bridge-e2e/openclaw
```

Cause from `bin/.bridge-openclaw.log`: `openclaw agent -m ... --json` required an explicit target session or agent id. The adapter was updated to retry with the detected default OpenClaw agent.

## Attempt 2

Sent:

```text
claude -> openclaw: 応答テスト: 1+1は? agmsgで返信して
```

Bridge result:

```text
Dispatched new messages for bridge-e2e/openclaw to openclaw
```

Received via official inbox script:

```text
1 new message(s):

  [2026-06-11T08:54:48Z] openclaw: 1+1は2です。
```

Official history excerpt:

```text
  ○ [2026-06-11T08:53:15Z] claude → openclaw: 応答テスト: 1+1は? agmsgで返信して
  ○ [2026-06-11T08:54:22Z] claude → openclaw: 応答テスト: 1+1は? agmsgで返信して
  ○ [2026-06-11T08:54:48Z] openclaw → claude: 1+1は2です。
```
