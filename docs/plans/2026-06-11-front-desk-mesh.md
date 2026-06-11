# 計画: front-desk メッシュ — 全入口をコンシェルジュに収束させる
- 作成: 2026-06-11 / 設計: Fable 5 / 実装: codex / 検証: claude+実E2E

## ゴール（ベストプラクティスの形）
```
あなた ─┬─ dashboard(🤖ボタン/ペイン会話) ─┐
        ├─ openclaw(チャネル経由) ──agmsg──┤→ front-desk team → コンシェルジュclaude(ハブ)
        └─ hermes ────────────agmsg──┘        │ 判断: どのプロジェクト/誰に振るか
                                               ├→ dashboard API(列を開く/プロジェクト作成)
                                               ├→ 各プロジェクトteamへ agmsg send(可視ペインが動く)
                                               └→ 返信を依頼元へ agmsg(ブリッジが窓口へ戻す)
```
受入基準(E2E): 「openclaw に自然文で『cmux-dashboard の codex に◯◯を頼んで』→ front-desk → コンシェルジュが該当 team へ転送 → 作業者の返信が openclaw まで戻る」一連の実証跡。hermes でも同様。

## タスク(S4・codex)
1. bin/setup-front-desk.sh: team=front-desk に concierge(claude-code)/openclaw/hermes を join(冪等)。
2. コンシェルジュ運用: cmux-dashboard の templates/CONCIERGE.md に「agmsg 受信プロトコル」を追記(front-desk の inbox 確認・依頼の解釈・宛先 team への転送・依頼元への返信)。※cmux-dashboard リポジトリ側 — 1コミット分離。
3. ブリッジ常駐: launchd plist 雛形(bin/launchd/)と README 追記(openclaw/hermes 用 front-desk ブリッジの起動例)。
4. E2E: 上記受入基準を実走し docs/evidence へ。
制約: 既存どおり(本体config不変・~/Documents/openclaw不可侵)。完遂→agmsg報告。
