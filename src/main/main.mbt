///|
using @html {canvas, div}

///|
using @rabbita {type Val, type Html}

///|
const CANVAS_ID : String = "planets"

///|
/// 配置と初期位相の乱数のシード。プロトタイプと同じ値。
const SEED : Int32 = 11

///|
/// 描くフレームの時刻（秒）。再生が終わるころに合わせる。
const FRAME_TIME : Double = 10.0

///|
/// キャンバスの幅に対する高さの比（16:10）。
const CANVAS_ASPECT : Double = 0.625

///|
/// 高解像度の画面でも描く画素数を増やしすぎないための dpr の上限。
const MAX_DPR : Double = 2.0

///|
/// fixture のデータで、すべての惑星が揃った時点の惑星系を1フレーム描く。
fn draw_fixture() -> Unit {
  guard @ffi.find_canvas(CANVAS_ID) is Some(element) else { return }
  guard element.context_2d() is Some(ctx) else { return }
  let repos = try! fixture_repos()
  guard @domain.year_range(repos) is Some((_, last_year)) else { return }
  let width = element.client_width()
  let size : @layout.Canvas = { width, height: width * CANVAS_ASPECT, }
  ctx.fit_canvas(
    size.width,
    size.height,
    @cmp.minimum(MAX_DPR, @ffi.device_pixel_ratio()),
  )
  let systems = @layout.layout(@domain.aggregate(repos), size, SEED)
  let planets = @orbit.planets(repos, systems, size, SEED)
  @render.draw_frame(ctx, size, systems, planets, FRAME_TIME, last_year)
}

///|
/// 惑星系を静止画で表示する画面。本物の画面は T4-2 で作る。
fn app() -> Val[Html] {
  let (state, _) = @rabbita.create_state_with_init(
    init=_ => {
      let draw = @cmd.custom_cmd(_ => draw_fixture(), kind=@cmd.after_render)
      ((), draw)
    },
    update=(state, _ : Unit, _) => (state, @rabbita.none),
  )
  state.view(_ => div(class="stage", canvas(id=CANVAS_ID, "")))
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
