///|
/// 惑星系の表示の設定。キャンバスの描画は `Stage` が受け持つ。
#derive(Eq)
struct StageConfig {
  first_year : Int32
  last_year : Int32
  /// `prefers-reduced-motion` のとき `true`。公転させず静止画で表示する
  still : Bool
}

///|
/// 検索が結果を表示できずに終わった理由。
#derive(Eq)
enum Failure {
  FetchFailed(user~ : String, @source.FetchError)
  NoRepos
}

///|
/// 惑星系を表示している間の DOM 側の内容。
#derive(Eq)
struct Shown {
  profile : @domain.Profile
  /// キャンバスの代替テキストに使う言語ごとの件数（件数の降順）
  stats : Array[@domain.LanguageStat]
}

///|
/// キャンバスの代替テキスト。画面読み上げでも言語構成がわかるようにする。
/// 例: `a の言語構成（3 repos）: Rust 2 repos（66.7%）、Elm 1 repos（33.3%）`
fn language_summary(
  login : String,
  stats : Array[@domain.LanguageStat],
) -> String {
  let total = stats.fold(init=0, (sum, stat) => sum + stat.count)
  let items = stats.map(stat => {
    let percent = @domain.percent_text(stat.count, total)
    "\{stat.name} \{stat.count} repos（\{percent}%）"
  })
  "\{login} の言語構成（\{total} repos）: \{items.join("、")}"
}

///|
#derive(Eq)
enum Phase {
  Idle
  /// 取得中のユーザー名
  Loading(String)
  Failed(Failure)
  Showing(Shown)
}

///|
/// 画面全体の状態。
#derive(Eq)
struct Model {
  /// 入力欄の文字列
  query : String
  phase : Phase
  /// `prefers-reduced-motion` のとき `true`
  still : Bool
  /// 今の年。表示する最後の年に使う
  this_year : Int32
}

///|
enum Msg {
  QueryChanged(String)
  Submit
  Fetched(Result[(@domain.Profile, Array[@domain.Repo]), @source.FetchError])
}

///|
/// 状態の更新に伴って行う副作用。実行は `run_effect` が受け持つ。
enum Effect {
  NoEffect
  /// 前の惑星系を止め、URL を更新して取得を始める
  StartSearch(String)
  MountStage(Array[@domain.Repo], StageConfig)
}

///|
/// 最初の状態を作る。`user` が空でなければ、すぐに検索を始める。
fn Model::initial(
  user : String,
  still~ : Bool,
  this_year~ : Int32,
) -> (Model, Effect) {
  { query: "", phase: Idle, still, this_year, }.search(user)
}

///|
/// 前後の空白を除いた `query` を検索する。空なら何もしない。
fn Model::search(self : Model, query : String) -> (Model, Effect) {
  let user = query.trim().to_owned()
  if user == "" {
    return (self, NoEffect)
  }
  ({ ..self, query: user, phase: Loading(user), }, StartSearch(user))
}

///|
/// 取得したリポジトリを表示する状態にする。対象が1件もなければ失敗にする。
fn Model::show(
  self : Model,
  profile : @domain.Profile,
  repos : Array[@domain.Repo],
) -> (Model, Effect) {
  guard @domain.year_range(repos) is Some((first_year, newest_year)) else {
    return ({ ..self, phase: Failed(NoRepos), }, NoEffect)
  }
  let last_year = @cmp.maximum(newest_year, self.this_year)
  let config = { first_year, last_year, still: self.still, }
  let stats = @domain.aggregate(repos)
  ({ ..self, phase: Showing({ profile, stats, }), }, MountStage(repos, config))
}

///|
/// `msg` を受けて次の状態と副作用を求める。
/// 取得中の検索や、今の画面に関係のないメッセージは無視する。
fn Model::update(self : Model, msg : Msg) -> (Model, Effect) {
  match (msg, self.phase) {
    (QueryChanged(query), _) => ({ ..self, query, }, NoEffect)
    (Submit, Loading(_)) => (self, NoEffect)
    (Submit, _) => self.search(self.query)
    (Fetched(Ok((profile, repos))), Loading(_)) => self.show(profile, repos)
    (Fetched(Err(error)), Loading(user)) =>
      ({ ..self, phase: Failed(FetchFailed(user~, error)), }, NoEffect)
    _ => (self, NoEffect)
  }
}

///|
/// 画面に出すエラーの文言。`format_time` は UNIX 時刻（秒）を表示用の時刻にする。
fn Failure::message(self : Failure, format_time : (Int32) -> String) -> String {
  match self {
    NoRepos => "言語が判定された公開リポジトリがありません"
    FetchFailed(user~, NotFound) =>
      "ユーザー \{user} が見つかりません"
    FetchFailed(user=_, RateLimited(reset_epoch~)) =>
      "GitHub API の利用上限に達しました。\{format_time(reset_epoch)} 以降にもう一度お試しください"
    FetchFailed(user=_, Network(_)) =>
      "通信に失敗しました。接続を確認してもう一度お試しください"
    FetchFailed(user=_, Decode(_)) =>
      "GitHub の応答を解釈できませんでした。時間をおいてもう一度お試しください"
  }
}
