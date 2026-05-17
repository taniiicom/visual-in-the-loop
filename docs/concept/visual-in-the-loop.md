# Visual in the Loop

## idea

- claude code や codex などのコーディングエージェントにおける plan agent/plan mode や、spec-kit で、plan を作ってもらうのは良いんですが、そのplanを人がレビューするのが大変
- なので、plan の是非をユーザに尋ねたり、clarifyや質問エージェントなど、ユーザに決定を求めるタイミングで、別途 "nano banana 2"などを呼び出して1枚図を作成する agent skills を作りたい

## clarify

```md
1. Mermaid フォールバックは無し。nano banana pro の性能を信じる。本質は「Mermaid等の構造図レイヤを超えた可視化」
1. プロンプト設計は深掘りしない。まずシンプルに、結果を見てチューニング
1. 生成は同期。画像が出来てから質問を表示する。中途半端な状態でユーザの注意を引かない
1. コスト最適化は後
1. 表示は環境検出で切り替え。② エスケープシーケンス系は Claude Code TUI下では実質効かないので、現実解は ① / ③ / ④
```

> アーキ図系は Mermaid/D2 にフォールバックアーキ図系は Mermaid/D2 にフォールバック、概念図・UIモックアップ系のみ Gemini

- NO.
- nano banana の性能を見ていると余計なワークフローやハーネスをつけない方が良い
- 本質を見失ってはいけない
- 必要な可視化は、Mermaid図で表現にできる範囲でもなければ、そのようなレイヤの可視化だけを求めているわけでもない

> plan が長いと1枚に収まらない
> 「主要な分岐点だけ」「変更されるコンポーネント関係だけ」のように切り口を決める prompt 設計

- 一旦あんまり気にしすぎず、**まずはシンプルなプロンプトから始める**のが良いと思います
- その結果，精度を見ながら，必要に応じてプロンプトチューニング

> レイテンシ (5-15 秒)で質問が出るのが遅れる
> バックグラウンド生成 + 出来次第 open、質問自体は即時表示

- NO.
- 質問を表示して，"ユーザの操作待ち" 状態になると，ユーザに通知が飛んでしまって，ユーザの意識をこちらに呼び戻すことになる
- ビジュアルが出ていないのに，ユーザを無駄に呼び寄せて，待たせるのは良くない
- ビジュアルの生成が完成して，**ユーザの意思決定に必要な要素がすべて揃ってから**，質問自体を表示し，ユーザの注目を呼ぶのが良い

> API コストが質問のたびに発生
> plan 規模の閾値で発火条件を絞る、キャッシュ

- これも後で，気にすれば良いこと
- まずはシンプルに

> 画像を Claude Code 内にinline 表示できない
> OS の image viewer を open で起動、または HTTPサーバで表示

- これは実行環境や条件に応じて，いくつか手札を用意しておくのが良いと思います

````md
## ハック5パターン

**① 外部ビューワを開く（一番素直)**

```bash
# macOS
open diagram.png
# Linux
xdg-open diagram.png
```

skill の最後に `Bash` で `open` を呼ぶだけ。プラン提示と同時に別ウィンドウで図がポップアップする。一番動作が確実で OS 依存も少ない。**最初に試すべき方法**。

**② ターミナルに直接描画（環境が揃えば最高)**

iTerm2 / WezTerm / Kitty / Ghostty などのモダンターミナルなら、エスケープシーケンスで画像を描ける。

- iTerm2/WezTerm: `imgcat diagram.png`
- Kitty/Ghostty: `kitty +kitten icat diagram.png`
- フォールバック付き万能: `timg` は Kitty/iTerm2/Sixel を自動検出し、対応がなければ Unicode の半角ブロックで描画する

ただし **Claude Code / Codex の TUI が画面を制御している間はエスケープシーケンスが食われて描画されない**ことが多い。実用上は使えないケースが多い。

**③ tmux ペインに描画（一番"埋め込み感"が出る)**

エージェントは左ペイン、図は右ペインに表示する構成。chafa と tmux を組み合わせて、サイドペインに画像を出すスキルの実例もすでに存在する。

skill 内で:

```bash
tmux split-window -h "chafa diagram.png; read"
```

これがおそらく**現状の現実解として一番強い**。エージェントのスクロールバックを汚さず、図は常に視界の隅にある。

**④ Markdown ファイルに埋め込んで VS Code に開かせる**

```bash
echo "![plan](diagram.png)" > /tmp/plan.md
code /tmp/plan.md
```

VS Code でエージェントを使っているなら、Markdown プレビューを開かせれば1枚図がきれいに見える。Cursor / Windsurf / VS Code の Claude Code 拡張なら自然。

**⑤ ローカルHTTPサーバ + ブラウザ**

`python -m http.server` を立てて `open http://localhost:PORT/diagram.png`。クリック可能な hover やズームが欲しいなら HTML にして開く。やや大袈裟。

## skill 設計の現実的な落とし所

```
1. Nano Banana Pro で diagram.png 生成
2. ターミナル種別を判定（$TERM_PROGRAM, $TERM）
   - tmux 配下 → ③ ペイン分割
   - iTerm2/WezTerm/Kitty 単独 → ② timg
   - VS Code 統合ターミナル → ④ markdown を code で開く
   - それ以外 → ① open / xdg-open
3. プラン本文と一緒に "図を別ペインに表示しました" と返す
```

**最も大事なポイント**: エージェント本体に画像を「見せる」のではなく、**人間の目に届く別経路を確保する**設計です。エージェントは生成依頼と表示コマンド発行だけ担当する。
````
