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
/// キャンバスへの描画と rAF のループ、ポインターの操作を受け持つ。
/// Rabbita の仮想 DOM の外にある。
///
/// 可変なのは再生・配置・ポインターの状態の差し替えと、予約中のフレームの id だけで、
/// 描く内容は毎回それらと時計から求める。
struct Stage {
  element : @ffi.Canvas
  ctx : @ffi.Context2d
  repos : Array[@domain.Repo]
  /// 表示する年が変わったときに呼ぶ
  on_year : (Int32) -> Unit
  /// 手放すときに解除するイベントの監視
  subscriptions : Array[@ffi.Subscription]
  mut size : @layout.Canvas
  mut systems : Array[@layout.System]
  mut planets : Array[@orbit.Planet]
  mut playback : @orbit.Playback
  mut pointer : Pointer
  /// カーソルが指の形になっているとき `true`
  mut pointing : Bool
  mut shown_year : Int32
  mut frame : Int32?
}

///|
/// ページを開いてからの経過時間（秒）。
fn clock_now() -> Double {
  @ffi.performance_now() / 1000.0
}

///|
/// 幅 `width` のキャンバスの大きさを返し、実際の画素数を合わせる。
fn fit_canvas(ctx : @ffi.Context2d, width : Double) -> @layout.Canvas {
  let size : @layout.Canvas = { width, height: width * CANVAS_ASPECT, }
  ctx.fit_canvas(
    size.width,
    size.height,
    @cmp.minimum(MAX_DPR, @ffi.device_pixel_ratio()),
  )
  size
}

///|
/// 大きさ `size` のキャンバスに合わせて、恒星と惑星を配置する。
fn arrange(
  repos : Array[@domain.Repo],
  size : @layout.Canvas,
) -> (Array[@layout.System], Array[@orbit.Planet]) {
  let systems = @layout.layout(@domain.aggregate(repos), size, SEED)
  (systems, @orbit.planets(repos, systems, size, SEED))
}

///|
/// canvas を今の幅に合わせ、`repos` の惑星系を描く準備をして、操作の監視を始める。
/// canvas が見つからないときは `None`。
fn Stage::mount(
  repos : Array[@domain.Repo],
  playback : @orbit.Playback,
  on_year : (Int32) -> Unit,
) -> Stage? {
  guard @ffi.find_canvas(CANVAS_ID) is Some(element) else { return None }
  guard element.context_2d() is Some(ctx) else { return None }
  let size = fit_canvas(ctx, element.client_width())
  let (systems, planets) = arrange(repos, size)
  let stage = {
    element,
    ctx,
    repos,
    on_year,
    subscriptions: [],
    size,
    systems,
    planets,
    playback,
    pointer: Away,
    pointing: false,
    shown_year: playback.year(clock_now()),
    frame: None,
  }
  stage.subscriptions.push(
    element.watch_pointer(
      (x, y) => stage.point(Hovering(x, y)),
      () => stage.point(Away),
      (x, y, touch) => if touch { stage.touch(x, y) } else { stage.click(x, y) },
    ),
  )
  stage.subscriptions.push(element.watch_resize(() => stage.refit()))
  Some(stage)
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
/// ループを止め、イベントの監視を解除する。
fn Stage::release(self : Stage) -> Unit {
  self.stop()
  for subscription in self.subscriptions {
    subscription.cancel()
  }
  self.subscriptions.clear()
  // 再検索では同じ canvas 要素が使い回されることがある
  self.element.set_cursor("")
}

///|
/// 時計が `clock` のときの1フレームを描き、年が変わっていれば知らせる。
fn Stage::draw(self : Stage, clock : Double) -> Unit {
  let year = self.playback.year(clock)
  let hover = self.pointer.target(
    self.playback.time(clock),
    year,
    self.planets,
    self.systems,
    self.size,
  )
  @render.draw_frame(
    self.ctx,
    self.size,
    self.systems,
    self.planets,
    self.playback,
    clock,
    hover,
  )
  let pointing = hover is Some(Planet(_))
  if pointing != self.pointing {
    self.pointing = pointing
    self.element.set_cursor(if pointing { "pointer" } else { "" })
  }
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

///|
/// ポインターの状態を差し替える。再生中は次のフレームで、止まっていればすぐに描く。
fn Stage::point(self : Stage, pointer : Pointer) -> Unit {
  self.pointer = pointer
  if !self.playback.is_running() {
    self.draw(clock_now())
  }
}

///|
/// 座標 `(x, y)` にある惑星または恒星を今の時刻で判定する。
fn Stage::hit_at(
  self : Stage,
  x : Double,
  y : Double,
  min_reach~ : Double = 0.0,
) -> @orbit.Hit? {
  let clock = clock_now()
  @orbit.hit_test(
    x,
    y,
    self.playback.time(clock),
    self.planets,
    self.systems,
    self.size,
    self.playback.year(clock),
    min_reach~,
  )
}

///|
/// 添字 `index` の惑星のリポジトリを新しいタブで開く。
fn Stage::open_planet(self : Stage, index : Int32) -> Unit {
  @ffi.open_new_tab(self.planets[index].repo.url)
}

///|
/// マウスでクリックされた。惑星ならリポジトリを開く。
fn Stage::click(self : Stage, x : Double, y : Double) -> Unit {
  if self.hit_at(x, y) is Some(Planet(index)) {
    self.open_planet(index)
  }
}

///|
/// 指でタップされた。まず通常の半径で判定し、外れたら指の大きさまで広げる。
/// 最初から広げると、恒星をタップしても周りの惑星が選ばれてしまう。
fn Stage::touch(self : Stage, x : Double, y : Double) -> Unit {
  let hit = match self.hit_at(x, y) {
    None => self.hit_at(x, y, min_reach=TOUCH_REACH)
    hit => hit
  }
  let (pointer, opened) = self.pointer.tapped(hit)
  self.point(pointer)
  if opened is Some(index) {
    self.open_planet(index)
  }
}

///|
/// 表示の幅が変わっていたら配置を計算し直す。再生の状態はそのまま続く。
fn Stage::refit(self : Stage) -> Unit {
  let width = self.element.client_width()
  guard width > 0.0 && width != self.size.width else { return }
  let size = fit_canvas(self.ctx, width)
  let (systems, planets) = arrange(self.repos, size)
  self.size = size
  self.systems = systems
  self.planets = planets
  self.pointer = Away
  self.draw(clock_now())
}
