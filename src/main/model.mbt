///|
/// 再生の操作部の状態。キャンバスの描画は `Stage` が受け持つ。
#derive(Eq)
struct Controls {
  first_year : Int32
  last_year : Int32
  year : Int32
  playing : Bool
  /// `prefers-reduced-motion` のとき `true`。再生できないようにする
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
  stats : Array[@domain.LanguageStat]
  controls : Controls
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
  /// 今の年。再生の終わりの年に使う
  this_year : Int32
}

///|
enum Msg {
  QueryChanged(String)
  Submit
  Fetched(Result[(@domain.Profile, Array[@domain.Repo]), @source.FetchError])
  TogglePlay
  /// スライダーの値（年の文字列）
  Seek(String)
  /// 再生が進んで表示する年が変わった
  YearChanged(Int32)
}

///|
/// 状態の更新に伴って行う副作用。実行は `run_effect` が受け持つ。
enum Effect {
  NoEffect
  /// 前の惑星系を止め、URL を更新して取得を始める
  StartSearch(String)
  MountStage(Array[@domain.Repo], Controls)
  ToggleStage
  SeekStage(Int32)
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
  let controls = {
    first_year,
    last_year,
    year: if self.still {
      last_year
    } else {
      first_year
    },
    playing: !self.still,
    still: self.still,
  }
  let stats = @domain.aggregate(repos)
  (
    { ..self, phase: Showing({ profile, stats, controls, }), },
    MountStage(repos, controls),
  )
}

///|
fn Model::with_controls(
  self : Model,
  shown : Shown,
  controls : Controls,
) -> Model {
  { ..self, phase: Showing({ ..shown, controls, }), }
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
    (TogglePlay, Showing(shown)) => {
      let controls = { ..shown.controls, playing: !shown.controls.playing, }
      (self.with_controls(shown, controls), ToggleStage)
    }
    (Seek(value), Showing(shown)) =>
      try @string.parse_int(value) catch {
        _ => (self, NoEffect)
      } noraise {
        year => {
          let controls = { ..shown.controls, year, playing: false, }
          (self.with_controls(shown, controls), SeekStage(year))
        }
      }
    (YearChanged(year), Showing(shown)) => {
      let controls = { ..shown.controls, year, }
      (self.with_controls(shown, controls), NoEffect)
    }
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

///|
/// 凡例の1項目の文字列。割合は小数第1位に四捨五入する。
fn legend_text(stat : @domain.LanguageStat, total : Int32) -> String {
  let tenths = (stat.count * 2000 + total) / (2 * total)
  "\{stat.name} \{stat.count}（\{tenths / 10}.\{tenths % 10}%）"
}
