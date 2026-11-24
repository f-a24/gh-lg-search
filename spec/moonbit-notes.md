# MoonBit / Rabbita / Warren 調査メモ

調査日: 2026-11-05。**ここの内容も古くなる前提で使うこと。** 実際のAPIは `moon ide doc` とスキルで確認する。

## 確認したバージョン

| 項目 | バージョン | 確認方法 |
|---|---|---|
| moonbit-agent-guide の検証環境 | moon/moonc 2026-10-16（moonc v0.10.16） | スキル本文の記載 |
| ローカル環境: moon | 0.1.20261104（940aa18 2026-11-04） | `moon version --all`（2026-11-06） |
| ローカル環境: moonc | v0.10.20+65efd5b93（2026-11-05） | 同上 |
| ローカル環境: moonrun | 0.1.20261104（940aa18 2026-11-04） | 同上 |
| ローカル環境: 機能フラグ | `rr_moon_mod`, `rr_moon_pkg` | 同上 |
| ローカル環境: warren | 0.4.5 | `warren` にバージョン表示がないため、`~/.moon/registry/cache/moonbit-community/warren/` のキャッシュで確認 |
| moonbitlang/skills | 9 スキル導入済み（`moonbit-agent-guide` を含む） | `~/.claude/skills/` を確認（2026-11-06） |

ローカルの moonc（v0.10.20）は、`moonbit-agent-guide` の検証環境（v0.10.16）より新しい。スキルの記述と実際の挙動が違うときは、`moon ide doc` とコンパイラの診断を優先する。

## AIエージェント向けの公式スキル（最重要）

MoonBit 公式（`moonbitlang` org）が Claude Code 用のスキル集を公開している。
MoonBit は学習データが少なく、書式の変更も多いので、**作業前に必ず入れておく**。

```sh
# すべてのスキルを Claude Code にインストール
npx skills@latest add moonbitlang/skills -g --agent claude-code --skill "*" --copy -y

# 一覧を見るだけ
npx skills@latest add moonbitlang/skills --list
```

- リポジトリ: https://github.com/moonbitlang/skills
- 中心になるのは `moonbit-agent-guide`。要点:
  - 作業前に `moon version --all` と依存バージョンを確認する
  - `moon.mod` / `moon.pkg` が現行形式。`moon.mod.json` は旧形式なので新規に作らない
  - 各ディレクトリが1パッケージ。ファイル名は名前空間にならない。トップレベルの宣言は `///|` で区切る
  - APIの調査は `moon ide doc`、`moon ide outline` / `peek-def` / `find-references` / `hover` / `rename`
  - 検証は `moon check` と、対象を絞った `moon test`。スナップショット更新（`moon test --update`）は意図したときだけ
  - 引き渡し前に `moon fmt`。`pkg.generated.mbti` は手で編集せず、`moon check` で再生成して差分を確認
  - 自動化スクリプトは `.mbtx`（MoonBit スクリプト）で書く。シェルスクリプトにしない
  - テストは `*_test.mbt`（ブラックボックス）と `*_wbtest.mbt`（ホワイトボックス）。`*.mbt.md` 内の `mbt check` ブロックもテストになる
  - よくある間違い: 変数・関数名を大文字で始める、`++` を使う、不要な `return`、メソッドに `Type::` を付け忘れる、可変フィールドの `mut` 忘れ

## JS FFI（公式ドキュメント）

出典: https://docs.moonbitlang.com/en/stable/language/ffi.html

```moonbit
// モジュール名 + 関数名で参照（Math.cos）
fn cos(d : Double) -> Double = "Math" "cos"

// インラインの JS で定義
extern "js" fn cos(d : Double) -> Double =
  #|(d) => Math.cos(d)

// JS の値を表す外部型（ABI は any）
#external
type ExternalRef
```

- 戻り値がないときは `-> Unit`
- 多相な外部関数は書けない
- クロージャはそのまま JS に渡せる。自由変数を持たないものは `FuncRef[T]`（JS の `Function`）
- 型の対応: `String`→string、`Bytes`/`FixedArray[Byte]`→Uint8Array、`FixedArray[T]`→`T[]`、`Int`/`UInt`/`Float`/`Double`→number
- **`Array[T]` を FFI のシグネチャに使うのは非推奨。`FixedArray[T]` を使う**（数値の FixedArray は将来 TypedArray に変わる可能性あり）
- JS へのエクスポート: `moon.pkg` に `pkgtype(kind: "foreign_library")` と `#export_name("...")`、またはリンク設定の `exports`。出力形式（esm / cjs / iife）の指定方法はリンク設定のリファレンスで確認する
- 非同期（Promise）の扱いはこのドキュメントには書かれていない。このプロジェクトの fetch の書き方は下の「T4-1 で確認したこと」を参照

参考（コミュニティ記事。古い可能性あり）:
- https://zenn.dev/mizchi/articles/moonbit-js-ffi
- https://dev.to/mizchi/writing-js-ffi-in-moonbit-jgn

## Rabbita

- リポジトリ: https://github.com/moonbit-community/rabbita （README は `rabbita/README.mbt.md`）
- Elm と Bonsai に影響を受けた宣言的・関数型の UI フレームワーク。旧名 `Rabbit-TEA`
- 型付きメッセージで状態を変え、副作用はコマンドで明示する。仮想 DOM の差分更新。約 15KB（min+gzip）
- **API は旧来の Model/Update/View 形式から変わっている。** 2026-11 時点の README の例:

```moonbit
using @rabbita {type Html, type Val}
using @html {button, div, h1}

///|
enum Msg {
  Inc
  Dec
}

///|
fn counter() -> Val[Html] {
  let (count, emit) = @rabbita.create_pure_state(0, update=fn(count, msg) {
    match msg {
      Inc => count + 1
      Dec => count - 1
    }
  })
  count.view(count => {
    div([
      h1(count.to_string()),
      button(on_click=emit(Inc), "+"),
      button(on_click=emit(Dec), "-"),
    ])
  })
}

///|
fn main {
  @rabbita.new(counter).mount("app")
}
```

- 確認が必要な点（T0-3 / T4-2 で `moon ide doc` とソースを読んで決める）:
  - HTTP リクエスト用のコマンドがあるか（なければ FFI で fetch）
  - 要素のマウント後に DOM 要素（canvas）を取得するフックがあるか
  - URL・history を扱う仕組みがあるか
- 旧テンプレート `rabbita-template` は非推奨。代わりに Warren の `warren new` を使う

## Warren（ビルドツール）

出典: https://github.com/moonbit-community/rabbita/blob/main/warren/README.md

```sh
moon install moonbit-community/warren   # インストール
warren new my-project                   # 新規作成
warren dev --browser-entry main         # 開発サーバー（ライブリロード）
warren build --browser-entry src/main   # 本番ビルド → dist/（引数なしだと cmd/browser を探して失敗する）
```

- ブラウザのエントリは既定で `cmd/browser`。`--browser-entry` で変更できる（このプロジェクトでは `src/main` を想定）
- サーバーのエントリ（`cmd/server`）は任意。このプロジェクトは静的公開なので使わない。既存の `cmd/server` を無視するには `--server-entry ""`
- `public/` があれば自動でコピーされる。出力は `dist/` に `index.js` と `index.html`
- `-C <dir>` でプロジェクトのルートを指定できる

### T0-3 で確認したこと（2026-11-06）

- `moon add` で入った Rabbita は 0.17.0。`warren new` のテンプレートは 0.15.2 を指すが、同じ書き方（`create_pure_state` / `@rabbita.new(app).mount("app")`）で動いた
- `--browser-entry src/main` は `moon.mod` の `source` 指定なしで動く。パッケージのパスは `f-a24/gh-lg-search/src/<名前>` になる
- `moon.pkg` の未使用 import は警告（`unused_package`）になる。そのため各パッケージの import は、実際に使うタスクで足す（依存の向きは `spec/architecture.md` が正）
- `warren dev` の初回は、ビルドが終わる前にページを開くと `index.js` が 404 になり画面が空になる。少し待って再読み込みすれば表示される
- `warren dev` は `public/index.html` に `<base href="/">` を足し、`styles.css` の `<link>` がなければ自動で差し込む。`warren build` は差し込まない。そのため `public/index.html` に `./styles.css` のリンクを明記している
- `public/index.html` は `./index.js` を相対パスで読み込み、`warren build` の `dist/index.html` にもそのまま残る（サブパスでの実際の確認は T5-1）

### T1-1 で確認したこと（2026-11-06）

- `String::compare` は**長さを先に比べる**（`"Rust" < "Haskell"`）。名前の昇順には使えないので、`domain` の `compare_names` で辞書順に比べている
- `} derive(...)` は非推奨（`deprecated_syntax`）。型宣言の前に `#derive(...)` と書く。スキルの記述より新しい挙動
- `pub` な型の `#derive` は `implicit_impl_as_method` 警告が出る。`pub extend T with Eq::{equal, not_equal}` と `pub extend T with @debug.Debug::{to_repr}` を明記する（`moonbitlang/core/debug` の import が必要）
- fixture は `moon.pkg` の `rule` + `dev_build`（`:embed`）でテスト用ファイルに埋め込む。パスは `moon.pkg` からの相対で動いた。出力名を `*_test.mbt` にすると本番ビルドに入らない。生成物は `.gitignore` 済みで、`moon check` / `moon test` のたびに再生成される

### T1-2 で確認したこと（2026-11-07）

- `.mbtx` の `import` はファイル先頭の `---` で囲むフロントマターに書く。囲まないと `unfenced_import` 警告になる。スキルの記述より新しい挙動
- `.mbtx` のファイル入出力は `moonbitlang/x/fs` で動く。`moon.mod` に依存を足さなくても、スクリプトの `import` だけで解決される
- `moon test tools/gen_linguist.mbtx` で `.mbtx` 内の `test` を実行できる（`main` は実行されない）。パッケージ全体の `moon test` には含まれないので、スクリプトを変えたときは明示して実行する
- `.mbtx` の実行で `tools/_build/` ができる。`.gitignore` の `_build` で除外済み
- ドキュメントテストの中でも、自パッケージの関数は `@linguist.color_of` のように修飾する。修飾しないと `test_unqualified_package` 警告になる
- 色の表は Linguist `v9.7.0` から生成した（833 言語のうち色があるのは 692 言語）。更新手順は `tools/gen_linguist.mbtx` の先頭に書いてある

### T2-1 で確認したこと（2026-11-07）

- `Array::sort_by` は不安定ソート。同じ値の順序に結果が左右される処理では、添字などで順序を固定する
- `layout` は言語名の幅を `measureText` で測らず、等幅フォントの字幅（10.5px × 0.6em）から見積もる。純粋関数のままにするため
- プロトタイプの貪欲法は重なりを許容していた（距離の判定が `0.85` 倍）。本実装は、外縁が重ならない格子点を必ず優先する
- 惑星系の面積の合計が、予約領域を除いたキャンバスの約 65% までは重ならずに置ける（25 言語・約 300 リポジトリ、20 シードで確認）。約 75% を超えると重なりが出て、100% を超えるとどんな配置でも避けられない。軌道の間隔に下限 `1.3s` があるため、リポジトリが非常に多いユーザーでは惑星系が大きくなりすぎる。このとき `layout` は重なりが最小の点に置き、恒星と言語名だけはキャンバス内に収める

### T2-2 で確認したこと（2026-11-07）

- `planets` は `spec/architecture.md` の当初の案と違い `canvas` も受け取る。軌道の半径（`7s`）と角速度に倍率 `s` が要るため。`position` は `Planet` が角速度を持つので `s` が要らない
- 軌道の半径の式は `layout` の `System::orbit_radius` に置き、`orbit` から呼ぶ。`domain` の `compare_names` も `orbit` の並べ替えで使うので `pub` にした
- `Repo` は作成年しか持たないので、同じ年の中の軌道の順は名前順になる（プロトタイプと同じ）。`spec/spec.md` §5 の「`created_at` の昇順」より粗い
- 型名 `Planet` と列挙子 `Hit::Planet` は同じ名前でも共存できる。テストからは `@orbit.Hit::Planet(0)` と書く
- ブラックボックステストでは、他パッケージのレコードのリテラルは型が分からないと解決できない。`let raw : Array[@domain.RawRepo] = ...` のように注釈を付ける
- `a - b is (0 | 1)` は `is` の優先順位が高い。`(a - b) is (0 | 1)` と括弧を付ける

### T3-1 で確認したこと（2026-11-07）

- Rabbita 0.17.0 の `dom` パッケージにも Canvas・`window` のバインディングがあるが、`textAlign` / `measureText` / `devicePixelRatio` がなく、`get_line_with` のように名前の誤りもある。そのため `src/ffi` に必要な分だけ `extern "js"` を書いた。`ffi` は Rabbita に依存しない
- Rabbita には `@sub.on_animation_frame` もある。rAF のループは T3-3 で `ffi` のものを使う想定（`spec/architecture.md` のとおり Rabbita の外で回す）
- 外部型を他パッケージから使うには `#external` の次に `pub type X` と書く
- JS の `null` は `Option` に自動では変換されない。`x == null` を返す非公開の `extern` で判定し、`pub fn` で `T?` に包む（`find_canvas` / `context_2d`）
- `extern "js"` はテストファイルにも書ける。`src/ffi/ffi_test.mbt` は偽のコンテキストと大域の API で呼び出しを記録している。`moon test` は Node で動くので `document` や `matchMedia` は差し替えが要る
- `Ref::new(x)` は非推奨。`Ref(x)` と書く
- `moon fmt` は `Int` を `Int32` に書き換える
- `warren dev` はアプリを iframe（`/__warren/preview/index.html`）の中に表示する。ブラウザのツールで DOM を調べるときは `document.querySelector('iframe').contentDocument` を使う
- 実際のブラウザでも一時的なコードで全 FFI を実行して確認した（dpr=1 の環境。dpr が 2 以上の表示は未確認）

### T3-2 で確認したこと（2026-11-07）

- マウント後に canvas を掴むには、`@rabbita.create_state_with_init` の `init` から `@cmd.custom_cmd(_ => ..., kind=@cmd.after_render)` を返す。`App::mount` は DOM を作るところまでで、`after_render` は次の rAF で実行される。そのため、その間に canvas を調べると初期サイズの 300×150 に見える（不具合ではない）
- `Canvas` という名前が `@html.canvas`（関数）・`@ffi.Canvas`（要素）・`@layout.Canvas`（大きさ）の3つある。`main` では `@layout.Canvas` の値を `size` と呼んで区別している
- `extern "js"` は `src/ffi` だけに置く決まりなので、`render` のテストに偽のコンテキストは作れない。`render` のテストは文字列を組み立てる非公開の関数だけを `*_wbtest.mbt` で確かめ、描画そのものはブラウザで確認する
- `src/main/fixture.mbt` と `moon.pkg` の `embed-fixture` は仮のデータ源。T4-2 で取り除く（`.gitignore` の `src/main/fixture_data.mbt` も）
- `Context2d::fit_canvas` は `canvas.style.width` を px で固定する。以後は CSS の `width: 100%` が効かず `client_width` が親の幅に追従しないので、T4-3 のリサイズ対応では親要素の幅を測るか、`fit_canvas` を直す
- `public/index.html` は IBM Plex Mono を読み込んでいないので、Canvas の文字は `ui-monospace` / `monospace` で表示される
- `reference/prototype.html` は Browser ペインで `file:///` として開くと静的なコピーになり、キャンバスが狭いまま作られる。案 B の「もう一度」を押すと今の幅で作り直される

### T3-3 で確認したこと（2026-11-07）

- 再生の状態は `orbit` の `Playback`（不変の値）。時間軸は `t` の1本だけで、年・惑星の位置・出現の大きさをすべて `t` から求める。`t` は再生が終わったあとも公転のために増え続ける
- `spec/spec.md` に書かれていない挙動は次のように決めた: 一時停止すると公転も止まる / スライダーで移動すると再生は止まる（年が進むとつまみと競合するため）/ 移動先の年までの惑星は最初から最大の大きさで描く（`settled_year`）/ 再生が終わっても自動で巻き戻さない（最初から見るにはスライダーを左端へ動かして ▶）
- `resume` は予約語の警告（`reserved_keyword`）が出るので、再開のメソッドは `Playback::play`
- rAF のループは `main` の `Stage` が `ffi` で回す。Rabbita の外から状態を変えるには、`custom_cmd` が渡す `&Scheduler` を保持して `scheduler.add((emit.0)(msg))` を呼ぶ。年が変わったときだけ知らせるので、仮想 DOM の更新は毎フレーム走らない
- `@html.input` の `value=` は属性を設定するだけなので、再生に合わせて値を動かすには `attrs=@html.Attrs::build().value_prop(...)` で property を設定する
- 2026-11-10: 年スライダー、再生／一時停止ボタン、左上の年表示は削除した（件数のみ表示）。この節の「スライダー」「一時停止」に関する記述は当時の実装のもの。年を追って惑星を増やす再生もやめ、`Playback::finished(...).play(clock)` で最初から全惑星を公転させている。`Playback::start` / `pause` / `seek` は `orbit` にテスト付きで残しているが、画面からは使っていない
- Browser ペインが非表示だと rAF は発火しない。`after_render` も動かないので canvas が 300px のままに見える。表示していても Claude のウィンドウが背面にあると rAF は毎秒1回に間引かれるので、時間に関わる確認では rAF の頻度を先に測る
- `prefers-reduced-motion` は、同じ URL の iframe を作り、モジュールの実行前に `contentWindow.matchMedia` を差し替えると確認できる（`srcdoc` の iframe ではアプリが起動しなかった）

### T4-1 で確認したこと（2026-11-10）

- `@rabbita/http` はステータスとヘッダーを返さず、レート制限を判定できない。fetch は `src/ffi` に書いた
- 非同期は、JS の Promise を `@js.Promise[T]`（`moonbit-community/rabbita/js`。`moonbitlang/async` の再公開）で受けて `.wait()` する。これで `ffi` は Rabbita に依存する。`%async.suspend` を直接使うと `moonbitlang/async` のスケジューラーを通らないので使わない
- 画面からは `@cmd.attempt(msg, async () -> A raise FetchError)` で呼べる想定（呼び出しは T4-2）
- `moonbitlang/async` は Rabbita 経由の間接依存なので、`moon.mod` に足さないと `import` できず、`async test` も書けない。そのため fetch を通す経路のテストはリポジトリに入れていない。プロジェクトのコピーに依存を足して、偽の `fetch` で `FetchError` の4種類と複数ページの結合を、実際の GitHub API で f-a24 の取得（53 件中 51 件が対象）を確認した。同じ `async test` が並列に動くので、`globalThis.fetch` の差し替えは競合する
- `FetchError` は `raise` するので `enum` ではなく `suberror`。`RateLimited` の引数はラベル付きで `reset_epoch~`
- `Profile` に `public_repos` を足した。`fetch_repos` の引数に渡すため
- 判定は `spec/spec.md` §3 のとおり「403 かつ `x-ratelimit-remaining: 0`」だけをレート制限とする。それ以外の HTTP エラーは `Network("HTTP 500")` のようにする。GitHub の文書では 429 でレート制限を返すこともあるとされており、現状これは `Network` になる
- `Array::push_all` はない。`Array::append` を使う。配列内包の末尾にカンマは書けない。複数行文字列を関数の引数に直接書くのは非推奨（`let` に置く）

### T4-2 で確認したこと（2026-11-10）

- `main` の状態遷移は `Model::update`（`src/main/model.mbt`）の純粋関数で、次の状態と `Effect` を返す。`Effect` をコマンドにするのは `run_effect` だけなので、`Model::update` は `*_wbtest.mbt` でテストできる
- `spec/spec.md` に書かれていない挙動は次のように決めた: `Decode` は専用の文言を出す / HTTP 500 などは「通信に失敗」と表示する / 取得が失敗しても URL の `?user=` は検索した名前のまま / 空白だけの検索は無視する
- 再生の終わりの年は「最新のリポジトリの作成年」と「今の年」の大きい方（`spec/spec.md` §5「現在の年まで」）
- Rabbita の描画も初回のコマンドも rAF で進むので、Browser ペインが非表示だと `fetch` すら始まらない。確認するときは同じ URL の iframe を作り、モジュールの実行前に `contentWindow.requestAnimationFrame` を `setTimeout` に差し替える。`fetch` も `contentWindow.fetch` を差し替えれば各エラーを再現できる
- `warren dev` で `?user=xxx` を確認するときは `/__warren/preview/index.html?user=xxx` を直接開いた（外枠のページに `?user=` を付けたときの動作は未確認）
- 配列内包は `[for x in xs => ...]` で、`{` だけでは書けない。ローカルの関数で戻り値の型を書きたいときは矢印関数ではなく `fn name(...) -> T { ... }`
- `Attrs::disabled(false)` は属性を付けないので、入力欄の無効化を切り替えられる

### T4-3 で確認したこと（2026-11-10）

- `@html.canvas` には `pointermove` などの属性がないので、`src/ffi/input.mbt` で `addEventListener` している。ホバーと選択は `Stage` の `Pointer` が持ち、Rabbita の状態は変えない
- `spec/spec.md` に書かれていない挙動は次のように決めた: タッチでは1回目のタップでツールチップを出し、選択中の惑星をもう一度タップするとリポジトリを開く / タップで選んだものは惑星が動いても追いかける / 何もない場所のタップで解除する / リサイズすると再生は続き、ホバーと選択は解除する / ツールチップの文字は `s` が 1 未満でも 1 倍で描き、幅に収まらなければ末尾を「…」にする
- `s` が小さいと惑星の判定半径は数 px しかないので、タッチは通常の半径で判定してから、外れたときだけ `min_reach`（22px）で判定し直す。最初から広げると、恒星をタップしても周りの惑星が選ばれる
- `fit_canvas` は `style.width` を設定しなくなった（T3-2 のメモの問題の解消）。表示サイズは CSS の `.stage canvas` が決める
- 再検索では Rabbita が同じ `<canvas>` 要素を再利用することがある。監視の解除とカーソルの復元は `Stage::release` で行う
- `Canvas` の `click` の `pointerType` はブラウザによってないので、直前の `pointerdown` で判断する
- Browser ペインでは、ペインを表示しても rAF と `ResizeObserver` が発火しないことがある（`visibilityState` は `visible` のまま、素の `div` でも 0 回）。実物の `ResizeObserver` は未確認で、`ResizeObserver` を `clientWidth` のポーリングに差し替えた iframe で再配置を確認した
- `.claude/launch.json` は 4300 番を指定している。すでに `warren dev` が動いていると preview_start は別のポートを割り当てるが、warren は `--port` がないと 4300 で起動しようとするので、割り当てられたポートでは接続できない

### GitHub Pages で使うときの注意

- サブパス（`https://f-a24.github.io/gh-lg-search/`）で配信される。生成された `index.html` が `/index.js` を**絶対パス**で読み込んでいると動かない
- `dist/index.html` を確認し、必要なら `./index.js` に書き換える処理をワークフローに入れるか、`public/index.html` を自前で用意する

## CI でのインストール（要確認）

公式のインストールスクリプト（調査時点。URL は公式サイトのダウンロードページで確認すること）:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
echo "$HOME/.moon/bin" >> "$GITHUB_PATH"
```

## Claude Code の権限設定の例

`.claude/settings.json` に入れておくと、確認なしで検証コマンドを回せる:

```json
{
  "permissions": {
    "allow": [
      "Bash(moon check:*)",
      "Bash(moon test:*)",
      "Bash(moon fmt:*)",
      "Bash(moon build:*)",
      "Bash(moon ide:*)",
      "Bash(moon version:*)",
      "Bash(warren build:*)"
    ]
  }
}
```

## そのほかの情報源

- 公式ドキュメント: https://docs.moonbitlang.com/
- MoonBit の宣言的 UI ライブラリ Luna（Rabbita の代替候補。今回は使わない）: https://azukiazusa.dev/blog/moonbit-declarative-ui-library-luna-ui.md
