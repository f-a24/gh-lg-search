///|
fn repo(name : String, language : String, year : Int32) -> @domain.Repo {
  { name, url: "https://github.com/a/\{name}", language, created_year: year, }
}

///|
let sample_profile : @domain.Profile = {
  login: "a",
  name: None,
  avatar_url: "https://example.com/a.png",
  bio: None,
  public_repos: 2,
}

///|
fn start(still~ : Bool = false) -> Model {
  Model::initial("", still~, this_year=2026).0
}

///|
fn loading() -> Model {
  { ..start(), query: "a", phase: Loading("a"), }
}

///|
/// 2020 年と 2024 年のリポジトリを読み込み終えた状態。
fn showing(still~ : Bool = false) -> Model {
  let model = { ..start(still~), query: "a", phase: Loading("a"), }
  let repos = [repo("x", "Rust", 2020), repo("y", "Elm", 2024)]
  model.update(Fetched(Ok((sample_profile, repos)))).0
}

///|
fn controls_of(model : Model) -> Controls {
  guard model.phase is Showing(shown) else { abort("表示中ではない") }
  shown.controls
}

///|
test "URL にユーザーがなければ待機し、あれば検索を始める" {
  let (idle, effect) = Model::initial("", still=false, this_year=2026)
  assert_true(idle.phase is Idle)
  assert_true(effect is NoEffect)
  let (model, effect) = Model::initial("f-a24", still=false, this_year=2026)
  assert_eq(model.query, "f-a24")
  assert_true(model.phase is Loading("f-a24"))
  assert_true(effect is StartSearch("f-a24"))
}

///|
test "検索は前後の空白を除き、空なら何もしない" {
  let (model, effect) = start().update(QueryChanged("  f-a24 ")).0.update(
    Submit,
  )
  assert_true(model.phase is Loading("f-a24"))
  assert_true(effect is StartSearch("f-a24"))
  let (model, effect) = start().update(QueryChanged("   ")).0.update(Submit)
  assert_true(model.phase is Idle)
  assert_true(effect is NoEffect)
}

///|
test "取得中はもう一度検索できない" {
  let (model, effect) = loading().update(Submit)
  assert_true(model.phase is Loading("a"))
  assert_true(effect is NoEffect)
}

///|
test "取得に成功すると最も古い年から今の年まで再生する" {
  let (model, effect) = loading().update(
    Fetched(Ok((sample_profile, [repo("x", "Rust", 2020)]))),
  )
  assert_true(effect is MountStage(_, _))
  let controls = controls_of(model)
  assert_eq(controls.first_year, 2020)
  assert_eq(controls.last_year, 2026)
  assert_eq(controls.year, 2020)
  assert_true(controls.playing)
}

///|
test "視差効果を減らす設定では最後の年で止めて表示する" {
  let controls = controls_of(showing(still=true))
  assert_eq(controls.year, 2026)
  assert_false(controls.playing)
  assert_true(controls.still)
}

///|
test "対象のリポジトリが空なら失敗にする" {
  let (model, effect) = loading().update(Fetched(Ok((sample_profile, []))))
  assert_true(model.phase is Failed(NoRepos))
  assert_true(effect is NoEffect)
}

///|
test "取得に失敗すると検索したユーザーの失敗になり、もう一度検索できる" {
  let (model, _) = loading().update(Fetched(Err(NotFound)))
  assert_true(model.phase == Failed(FetchFailed(user="a", NotFound)))
  assert_true(model.update(Submit).1 is StartSearch("a"))
}

///|
test "再生の操作" {
  let model = showing()
  let (paused, effect) = model.update(TogglePlay)
  assert_false(controls_of(paused).playing)
  assert_true(effect is ToggleStage)
  let (moved, effect) = model.update(Seek("2022"))
  assert_eq(controls_of(moved).year, 2022)
  assert_false(controls_of(moved).playing)
  assert_true(effect is SeekStage(2022))
  let (advanced, effect) = model.update(YearChanged(2021))
  assert_eq(controls_of(advanced).year, 2021)
  assert_true(controls_of(advanced).playing)
  assert_true(effect is NoEffect)
  let (same, effect) = model.update(Seek("abc"))
  assert_true(same == model)
  assert_true(effect is NoEffect)
}

///|
test "表示中でないときの再生のメッセージは無視する" {
  let model = loading()
  assert_true(model.update(YearChanged(2021)).0 == model)
  assert_true(model.update(TogglePlay).1 is NoEffect)
  assert_true(model.update(Seek("2021")).1 is NoEffect)
}

///|
test "エラーの文言" {
  let format_time = (epoch : Int32) => "時刻\{epoch}"
  let message = (error : @source.FetchError) => {
    FetchFailed(user="ghost", error).message(format_time)
  }
  inspect(
    message(NotFound),
    content="ユーザー ghost が見つかりません",
  )
  inspect(
    message(RateLimited(reset_epoch=100)),
    content="GitHub API の利用上限に達しました。時刻100 以降にもう一度お試しください",
  )
  inspect(
    message(Network("HTTP 500")),
    content="通信に失敗しました。接続を確認してもう一度お試しください",
  )
  inspect(
    message(Decode("x")),
    content="GitHub の応答を解釈できませんでした。時間をおいてもう一度お試しください",
  )
  inspect(
    NoRepos.message(format_time),
    content="言語が判定された公開リポジトリがありません",
  )
}

///|
test "凡例の文字列" {
  fn stat(count : Int32) -> @domain.LanguageStat {
    { name: "TypeScript", color: "#3178c6", count, }
  }

  inspect(legend_text(stat(27), 51), content="TypeScript 27（52.9%）")
  inspect(legend_text(stat(1), 51), content="TypeScript 1（2.0%）")
  inspect(legend_text(stat(51), 51), content="TypeScript 51（100.0%）")
}
