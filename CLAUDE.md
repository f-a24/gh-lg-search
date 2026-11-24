# gh-lg-search（MoonBit リプレイス版）

GitHub ユーザー名を入力すると、そのユーザーの公開リポジトリの言語構成を
「言語の惑星系」として描くWebアプリ。旧版（Next.js + Recharts の円グラフ）を
MoonBit + Rabbita で作り直す。公開先は GitHub Pages（静的ホスティングのみ）。

## 最初に読むもの（この順番で）

1. `spec/spec.md` — 何を作るか（機能・見た目・スコープ）
2. `spec/architecture.md` — パッケージ構成、データモデル、純粋関数とFFIの境界
3. `spec/moonbit-notes.md` — MoonBit / Rabbita / Warren の調査メモ（2026-11時点）
4. `reference/prototype.html` — 見た目と動きの正解。B（惑星系）のJS実装は `reference/prototype-planets.js`

## MoonBit について必ず守ること

- **MoonBit の知識は古い可能性が高い前提で動くこと。** 言語仕様・標準ライブラリ・
  `moon.mod` / `moon.pkg` の書式・Rabbita の API は頻繁に変わっている。
  記憶でAPIを書かず、次の順で確認してから書く:
  1. `moonbit-agent-guide` スキル（`moonbitlang/skills`。インストール方法は `spec/moonbit-notes.md`）
  2. `moon ide doc <シンボル>` / `moon ide outline` / `moon ide peek-def`
  3. `.mooncakes/` 以下にある依存パッケージのソースと `pkg.generated.mbti`
- 新規ファイルは `moon.mod` / `moon.pkg` 形式で作る（`moon.mod.json` / `moon.pkg.json` は旧形式）。
- トップレベルの宣言は `///|` で区切る。
- JS FFI のシグネチャに `Array[T]` を使わない（非推奨）。`FixedArray[T]` を使う。
- FFI（`extern "js"`）を書いてよいのは `src/ffi/` パッケージだけ。他のパッケージはFFIを直接呼ばない。

## 変更のたびに実行するコマンド

```sh
moon check          # 型チェック（pkg.generated.mbti も更新される）
moon test           # 対象パッケージだけでよい: moon test -p <package>
moon fmt            # 引き渡し前に必ず
```

ブラウザでの確認は `warren dev --browser-entry src/main`（詳細は `spec/moonbit-notes.md`）。

## コーディング方針

- `domain` / `layout` / `orbit` は**副作用のない純粋関数だけ**で書き、必ずテストを付ける。
  描画やブラウザAPIに依存させない（将来 GraphQL・バイト数集計・時系列表示を足すときに差し替えやすくするため）。
- 惑星の位置は「時刻 t の純粋関数」で計算する。アニメーション状態を可変で積み上げない。
- テスト用の実データは `fixtures/f-a24-repos.json`。ネットワークに依存したテストは書かない。
- 迷ったら `reference/prototype-planets.js` の挙動に合わせる（数式・定数もそこにある）。

## 完了の定義（各タスク共通）

- `moon check` が警告なしで通る / `moon test` が通る / `moon fmt` 済み
- 公開APIが変わった場合は `pkg.generated.mbti` の差分を確認してコミットに含める

## やらないこと

- 旧 Next.js のコードを参考に移植しない（設計が違う）。仕様は `spec/` が正。
- サーバーを前提にした機能（APIルート、秘密のトークン埋め込み）は作らない。GitHub Pages で動かす。
- 依頼されていないライブラリ追加や大規模なリファクタリングはしない。必要なら先に提案する。
