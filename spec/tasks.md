# 実装タスク

1回の作業で1タスクずつ進める。各タスクの完了条件と、`CLAUDE.md` の「完了の定義」をすべて満たしたらチェックを付ける。
作業は main ブランチで直接行い、タスクごとにコミット・push してよい。
公開中のサイトは T5-1 まで main の `docs/`（旧版のビルド結果）から配信され続けるので、**`docs/` は T5-1 まで消さない**。
デプロイ用ワークフローは T5-1 で `.github/workflows/pages.yml` に配置した（下書き `spec/pages.workflow.yml` は移動後に削除）。

---

## M0. 環境とプロジェクトの土台

- [x] **T0-1 ツールチェーンの確認**
  - `moon version --all` を実行し、結果を `spec/moonbit-notes.md` の「確認したバージョン」に追記する
  - `moonbitlang/skills` がインストールされているか確認する（なければ人間に依頼する。手順は `spec/moonbit-notes.md`）
  - 完了条件: バージョンが記録されている

- [x] **T0-2 旧アプリの撤去**
  - 旧 Next.js のソースと設定（`pages/`、`package.json`、`yarn.lock`、`next.config.js`、`tsconfig.json`、`next-env.d.ts` など）を削除する
  - **`docs/` は消さない。** 公開中のサイトの配信元なので、T5-1 で新しい版のデプロイに切り替えるときに消す
  - 完了条件: `docs/` 以外に旧アプリのファイルが残っていない

- [x] **T0-3 MoonBit プロジェクトの作成**
  - `warren new` の生成物を参考に、`spec/architecture.md` のパッケージ構成で `moon.mod` と各 `moon.pkg` を作る
  - Rabbita を依存に追加する（`moon add moonbit-community/rabbita`）
  - `src/main` に「Hello」を表示するだけの Rabbita アプリを置く
  - 完了条件: `moon check` が通る / `warren dev --browser-entry src/main` でブラウザに表示される

## M1. ドメイン（純粋関数）

- [x] **T1-1 データモデルと集計**
  - `Repo` / `LanguageStat` / `Profile` と `aggregate` を実装する
  - 完了条件: `fixtures/f-a24-repos.json` から作った入力で、次の結果になるテストが通る
    - 対象 51 件、12 言語（fork の `three.js` と言語なしの `slides-sandbox` は除外）
    - 順序と件数: TypeScript 27, JavaScript 7, Jupyter Notebook 6, Haskell 2, Rust 2,
      CSS 1, Elm 1, GLSL 1, Kotlin 1, Python 1, Svelte 1, Swift 1
    - 作成年の範囲: 2017〜2026

- [x] **T1-2 言語色の表**
  - `tools/gen_linguist.mbtx` で GitHub Linguist の `languages.yml` から `src/linguist/` に色の表を生成する
    （`.mbtx` で書けない場合は理由を記録したうえで、生成済みファイルを手で更新する方式でもよい）
  - 完了条件: TypeScript=`#3178c6`、JavaScript=`#f1e05a`、Jupyter Notebook=`#DA5B0B` が引ける / 未知の言語は `#cccccc`

## M2. 配置と軌道（純粋関数）

- [x] **T2-1 恒星の配置 `layout`**
  - `reference/prototype-planets.js` の `layoutSystems` を移植する
  - 完了条件: `spec/architecture.md` の layout の「テストで確かめる性質」がすべてテストで通る

- [x] **T2-2 惑星と軌道 `orbit`**
  - `planets` / `position` / `visible_until` / `year_at` / `hit_test` を実装する
  - 完了条件:
    - 同じ言語の惑星は作成年が古いほど内側の軌道
    - `position` が t に対して周期的で、楕円の範囲内に収まる
    - `hit_test` が惑星・恒星・何もない場所を正しく判定する
    - f-a24 のデータで、2019年時点の表示件数が 25 件になる（2017〜2019年の合計）

## M3. 描画

- [x] **T3-1 Canvas の FFI**
  - `src/ffi` に Canvas 2D、rAF、devicePixelRatio、reduced-motion 判定を用意する
  - 完了条件: `moon check` が通る（FFI はテストしにくいので、型と呼び出し側のコンパイルで担保）

- [x] **T3-2 静止画の描画**
  - fixtures のデータを埋め込み、ある時刻の惑星系を1フレーム描く
  - 完了条件: `reference/prototype.html` の案 B（f-a24 の実データ）と見比べて、恒星・軌道・惑星・言語名が同じように描かれている。スクリーンショットを人間に確認してもらう

- [x] **T3-3 アニメーションと再生**
  - rAF ループ、10秒での年の再生、惑星の出現アニメーション、再生／一時停止、年スライダー
  - reduced-motion 時は最終状態の静止画
  - 完了条件: 動作を人間に確認してもらう

## M4. アプリとして完成させる

- [x] **T4-1 GitHub API からの取得**
  - `src/ffi` に fetch を追加し、`src/source` に REST 版を実装する
  - 完了条件: JSON デコードのテスト（fixtures を使用）が通る / `FetchError` の4種類を返し分けられる

- [x] **T4-2 画面（Rabbita）**
  - 入力欄、検索、ローディング、エラー表示、プロフィール、DOM の凡例
  - `?user=xxx` での直接表示と URL の更新
  - 完了条件: `spec/spec.md` §3 のエラー表示がすべて確認できる / ローディング中に操作できない

- [x] **T4-3 インタラクション**
  - ホバーのツールチップ、惑星クリックで GitHub を開く、タッチ対応、リサイズ時の再配置
  - 完了条件: `spec/spec.md` §5「インタラクション」をすべて満たす

## M5. 公開

- [x] **T5-1 GitHub Pages へのデプロイ**
  - まずローカルで `warren build` を実行し、`dist/index.html` が `index.js` をどのパスで読み込んでいるか確認する
  - `spec/pages.workflow.yml` を `.github/workflows/pages.yml` に移動して完成させる
  - 人間に次の2つを依頼し、終わったと返事をもらってから push する:
    1. Settings → Pages → Source を「GitHub Actions」に変更する
    2. 切り替えから新しい版の公開まで、サイトが数分間表示されなくなることの了承
  - 同じコミットで旧版のビルド結果 `docs/` を削除する
  - サブパス `/gh-lg-search/` で `index.js` が読み込まれることを確認する
  - 完了条件: Actions が成功し、公開URLで f-a24 を検索できる

- [x] **T5-2 仕上げ**
  - README を書き直す（スクリーンショット、技術スタック、開発方法）
  - 幅 375px での表示確認、アクセシビリティ（ボタンのラベル、フォーカス表示、凡例のテキスト）
  - 完了条件: 人間のレビューで OK

---

## 将来のタスク（今回はやらない）

- GraphQL + PAT による精密モード（バイト数ベース。恒星の大きさに反映）
- IndexedDB へのキャッシュ
- 惑星系をクリックしてズーム
- 画像として保存
