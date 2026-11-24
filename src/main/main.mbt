///|
using @rabbita {type Val}

///|
/// プロフィールと、集計の対象になるリポジトリを取得する。
async fn load(
  user : String,
) -> (@domain.Profile, Array[@domain.Repo]) raise @source.FetchError {
  let profile = @source.fetch_profile(user)
  (profile, @source.fetch_repos(user, profile.public_repos))
}

///|
/// 描画中の惑星系を止めて手放す。
fn release_stage(holder : Ref[Stage?]) -> Unit {
  if holder.val is Some(stage) {
    stage.release()
    holder.val = None
  }
}

///|
/// 描画後に canvas を掴み、すべての惑星が揃った `repos` の惑星系を表示する。
fn mount_cmd(
  holder : Ref[Stage?],
  repos : Array[@domain.Repo],
  config : StageConfig,
) -> @cmd.Cmd {
  @cmd.custom_cmd(
    _ => {
      let { first_year, last_year, still, } = config
      let finished = @orbit.Playback::finished(first_year, last_year)
      let playback = if still { finished } else { finished.play(clock_now()) }
      holder.val = Stage::mount(repos, playback)
      if holder.val is Some(stage) {
        stage.apply(playback, clock_now())
      }
    },
    kind=@cmd.after_render,
  )
}

///|
/// `Model::update` が求めた副作用をコマンドにする。
fn run_effect(
  effect : Effect,
  holder : Ref[Stage?],
  emit : @cmd.Emit[Msg],
) -> @cmd.Cmd {
  match effect {
    NoEffect => @rabbita.none
    StartSearch(user) =>
      @cmd.batch([
        @cmd.custom_cmd(_ => {
          release_stage(holder)
          @ffi.set_query_param("user", user)
        }),
        @cmd.attempt(result => (emit.0)(Fetched(result)), () => load(user)),
      ])
    MountStage(repos, config) => mount_cmd(holder, repos, config)
  }
}

///|
/// 画面全体。`?user=xxx` があれば開いてすぐ検索する。
fn app() -> Val[Html] {
  let holder : Ref[Stage?] = Ref(None)
  let (state, emit) = @rabbita.create_state_with_init(
    init=emit => {
      let (model, effect) = Model::initial(
        @ffi.query_param("user"),
        still=@ffi.prefers_reduced_motion(),
        this_year=@ffi.current_year(),
      )
      (model, run_effect(effect, holder, emit))
    },
    update=(model, msg, emit) => {
      let (updated, effect) = model.update(msg)
      (updated, run_effect(effect, holder, emit))
    },
  )
  state.view(model => view(model, emit))
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
