///|
/// 高解像度の画面でも描く画素数を増やしすぎないための dpr の上限。
const MAX_DPR : Double = 2.0

///|
/// キャンバスの幅に対する高さの比（16:10）。
const CANVAS_ASPECT : Double = 0.625

///|
/// 配置と初期位相の乱数のシード。プロトタイプと同じ値。
const SEED : Int32 = 11

///|
/// キャンバスへの描画と rAF のループを受け持つ。Rabbita の仮想 DOM の外にある。
///
/// 可変なのは再生の状態の差し替えと、予約中のフレームの id だけで、
/// 描く内容は毎回 `playback` と時計から求める。
struct Stage {
  ctx : @ffi.Context2d
  size : @layout.Canvas
  systems : Array[@layout.System]
  planets : Array[@orbit.Planet]
  /// 表示する年が変わったときに呼ぶ
  on_year : (Int32) -> Unit
  mut playback : @orbit.Playback
  mut shown_year : Int32
  mut frame : Int32?
}

///|
/// ページを開いてからの経過時間（秒）。
fn clock_now() -> Double {
  @ffi.performance_now() / 1000.0
}

///|
/// canvas を今の幅に合わせ、`repos` の惑星系を描く準備をする。
/// canvas が見つからないときは `None`。
fn Stage::mount(
  repos : Array[@domain.Repo],
  playback : @orbit.Playback,
  on_year : (Int32) -> Unit,
) -> Stage? {
  guard @ffi.find_canvas(CANVAS_ID) is Some(element) else { return None }
  guard element.context_2d() is Some(ctx) else { return None }
  let width = element.client_width()
  let size : @layout.Canvas = { width, height: width * CANVAS_ASPECT, }
  ctx.fit_canvas(
    size.width,
    size.height,
    @cmp.minimum(MAX_DPR, @ffi.device_pixel_ratio()),
  )
  let systems = @layout.layout(@domain.aggregate(repos), size, SEED)
  let planets = @orbit.planets(repos, systems, size, SEED)
  Some({
    ctx,
    size,
    systems,
    planets,
    on_year,
    playback,
    shown_year: playback.year(clock_now()),
    frame: None,
  })
}

///|
/// 予約中のフレームを取り消し、ループを止める。
fn Stage::stop(self : Stage) -> Unit {
  if self.frame is Some(id) {
    @ffi.cancel_animation_frame(id)
    self.frame = None
  }
}

///|
/// 時計が `clock` のときの1フレームを描き、年が変わっていれば知らせる。
fn Stage::draw(self : Stage, clock : Double) -> Unit {
  @render.draw_frame(
    self.ctx,
    self.size,
    self.systems,
    self.planets,
    self.playback,
    clock,
  )
  let year = self.playback.year(clock)
  if year != self.shown_year {
    self.shown_year = year
    (self.on_year)(year)
  }
}

///|
/// 再生中なら次のフレームを予約する。すでに予約があれば何もしない。
fn Stage::schedule(self : Stage) -> Unit {
  guard self.playback.is_running() && self.frame is None else { return }
  let id = @ffi.request_animation_frame(now => {
    self.frame = None
    self.draw(now / 1000.0)
    self.schedule()
  })
  self.frame = Some(id)
}

///|
/// 再生の状態を差し替え、今の状態を描く。再生中ならループを回し、止まったら取り消す。
fn Stage::apply(
  self : Stage,
  playback : @orbit.Playback,
  clock : Double,
) -> Unit {
  self.playback = playback
  if !playback.is_running() {
    self.stop()
  }
  self.draw(clock)
  self.schedule()
}

///|
/// 再生中なら一時停止し、止まっていれば続きから再生する。
fn Stage::toggle(self : Stage) -> Unit {
  let clock = clock_now()
  let playback = if self.playback.is_running() {
    self.playback.pause(clock)
  } else {
    self.playback.play(clock)
  }
  self.apply(playback, clock)
}

///|
/// `year` の始まりへ移動して止める。
fn Stage::seek(self : Stage, year : Int32) -> Unit {
  let clock = clock_now()
  self.apply(self.playback.seek(year, clock), clock)
}
