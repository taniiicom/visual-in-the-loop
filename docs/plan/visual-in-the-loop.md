# Plan: `visual-in-the-loop` Agent Skill

## Context

エージェント (Claude Code / Codex / spec-kit など) が plan agent / plan mode / clarify で作る plan を、人がレビューするのが大変。テキストの壁を読み下すのは認知負荷が高い。

そこで、エージェントが**ユーザに意思決定を求めるタイミング** (`AskUserQuestion`, `ExitPlanMode` 等) に Nano Banana Pro (`gemini-3-pro-image-preview`) で **1 枚の図** を生成し、人間の目に届けてレビュー負荷を下げる Agent Skill を作る。配布リポジトリは `/Users/taniiicom/projects/_libraries/skills-visual-in-the-loop`。

### 設計原則 (絶対遵守)

1. **本質を見失わない** — nano banana の性能を信じる。Mermaid/D2 フォールバックを入れない。可視化レイヤを限定しない
2. **シンプル第一** — プロンプト設計を作り込まない。1 行プロンプトから始めて、結果でチューン
3. **同期実行** — ビジュアル完成後に質問を表示。「画像なしでユーザを呼ぶ」を絶対回避
4. **コスト最適化は後** — 閾値・キャッシュは今は入れない
5. **表示は環境検出で ①③④ から選ぶ** — ② (escape sequence) は Claude Code TUI 下で食われ不採用、⑤ (HTTP) は大袈裟で不採用
6. **エージェントに画像を見せない** — 人間の目に届く別経路を確保。エージェントは生成依頼と表示コマンド発行だけ

## 規約調査結果に基づくレイアウト

### 配布レイアウト = `skills/<name>/SKILL.md` (モノレポ式)

主要 skills repo 全てがこのパターン:

| repo | スキル数 | レイアウト |
|---|---|---|
| `anthropics/skills` | 16+ | `skills/<name>/SKILL.md` |
| `vercel-labs/agent-skills` | 6+ | `skills/<name>/SKILL.md` |
| `mastra-ai/skills` | 1+ | `skills/<name>/SKILL.md` |

`npx skills add <owner/repo>` は GitHub 上の `skills/<name>/SKILL.md` を直接参照してインストールする。ルート `SKILL.md` だと検出されない可能性が高い。さらに、将来スキルを追加する余地が残る。

### 実装言語 = Node.js (依存ゼロ、`fetch` で REST API 直叩き)

- `npx skills add` 自体が Node 前提 → 利用者環境に Node は必ずある
- Python は別途インストール要求になり、配布ハードルが上がる
- Node 18+ の標準 `fetch` で Gemini REST API を直接叩けば **依存ゼロ** (`@google/genai` SDK さえ不要)
- `package.json` も不要、`npm install` も不要、`npx skills add` 直後にそのまま動く

これは設計原則 2「シンプル第一」と完全一致。

## 推奨アプローチ: skill 駆動単独 (MVP)

Hook は MVP では採用しない。理由:

- `PreToolUse` hook で `AskUserQuestion` の result data がストリップされる既知バグ (Issue #12031)
- `ExitPlanMode` は `PreToolUse` ではなく `PermissionRequest` matcher が必要 (Issue #12605)
- `AskUserQuestion` を確実に捕まえる hook 経路が現状無い
- 半端な hook で `ExitPlanMode` だけ捕まえても clarify / 途中の意思決定がカバーできない

代わりに **SKILL.md の `description` を pushy に書き**、エージェントが意思決定タイミングで自発的に呼ぶ形にする。将来 hook が安定したら `references/hook-example.md` を追加して補強する余地は残す。

## ファイル構造

```
skills-visual-in-the-loop/             (= repo root)
├── skills/
│   └── visual-in-the-loop/
│       ├── SKILL.md                   # 新規: フロントマター + 使い方
│       ├── scripts/
│       │   ├── generate.mjs           # 新規: Node 18+, fetch で Gemini API
│       │   ├── show.sh                # 新規: bash, 環境検出 ①③④
│       │   └── run.sh                 # 新規: bash, generate → show ラッパ
│       └── references/
│           └── prompt-template.md     # 新規: 初期プロンプト (3 行)
├── .claude/commands/                  # (既存) 開発用 slash commands
└── .gitignore                         # (既存) tmp/ ignore 済み
```

**判断**: 単一スキル始まりでもデファクトの `skills/<name>/` を採る。`npx skills add owner/visual-in-the-loop --skill visual-in-the-loop` で配布可能になる。

## 各ファイルの中身

### `skills/visual-in-the-loop/SKILL.md`

フロントマター:

```yaml
---
name: visual-in-the-loop
description: >
  Generate a single visual (Nano Banana Pro / Gemini 3 Pro Image) of any
  plan, spec, or design BEFORE asking the user to review or decide. USE
  PROACTIVELY whenever about to call AskUserQuestion, ExitPlanMode, or
  otherwise request human review of a multi-step plan, ambiguous spec,
  architecture choice, UI mockup, or conceptual design. Blocks until the
  image is rendered to the user's environment (open / tmux+chafa / VS Code
  markdown). Call FIRST, then present the question. Humans review plans much
  faster with a visual — do not describe diagrams in text and skip this.
allowed-tools: Bash
license: MIT
---
```

本文 (~80 行):

- **When to use** — 3-4 行で再強調 (undertrigger 補正)
- **How to use** — 1 ステップ:
  ```bash
  echo "<plan or question text>" | bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"
  ```
- **What happens** — generate.mjs が PNG 生成 → show.sh が 1 経路選んで表示 → exit 0
- **Failure mode** — `run.sh` が非 0 で返ったら画像なしで通常通り質問する
- **Do not** — Mermaid 等にフォールバックしない / 質問を先に出さない / バックグラウンド化しない

### `scripts/generate.mjs` (約 50 行、Node 18+, 依存ゼロ)

- 入力: stdin (plan / 質問テキスト, UTF-8)
- env: `GEMINI_API_KEY` または `GOOGLE_API_KEY`
- 処理 (擬似コード):
  ```js
  import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
  import { tmpdir } from 'node:os';
  import { join } from 'node:path';

  const apiKey = process.env.GEMINI_API_KEY ?? process.env.GOOGLE_API_KEY;
  const planText = readFileSync(0, 'utf-8');               // stdin
  const template = readFileSync(join(import.meta.dirname, '../references/prompt-template.md'), 'utf-8');
  const prompt = template.replace('{plan}', planText);

  const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent';
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseModalities: ['TEXT', 'IMAGE'] },
    }),
  });
  if (!resp.ok) { process.exit(1); }
  const json = await resp.json();
  const part = json.candidates?.[0]?.content?.parts?.find(p => p.inlineData);
  if (!part) { process.exit(1); }
  const outDir = join(tmpdir(), 'visual-in-the-loop');
  mkdirSync(outDir, { recursive: true });
  const out = join(outDir, `${Date.now()}.png`);
  writeFileSync(out, Buffer.from(part.inlineData.data, 'base64'));
  process.stdout.write(out + '\n');
  ```
- 出力: PNG パスを stdout 1 行のみ。失敗時は stderr に WARN + exit 1
- 保存先: `${TMPDIR}/visual-in-the-loop/<timestamp>.png` (OS の tmp、ユーザ project を汚さない)

### `references/prompt-template.md` (3 行)

```
A single clear visual that helps a human reviewer quickly grasp the following plan.
Choose the most fitting form (concept sketch, architecture diagram, UI mockup) for the content.
Be faithful to the text. Do not invent details.

PLAN:
{plan}
```

シンプルから開始。チューニングはここを編集するだけで完結。

### `scripts/show.sh` (約 30 行)

判定ロジック (上から評価、最初に match した経路を使う):

```sh
#!/usr/bin/env bash
IMG="$1"
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null && command -v chafa >/dev/null; then
    tmux split-window -h -d "chafa --size=80x40 '$IMG'; read"           # ③
elif [ "${TERM_PROGRAM:-}" = "vscode" ] && command -v code >/dev/null; then
    MD=$(mktemp -t vitl).md
    printf '![plan](%s)\n' "$IMG" > "$MD"
    code --reuse-window "$MD"                                            # ④
elif [ "$(uname -s)" = "Darwin" ]; then
    open "$IMG"                                                          # ①
elif command -v xdg-open >/dev/null; then
    xdg-open "$IMG"                                                      # ①
else
    echo "[visual-in-the-loop] no display path available" >&2
    exit 0
fi
```

**実装しないもの**:
- ② ターミナル直描画 (Claude Code TUI 下で escape sequence が食われる)
- ⑤ HTTP サーバ (port 管理が複雑、原則「シンプル」と矛盾)

### `scripts/run.sh` (約 15 行)

```sh
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMG=$(node "$SCRIPT_DIR/generate.mjs")
if [ -z "$IMG" ] || [ ! -f "$IMG" ]; then
    echo "[visual-in-the-loop] generation failed, continuing without visual" >&2
    exit 0
fi
bash "$SCRIPT_DIR/show.sh" "$IMG" || true
echo "[visual-in-the-loop] rendered: $IMG"
```

すべての失敗パスを **exit 0** に収束させて、skill のせいで質問体験を止めない。

## 失敗モードと対応

| 失敗 | 検知 | 対応 |
|---|---|---|
| API key 未設定 | `generate.mjs` で env チェック | exit 1 → `run.sh` exit 0 で素通り |
| ネットワーク / API エラー | fetch resp.ok false | exit 1 → 素通り |
| 画像 part が返らない (TEXT のみ) | parts.find で inlineData なし | exit 1 → 素通り |
| tmux 不在なのに `$TMUX` だけセット | `command -v tmux` も AND | 検知して次の候補へ |
| chafa 不在 | `command -v chafa` も AND | 検知して次の候補へ |
| VS Code 未インストール | `command -v code` も AND | 検知して次の候補へ |
| `open` / `xdg-open` 両方無い (CI/ssh 等) | else 分岐 | WARN + exit 0 で素通り |
| Node 18 未満 (fetch 不可) | `node --version` で先頭で確認 (任意) | exit 1 → 素通り |

## エンドツーエンド検証

### 単体動作

```bash
export GEMINI_API_KEY=...
echo "Plan: refactor auth into oauth/, session/, mfa/" | node skills/visual-in-the-loop/scripts/generate.mjs
# stdout に PNG パス、または stderr に WARN
bash skills/visual-in-the-loop/scripts/show.sh <PNG>
echo "Plan: ..." | bash skills/visual-in-the-loop/scripts/run.sh
```

### 環境別の表示パス

| ケース | 操作 | 期待 |
|---|---|---|
| ③ tmux + chafa | `tmux new -s test` 内で `run.sh` | 右ペインに chafa 描画 |
| ④ VS Code | VS Code 統合ターミナルから `run.sh` | 新規 markdown タブで画像表示 |
| ① macOS | Terminal.app から `run.sh` | Preview.app で PNG が開く |
| ① Linux | desktop で `run.sh` | デフォルト image viewer |
| fallback | ssh 先で `run.sh` | WARN + exit 0 |

### Skill 経由

1. `ln -s "$(pwd)/skills/visual-in-the-loop" ~/.claude/skills/visual-in-the-loop` (ローカル開発時)
2. Claude Code を起動して「plan mode で <架空タスク> を進めて」
3. `ExitPlanMode` 直前で skill が起動し画像が出ることを確認
4. `AskUserQuestion` を伴うタスクで、agent が SKILL.md 指示通り skill を呼ぶか観察
5. 呼ばないケースが頻発したら description をさらに pushy にチューン

### 配布検証

```bash
npx skills add taniiicom/visual-in-the-loop --skill visual-in-the-loop
```

を別マシン or 別ディレクトリで実行して `~/.claude/skills/visual-in-the-loop/` 配下に展開されること、`generate.mjs` が `node` で動くことを確認。

## 依存

- **Node.js 18+** (標準 `fetch` を使う)
- 任意: `chafa`, `tmux` (③ を使うなら), `code` CLI (④ を使うなら)
- env: `GEMINI_API_KEY` または `GOOGLE_API_KEY`
- **`npm install` 不要、`package.json` 不要** (依存ゼロ)

## 実装順序

1. `skills/visual-in-the-loop/scripts/generate.mjs` — API key で手動試打、PNG 生成を確認
2. `skills/visual-in-the-loop/scripts/show.sh` — 各表示パス (① ③ ④) を 1 つずつ手で叩いて検証
3. `skills/visual-in-the-loop/scripts/run.sh` — 1+2 を繋ぐ、失敗ケースで exit 0 を確認
4. `skills/visual-in-the-loop/references/prompt-template.md`
5. `skills/visual-in-the-loop/SKILL.md` — description を pushy に
6. ローカルで symlink して Claude Code 経由で確認
7. (将来) hook 経路を `references/hook-example.md` として追加

## 原則チェックリスト (最終確認)

| 原則 | 反映 |
|---|---|
| 本質を見失わない / Mermaid 無し | generate.mjs は nano banana 全任せ。show.sh も image を素通し |
| シンプル第一 / プロンプト作り込まない | prompt-template.md は 3 行。チューニングはここだけ |
| 同期実行 | run.sh が blocking で generate → show、exit するまで agent は次へ進めない |
| コスト最適化は後 | 閾値・キャッシュ無し |
| 表示は ①③④ | show.sh の検出順そのまま。②⑤ 不採用 |
| 人間に届く別経路 | agent には PNG パス 1 行返すだけ。画像本体は agent を経由しない |
| デファクト準拠 | `skills/<name>/SKILL.md` でモノレポ式、`npx skills add` 互換 |
| 依存最小 | Node 18+ の `fetch` のみ。npm install 不要、package.json 不要 |
