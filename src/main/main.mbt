///|
using @html {button, canvas, div, input}

///|
using @rabbita {type Val, type Html}

///|
const CANVAS_ID : String = "planets"

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
enum Msg {
  TogglePlay
  /// スライダーの値（年の文字列）
  Seek(String)
  /// 再生が進んで表示する年が変わった
  YearChanged(Int32)
}

///|
/// 再生の操作部の状態を更新する。スライダーの値が年でなければ `None`。
fn Controls::update(self : Controls, msg : Msg) -> Controls? {
  match msg {
    TogglePlay => Some({ ..self, playing: !self.playing, })
    Seek(value) =>
      try @string.parse_int(value) catch {
        _ => None
      } noraise {
        year => Some({ ..self, year, playing: false, })
      }
    YearChanged(year) => Some({ ..self, year, })
  }
}

///|
/// 再生／一時停止のボタンと年スライダー。
fn controls_view(controls : Controls, emit : @cmd.Emit[Msg]) -> Html {
  let label = if controls.playing { "一時停止" } else { "再生" }
  div(class="controls", [
    button(
      class="play",
      type_="button",
      title=label,
      disabled=controls.still,
      attrs=@html.Attrs::build().aria_label(label),
      on_click=(emit.0)(TogglePlay),
      if controls.playing {
        "❚❚"
      } else {
        "▶"
      },
    ),
    input(
      class="year",
      input_type=Range,
      min=controls.first_year,
      max=controls.last_year,
      step=1,
      attrs=@html.Attrs::build()
        .aria_label("表示する年")
        .value_prop(controls.year.to_string()),
      on_input=emit.map(value => Seek(value)),
    ),
  ])
}

///|
/// 惑星系を再生する画面。本物の画面は T4-2 で作る。
fn app() -> Val[Html] {
  let repos = try! fixture_repos()
  guard @domain.year_range(repos) is Some((first_year, last_year)) else {
    abort("fixture に対象のリポジトリがない")
  }
  let still = @ffi.prefers_reduced_motion()
  let stage : Ref[Stage?] = Ref(None)
  let with_stage = (action : (Stage) -> Unit) => {
    @cmd.custom_cmd(_ => if stage.val is Some(stage) { action(stage) })
  }
  let (state, emit) = @rabbita.create_state_with_init(
    init=emit => {
      let controls = {
        first_year,
        last_year,
        year: if still {
          last_year
        } else {
          first_year
        },
        playing: !still,
        still,
      }
      let mount = @cmd.custom_cmd(
        scheduler => {
          let playback = if still {
            @orbit.Playback::finished(first_year, last_year)
          } else {
            @orbit.Playback::start(first_year, last_year, clock_now())
          }
          let on_year = year => scheduler.add((emit.0)(YearChanged(year)))
          stage.val = Stage::mount(repos, playback, on_year)
          if stage.val is Some(stage) {
            stage.apply(playback, clock_now())
          }
        },
        kind=@cmd.after_render,
      )
      (controls, mount)
    },
    update=(controls, msg, _) => {
      guard controls.update(msg) is Some(updated) else {
        return (controls, @rabbita.none)
      }
      let effect = match msg {
        TogglePlay => with_stage(stage => stage.toggle())
        Seek(_) => with_stage(stage => stage.seek(updated.year))
        YearChanged(_) => @rabbita.none
      }
      (updated, effect)
    },
  )
  state.view(controls => {
    div(class="stage", [canvas(id=CANVAS_ID, ""), controls_view(controls, emit)])
  })
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
