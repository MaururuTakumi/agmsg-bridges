# 計画: agmsg ⇄ OpenClaw / Hermes ブリッジ
- 作成: 2026-06-11 / 設計・監査: Fable 5 / 実装: codex / 評価: Opus
- リポジトリ: ~/projects/agmsg-bridges（新規。~/.agents/skills/agmsg 本体と ~/Documents/openclaw は**変更禁止**）

## 1. 背景とゴール
agmsg（SQLite ベースのローカルエージェント間メッセージング。現状 Claude Code/Codex/Gemini 対応）に、このデバイスに導入済みの **OpenClaw**（/opt/homebrew/bin/openclaw、gateway型）と **Hermes**（~/.local/bin/hermes、gateway 稼働中）を参加させる。

受け入れ基準（live E2E・実機必須）:
1. claude から `agmsg send <team> claude openclaw "..."` → ブリッジが openclaw を起こす → **openclaw が `agmsg send` で実返信** → claude の inbox に届く（往復成立）。
2. 同様に hermes との往復が成立。
3. ブリッジは新着のみ処理（high-water mark）・多重起動防止（lock）・エージェント不在時は安全にスキップしログに残す。
4. agmsg 本体のスクリプト/DB/teams を一切変更しない（join.sh 等の公式スクリプト経由のみ）。
5. README にセットアップ手順（join → bridge 起動 → 送信例）。

## 2. スコープ
- やること: 汎用ポーリングブリッジ + openclaw/hermes アダプタ + join ヘルパ + live E2E スクリプト + README。
- やらないこと: agmsg 本体改造、openclaw/hermes 本体設定の書き換え（読み取りと CLI 呼び出しのみ）、リモートネットワーク連携、~/Documents/openclaw（別件進行中）への接触。

## 3. 設計判断（実証済みパターンの汎用化）
- **送信方向（openclaw/hermes → agmsg）**: 両者ともシェルツールを持つため、グローバル `/opt/homebrew/bin/agmsg`（導入済みディスパッチャ）を wake 文中で案内するだけ。専用実装ゼロ。
- **受信方向（agmsg → openclaw/hermes）**: `bin/agmsg-bridge.sh <team> <agent> <adapter>` — inbox.sh ではなく history.sh/SQLite読み出し…**ではなく公式 scripts のみ**: `inbox.sh <team> <agent>` を定期実行し、新着があれば1回だけアダプタを起動（hwm は inbox.sh が既読管理するためブリッジ側は「新着有無」判定のみで良い。要確認: inbox.sh が既読化するか→するなら wake 文に本文を同梱）。cmux-dashboard の collab-delivery と同じ思想。
  - adapter=openclaw: `openclaw agent -m "<wake文>" --json`（gateway 経由1ターン。--agent <id> は config から既定解決）
  - adapter=hermes: `hermes -z "<wake文>" --yolo --max-turns 6`（ワンショット・シェルツール許可）
  - wake文テンプレ: 「agmsg で <from> から新着: <本文>。返信は必ず `agmsg send <team> <you> <from> "<返事>"` を実行せよ。実行できない場合は理由を述べよ。」
- **常駐**: まず手動/フォアグラウンドの watch ループ（`--interval 15`）。launchd 化は E2E 合格後の任意項目。
- 却下案: agmsg 本体に新 type を実装（本体改造になる・join.sh は type 文字列を受けるため不要）/ webhook 連携（両者の gateway 設定変更が必要で侵襲的。CLI ワンショットで十分）。

## 4. タスク分解
| # | タスク | 担当 | 完了条件 | 依存 |
|---|---|---|---|---|
| 0 | scaffold + 本計画 | fable | 済 | - |
| 1 | bin/agmsg-bridge.sh（汎用ポーラ+lock+log）+ openclaw アダプタ + join ヘルパ(bin/setup.sh: team へ openclaw/hermes を join) + **live E2E**: claude→openclaw 往復 | codex | E2E 証跡（実際の返信メッセージID） | 0 |
| 2 | hermes アダプタ + live E2E: claude→hermes 往復 | codex | 同上 | 1 |
| 3 | README + 評価（Opus: 設計照合 + E2E 再現） | Opus | 全受入基準合格 | 2 |

## 5. リスク・未決事項
- inbox.sh の既読セマンティクス（ブリッジが読むとエージェント本人が読めない）→ wake 文に本文を**全文同梱**して解決（dashboard 方式）。
- openclaw gateway が落ちている場合 → `--local` フォールバック or スキップ+ログ。hermes も同様（gateway は現在稼働中）。
- hermes --yolo の安全性 → wake 文プロトコルは「agmsg send の実行」のみ要求。破壊的指示は含めない。
- 既存の「hermes 監視プロジェクト」(~/Documents/openclaw で別 codex 進行中) と衝突しないこと → 本リポジトリ外に書き込まない。

## 6. codexへの指示文（コピペ可）
S1: 「~/projects/agmsg-bridges で作業。計画書 docs/plans/2026-06-11-openclaw-hermes-bridge.md §3 に従い bin/agmsg-bridge.sh・openclaw アダプタ・bin/setup.sh を実装。agmsg 公式 scripts のみ使用（DB直読禁止）。live E2E: team=bridge-e2e を作り claude と openclaw を join → claude から send → ブリッジ1周 → openclaw の実返信を inbox で確認。証跡（送受信メッセージの実文面）を添えて報告。完遂まで止まるな」
S2: 「hermes アダプタを追加し同様の live E2E。hermes は `-z --yolo --max-turns 6`。証跡添付」

## 7. Evaluator観点（Opus）
- 静的: agmsg 本体/openclaw設定/hermes設定への書き込みが無いこと（git status とファイル mtime）。lock/hwm/スキップの実装。wake 文に返信プロトコルと本文全文。
- 動的: bin/setup.sh から素の状態で E2E を**自分で再実行**し、openclaw・hermes 双方の往復を確認（メッセージIDと文面を証跡化）。タイムアウトや gateway 停止時の挙動（スキップ+ログ）も1ケース確認。
