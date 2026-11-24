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
/// 2020 年と 2024 年のリポジトリを読み込み終えたときの表示の設定。
fn config_of(still~ : Bool = false) -> StageConfig {
  let model = { ..start(still~), query: "a", phase: Loading("a"), }
  let repos = [repo("x", "Rust", 2020), repo("y", "Elm", 2024)]
  let (shown, effect) = model.update(Fetched(Ok((sample_profile, repos))))
  guard shown.phase is Showing(_) else { abort("表示中ではない") }
  guard effect is MountStage(_, config) else {
    abort("描画が始まらない")
  }
  config
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
test "取得に成功すると最も古い年から今の年までを表示する" {
  let config = config_of()
  assert_eq(config.first_year, 2020)
  assert_eq(config.last_year, 2026)
  assert_false(config.still)
}

///|
test "視差効果を減らす設定では静止画にする" {
  assert_true(config_of(still=true).still)
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
