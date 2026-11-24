# 設計

## 方針

1. **純粋な計算と、ブラウザに触れる処理をパッケージで分ける。** 計算側は `moon test` だけで検証できるようにする。
2. **データ取得は差し替え可能にする。** 今は未認証 REST、将来は PAT + GraphQL。集計と描画のコードは変えずに済むようにする。
3. **アニメーションは時刻 t の関数として描く。** 「前フレームの状態を更新する」方式にしない。スライダーで任意の年へ飛べるのも、ヒット判定も、同じ関数から得られる。

## パッケージ構成（案）

パッケージ名は `moon.mod` の `name` に依存する。下の `@gh/...` は仮の表記。

```
moon.mod
src/
├─ domain/      # 純粋。データモデルと集計
├─ linguist/    # 純粋。言語名 → 色の表（生成ファイル）
├─ layout/      # 純粋。言語の統計 → 恒星の座標と軌道パラメータ
├─ orbit/       # 純粋。時刻 t → 各惑星の位置、表示中の惑星、ヒット判定
├─ source/      # GitHub API からの取得とJSONデコード（REST。将来 GraphQL を追加）
├─ ffi/         # extern "js" をここに集約（fetch、Canvas 2D、rAF、history、window.open）
├─ render/      # orbit の結果を ffi の Canvas API で描く
└─ main/        # Rabbita のアプリ本体（入力、状態、エラー表示）。ブラウザのエントリ
tools/
└─ gen_linguist.mbtx   # languages.yml から linguist パッケージを生成するスクリプト
fixtures/
└─ f-a24-repos.json    # テスト用の実データ
```

依存の向き（矢印の先に依存する）:

```
main → render → orbit → layout → domain
main → source → domain        render → ffi
main → ffi                    source → ffi
domain → linguist
```

`domain` / `layout` / `orbit` / `linguist` は `ffi` に依存してはいけない。

## データモデル（domain）

```moonbit
// 概念を示す擬似コード。実際の構文は moon ide doc で確認すること
pub struct Repo {
  name : String
  url : String           // html_url
  language : String      // null は取得時点で除外済み
  created_year : Int
  // 将来: language_bytes : Map[String, Int]（GraphQL で取得したとき）
}

pub struct LanguageStat {
  name : String
  color : String         // "#rrggbb"
  count : Int            // 今はリポジトリ数。将来はバイト数にも切り替えられるよう weight にする案もあり
}

pub struct Profile {
  login : String
  name : String?
  avatar_url : String
  bio : String?
  public_repos : Int     // fetch_repos のページ数の計算に使う
}

pub fn aggregate(repos : Array[Repo]) -> Array[LanguageStat]
// 件数降順、同数は名前昇順
```

除外（fork、language なし）は `source` のデコード時に行うか、`domain` に `filter_countable` を置いてテストする。
**旧版と同じ集計結果になること**を `fixtures/f-a24-repos.json` で検証する（期待値は `spec/tasks.md` 参照）。

## layout

```moonbit
pub struct Canvas { width : Double; height : Double }

pub struct System {
  language : String
  color : String
  x : Double; y : Double       // 恒星の中心
  star_radius : Double
  orbit_step : Double
  tilt : Double                // ラジアン、±0.35
  extent : Double              // 最外軌道 + 8s
}

pub fn layout(stats : Array[LanguageStat], canvas : Canvas, seed : Int) -> Array[System]
```

テストで確かめる性質:
- 惑星系どうしの外縁が重ならない（楕円なので縦方向は 0.45 倍で近似してよい）
- すべての恒星とラベルがキャンバス内（予約領域を除く）
- 同じ入力・同じ seed なら同じ結果
- 言語 1 個、25 個、件数が極端（1件の言語が20個）のケースで成立

## orbit

```moonbit
pub struct Planet {
  repo : Repo
  system_index : Int
  orbit_radius : Double
  phase : Double               // 初期位相
  angular_speed : Double
}

pub fn planets(repos : Array[Repo], systems : Array[System], canvas : Canvas, seed : Int) -> Array[Planet]
// 言語ごとに created_year の昇順で内側の軌道から割り当てる
// 軌道の半径と角速度に倍率 s が要るので canvas を受け取る

pub fn position(p : Planet, systems : Array[System], t : Double) -> (Double, Double)
// t は秒。楕円上の位置を恒星の傾きで回転して返す

pub fn visible_until(year : Int, planets : Array[Planet]) -> Array[Int]
pub fn hit_test(x : Double, y : Double, t : Double, planets : Array[Planet], systems : Array[System], canvas : Canvas, visible_year : Int) -> Hit?
// Hit = Planet(index) | Star(index)

pub fn year_at(progress : Double, first_year : Int, last_year : Int) -> Int
```

## source（REST）

- `fetch_profile(user)` と `fetch_repos(user, public_repos)` を提供する。
- ページは並列取得してよい（件数が多いユーザーで待ち時間を減らす）。
- エラーは型で区別する:

```moonbit
pub(all) suberror FetchError {
  NotFound
  RateLimited(reset_epoch~ : Int)
  Network(String)
  Decode(String)
}
```

- JSON のデコードは `@json` などの標準手段を使い、テストは fixtures で行う（fetch 自体はテストしない）。
- 将来の GraphQL 版も同じ `Array[Repo]` を返す関数として追加する。

## ffi

ここだけが `extern "js"` を持つ。用意する関数（例）:

| 分類 | 関数 |
|---|---|
| fetch | GET してステータス・ヘッダー（`x-ratelimit-remaining` / `x-ratelimit-reset`）・本文テキストを返す。非同期の扱いは Rabbita の Cmd / MoonBit の async のどちらで書けるかを調べて決める |
| Canvas 2D | `get_context`、`set_size(dpr 対応)`、`fill_rect`、`arc`、`ellipse`、`radial_gradient`、`fill_text`、`measure_text`、`save/restore/translate/rotate` など、render が必要とする最小限 |
| ループ | `request_animation_frame(callback)`、`cancel`、`performance_now` |
| その他 | `prefers_reduced_motion()`、`device_pixel_ratio()`、`location_search()`、`replace_state(url)`、`open_new_tab(url)`、リサイズ監視 |

Canvas のコンテキストは `#external type` で表す。呼び出し回数が多い描画は、
「惑星の座標配列をまとめて JS に渡して描く」形にしてもよい（FFI 呼び出しのオーバーヘッドが問題になった場合）。

## main（Rabbita）

状態（Model）の例:

```
Idle | Loading(user) | Loaded(profile, stats, systems, planets) | Failed(FetchError)
+ 再生状態: Playing(start_time) | Paused(year)
```

- キャンバスの描画は Rabbita の仮想 DOM の外で行う。マウント後に `canvas` 要素を取得して rAF ループを回す。
- プロフィール・エラーは Rabbita の View で描く。

## ビルドと公開

- 開発: `warren dev --browser-entry src/main`
- 本番: `warren build --browser-entry src/main`（出力は `dist/`）
- GitHub Actions で `dist/` を GitHub Pages にデプロイする（`.github/workflows/pages.yml`）。
- `dist/` は `.gitignore` に入れる（ビルド結果をコミットしない）。
- **注意:** Warren の生成する `index.html` は `/index.js` を絶対パスで読み込む可能性がある。
  サブパス `/gh-lg-search/` で動かすため、相対パス `./index.js` になっていることを確認し、
  なっていなければワークフローで書き換えるか、自前の `public/index.html` を用意する。
