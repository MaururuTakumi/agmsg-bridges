# S4 Front Desk Mesh E2E Evidence

Date: 2026-06-11
Primary repository: `/Users/takumihayashi/projects/agmsg-bridges`
Project team exercised: `cmux-dashboard`

## Scope

S4 request from `claude`:

1. Add an idempotent `front-desk` setup helper joining `concierge`, `openclaw`, and `hermes`.
2. Add the concierge agmsg receive protocol to `cmux-dashboard/templates/CONCIERGE.md` in a separate commit.
3. Add launchd plist templates and README startup examples for front-desk OpenClaw/Hermes bridges.
4. Prove:
   - OpenClaw natural-language request -> `front-desk/concierge` -> `cmux-dashboard/codex` -> reply -> OpenClaw.
   - Hermes natural-language request -> `front-desk/concierge` -> `cmux-dashboard/codex` -> reply -> Hermes.

No subagents were used. No push was performed.

## Static Implementation

Added:

```text
bin/setup-front-desk.sh
bin/launchd/com.agmsg-bridges.front-desk-openclaw.plist
bin/launchd/com.agmsg-bridges.front-desk-hermes.plist
docs/evidence/2026-06-11-s4-front-desk-mesh-e2e.md
```

Updated:

```text
bin/agmsg-bridge.sh
README.md
```

The bridge log/lock scope is now `team + agent`, so `front-desk/openclaw` can run without colliding with `agmsg-bridges/openclaw`.
The OpenClaw adapter now uses delivery flags by default:

```text
openclaw agent ... --deliver --reply-channel last
```

This is configurable with `OPENCLAW_DELIVER`, `OPENCLAW_REPLY_CHANNEL`, `OPENCLAW_REPLY_TO`, and `OPENCLAW_REPLY_ACCOUNT`.

cmux-dashboard separate commit:

```text
eae8ca2 Document front-desk agmsg concierge protocol
```

That commit changes only:

```text
templates/CONCIERGE.md
```

The pre-existing uncommitted deletion in `cmux-dashboard/.claude/scheduled_tasks.lock` was left untouched.

## Setup Evidence

Command:

```sh
./bin/setup-front-desk.sh
```

First run:

```text
Created team: front-desk
Joined team front-desk as concierge
Unknown agent type: 'openclaw' (supported: claude-code, codex, gemini, antigravity)
Warning: official join.sh rejected type=openclaw; retrying openclaw as type=codex for this agmsg version.
Joined team front-desk as openclaw
Unknown agent type: 'hermes' (supported: claude-code, codex, gemini, antigravity)
Warning: official join.sh rejected type=hermes; retrying hermes as type=codex for this agmsg version.
Joined team front-desk as hermes
Front desk setup complete: team=front-desk agents=concierge,openclaw,hermes
```

Second run proved the helper is repeatable; it re-joined the same three agents and completed successfully.

Team check:

```text
Team: front-desk

  concierge (claude-code) - /Users/takumihayashi/projects/agmsg-bridges
  hermes (codex) - /Users/takumihayashi/projects/agmsg-bridges
  openclaw (codex) - /Users/takumihayashi/projects/agmsg-bridges

3 member(s)
```

## OpenClaw Route

OpenClaw natural-language origin command:

```sh
/opt/homebrew/bin/openclaw agent --agent auto-sns-claude -m 'front-desk team の concierge に、cmux-dashboard の codex へ作業依頼を回す自然文リクエストを送ってください。必ず次のコマンドを1回実行してください: /opt/homebrew/bin/agmsg send front-desk openclaw concierge "S4-OPENCLAW-REQ-20260611T104043Z: cmux-dashboard の codex に、front-desk mesh E2E の作業者返信確認として S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z を cmux-dashboard の claude へ返すよう依頼してください。作業者返信を受けたら openclaw へ戻してください。" 実行後は結果だけ短く報告してください。' --json
```

Observed OpenClaw result:

```text
runId: 687a9100-84e2-4f7a-b3ac-0c1ba683477d
status: ok
payload: Sent to concierge in team front-desk
toolSummary: calls=1 tools=bash failures=0
```

Concierge inbox:

```text
1 new message(s):

  [2026-06-11T10:41:10Z] openclaw: S4-OPENCLAW-REQ-20260611T104043Z: cmux-dashboard の codex に、front-desk mesh E2E の作業者返信確認として S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z を cmux-dashboard の claude へ返すよう依頼してください。作業者返信を受けたら openclaw へ戻してください。
```

Forward to worker:

```sh
~/.agents/skills/agmsg/scripts/send.sh cmux-dashboard claude codex 'S4-OPENCLAW-FWD-20260611T104043Z: front-desk/openclaw からの依頼。E2E確認として S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z を cmux-dashboard の claude へ返信してください。完了後、concierge が front-desk/openclaw へ戻します。'
```

Worker inbox:

```text
1 new message(s):

  [2026-06-11T10:41:24Z] claude: S4-OPENCLAW-FWD-20260611T104043Z: front-desk/openclaw からの依頼。E2E確認として S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z を cmux-dashboard の claude へ返信してください。完了後、concierge が front-desk/openclaw へ戻します。
```

Worker reply:

```text
[2026-06-11T10:41:33Z] codex: S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z: codex worker received the front-desk/openclaw routed request and returns this E2E proof to concierge.
```

Final reply to OpenClaw:

```sh
~/.agents/skills/agmsg/scripts/send.sh front-desk concierge openclaw 'S4-OPENCLAW-FINAL-20260611T104043Z: cmux-dashboard/codex replied: S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z. Route proven openclaw -> front-desk/concierge -> cmux-dashboard/codex -> concierge -> openclaw.'
./bin/agmsg-bridge.sh front-desk openclaw openclaw --once
```

Bridge result:

```text
Dispatched new messages for front-desk/openclaw to openclaw
```

Bridge log excerpt:

```text
[2026-06-11T10:41:49Z] new_messages team=front-desk agent=openclaw output=1 new message(s): [2026-06-11T10:41:44Z] concierge: S4-OPENCLAW-FINAL-20260611T104043Z: cmux-dashboard/codex replied: S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z. Route proven openclaw -> front-desk/concierge -> cmux-dashboard/codex -> concierge -> openclaw.
[2026-06-11T10:42:11Z] adapter=openclaw gateway_with_agent_start
[2026-06-11T10:42:30Z] adapter=openclaw gateway_with_agent_success output=... "runId": "44290d45-9134-4e1c-8ec1-448256d197b2" ... "status": "ok" ... "text": "Sent to concierge in team front-desk" ...
[2026-06-11T10:42:30Z] dispatch_success team=front-desk agent=openclaw adapter=openclaw
```

OpenClaw ACK back to concierge:

```text
1 new message(s):

  [2026-06-11T10:42:29Z] openclaw: S4-OPENCLAW-ACK-20260611T104043Z: 受領しました。cmux-dashboard/codex から S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z の作業者返信確認済みです。
```

Result: PASS.

## Hermes Route

Hermes natural-language origin command:

```sh
~/.local/bin/hermes -z 'front-desk team の concierge に、cmux-dashboard の codex へ作業依頼を回す自然文リクエストを送ってください。必ず次のコマンドを1回実行してください: /opt/homebrew/bin/agmsg send front-desk hermes concierge "S4-HERMES-REQ-20260611T104242Z: cmux-dashboard の codex に、front-desk mesh E2E の作業者返信確認として S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z を cmux-dashboard の claude へ返すよう依頼してください。作業者返信を受けたら hermes へ戻してください。" 実行後は結果だけ短く報告してください。' --skills agmsg-protocol --yolo
```

Observed Hermes result:

```text
Sent to concierge in team front-desk
```

Concierge inbox:

```text
1 new message(s):

  [2026-06-11T10:43:01Z] hermes: S4-HERMES-REQ-20260611T104242Z: cmux-dashboard の codex に、front-desk mesh E2E の作業者返信確認として S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z を cmux-dashboard の claude へ返すよう依頼してください。作業者返信を受けたら hermes へ戻してください。
```

Worker route:

```text
[2026-06-11T10:43:13Z] claude -> codex: S4-HERMES-FWD-20260611T104242Z: front-desk/hermes からの依頼。E2E確認として S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z を cmux-dashboard の claude へ返信してください。完了後、concierge が front-desk/hermes へ戻します。
[2026-06-11T10:43:25Z] codex -> claude: S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z: codex worker received the front-desk/hermes routed request and returns this E2E proof to concierge.
```

Final reply to Hermes:

```sh
~/.agents/skills/agmsg/scripts/send.sh front-desk concierge hermes 'S4-HERMES-FINAL-20260611T104242Z: cmux-dashboard/codex replied: S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z. Route proven hermes -> front-desk/concierge -> cmux-dashboard/codex -> concierge -> hermes.'
./bin/agmsg-bridge.sh front-desk hermes hermes --once
```

Bridge result:

```text
Dispatched new messages for front-desk/hermes to hermes
```

Bridge log excerpt:

```text
[2026-06-11T10:43:39Z] new_messages team=front-desk agent=hermes output=1 new message(s): [2026-06-11T10:43:32Z] concierge: S4-HERMES-FINAL-20260611T104242Z: cmux-dashboard/codex replied: S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z. Route proven hermes -> front-desk/concierge -> cmux-dashboard/codex -> concierge -> hermes.
[2026-06-11T10:43:41Z] adapter=hermes max_turns_unsupported_retry_without_max_turns
[2026-06-11T10:43:41Z] adapter=hermes oneshot_start
[2026-06-11T10:43:52Z] adapter=hermes oneshot_success output=Sent to concierge in team front-desk
[2026-06-11T10:43:52Z] dispatch_success team=front-desk agent=hermes adapter=hermes
```

Hermes ACK back to concierge:

```text
1 new message(s):

  [2026-06-11T10:43:50Z] hermes: S4-HERMES-FINAL-ACK-20260611T104332Z: 受信確認しました。cmux-dashboard/codex からの返信 S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z により、hermes -> front-desk/concierge -> cmux-dashboard/codex -> concierge -> hermes の往復ルート proven を確認しました。
```

Result: PASS.

## History Excerpts

Front desk:

```text
  ○ [2026-06-11T10:41:10Z] openclaw -> concierge: S4-OPENCLAW-REQ-20260611T104043Z: ...
  ○ [2026-06-11T10:41:44Z] concierge -> openclaw: S4-OPENCLAW-FINAL-20260611T104043Z: ...
  ○ [2026-06-11T10:42:29Z] openclaw -> concierge: S4-OPENCLAW-ACK-20260611T104043Z: ...
  ○ [2026-06-11T10:43:01Z] hermes -> concierge: S4-HERMES-REQ-20260611T104242Z: ...
  ○ [2026-06-11T10:43:32Z] concierge -> hermes: S4-HERMES-FINAL-20260611T104242Z: ...
  ○ [2026-06-11T10:43:50Z] hermes -> concierge: S4-HERMES-FINAL-ACK-20260611T104332Z: ...
```

cmux-dashboard:

```text
  ○ [2026-06-11T10:41:24Z] claude -> codex: S4-OPENCLAW-FWD-20260611T104043Z: ...
  ○ [2026-06-11T10:41:33Z] codex -> claude: S4-CMUX-CODEX-REPLY-OPENCLAW-20260611T104043Z: ...
  ○ [2026-06-11T10:43:13Z] claude -> codex: S4-HERMES-FWD-20260611T104242Z: ...
  ○ [2026-06-11T10:43:25Z] codex -> claude: S4-CMUX-CODEX-REPLY-HERMES-20260611T104242Z: ...
```

## Verification

agmsg-bridges:

```sh
bash -n bin/agmsg-bridge.sh bin/setup.sh bin/setup-front-desk.sh
plutil -lint bin/launchd/com.agmsg-bridges.front-desk-openclaw.plist bin/launchd/com.agmsg-bridges.front-desk-hermes.plist
```

Observed:

```text
bin/launchd/com.agmsg-bridges.front-desk-openclaw.plist: OK
bin/launchd/com.agmsg-bridges.front-desk-hermes.plist: OK
```

cmux-dashboard:

```sh
git diff --check -- templates/CONCIERGE.md
bash -n test.sh
```

Observed: both passed with no output.

`./test.sh` was also attempted in `cmux-dashboard`. It produced many PASS lines through R4 checks but did not terminate during the existing R4 API action wait, so that non-required full suite attempt was stopped. This S4 cmux-dashboard change is a markdown-only protocol addition; the decisive S4 verification is the live agmsg/OpenClaw/Hermes route above.

## Channel Delivery Addendum

Late S4 addendum clarified that real OpenClaw/Hermes entry points are Discord/Slack channels, not terminal-only usage.

OpenClaw CLI support was verified with:

```sh
/opt/homebrew/bin/openclaw agent --help
```

Relevant supported flags:

```text
--channel <channel>        Delivery channel: last|telegram|whatsapp|discord|...|slack|...
--deliver                  Send the agent's reply back to the selected channel
--reply-account <id>       Delivery account id override
--reply-channel <channel>  Delivery channel override (separate from routing)
--reply-to <target>        Delivery target override (separate from session routing)
```

`openclaw doctor` was read-only. It reported the expected plugin metadata conflict warning:

```text
Left plugin install index in place because shared SQLite state has conflicting plugin install metadata for: acpx, brave, codex, discord, slack
```

It also reported a channel blocker for Slack group-origin testing:

```text
channels.slack.groupPolicy is "allowlist" but groupAllowFrom (and allowFrom) is empty - all group messages will be silently dropped.
```

No OpenClaw state or config was modified. Because no live Discord/Slack source channel and target were provided, and current doctor output says Slack group messages can be dropped by configuration, the live channel-origin E2E was not performed here. The bridge-side equivalent is covered by the OpenClaw delivery flag smoke below and by the CLI-origin agmsg route evidence above.

Delivery flag smoke command:

```sh
~/.agents/skills/agmsg/scripts/send.sh front-desk concierge openclaw 'S4-OPENCLAW-DELIVER-SMOKE-20260611T105200Z: verify bridge invokes OpenClaw with delivery flags and reply-channel last. Reply to concierge with S4-OPENCLAW-DELIVER-ACK-20260611T105200Z.'
./bin/agmsg-bridge.sh front-desk openclaw openclaw --once
```

Bridge result:

```text
Dispatched new messages for front-desk/openclaw to openclaw
```

Bridge log excerpt:

```text
[2026-06-11T10:52:29Z] adapter=openclaw delivery deliver=1 reply_channel=last reply_to=none reply_account=none
[2026-06-11T10:52:34Z] adapter=openclaw gateway_with_agent_start
[2026-06-11T10:52:46Z] adapter=openclaw gateway_with_agent_success output=... "runId": "ed412f58-6bab-4ead-95eb-9c27e9042519" ... "status": "ok" ... "text": "Sent to concierge in team front-desk" ...
[2026-06-11T10:52:46Z] dispatch_success team=front-desk agent=openclaw adapter=openclaw
```

ACK proof:

```text
1 new message(s):

  [2026-06-11T10:52:43Z] openclaw: S4-OPENCLAW-DELIVER-ACK-20260611T105200Z
```

Result: PASS for bridge invocation with OpenClaw delivery flags. Live Discord/Slack channel delivery remains blocked on an actual channel source/target and current OpenClaw channel configuration.

## Boundary Checks

- Used only official agmsg scripts or `/opt/homebrew/bin/agmsg`; no direct DB/team file edits.
- Did not modify `~/Documents/openclaw`.
- Did not modify OpenClaw or Hermes config bodies.
- Did not install launchd jobs; only added plist templates.
- Did not push.
