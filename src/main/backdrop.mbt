///|
/// 画面全体の背景用キャンバスの id。
const BACKDROP_ID : String = "space"

///|
/// 背景を描き直す最短の間隔（秒）。星の瞬きはゆっくりなので、毎フレームは描かない。
const BACKDROP_INTERVAL : Double = 0.05

///|
/// 画面全体の宇宙の背景を描き続ける。検索の状態に関係なく、起動から常に動く。
///
/// 背景は面積が大きいので、画素数を増やさないよう dpr は 1 で描く。
/// 可変なのは表示サイズ、最後に描いた時刻、予約中のフレームの id だけ。
struct Backdrop {
  element : @ffi.Canvas
  ctx : @ffi.Context2d
  /// `prefers-reduced-motion` のとき `true`。瞬かせず、リサイズ時だけ描き直す
  still : Bool
  mut width : Double
  mut height : Double
  mut drawn_at : Double
}

///|
/// 背景用キャンバスを掴み、表示サイズに合わせて描き始める。見つからないときは何もしない。
fn Backdrop::start(still : Bool) -> Unit {
  guard @ffi.find_canvas(BACKDROP_ID) is Some(element) else { return }
  guard element.context_2d() is Some(ctx) else { return }
  let backdrop = {
    element,
    ctx,
    still,
    width: 0.0,
    height: 0.0,
    drawn_at: -1.0e9,
  }
  backdrop.refit()
  // 監視は画面を開いている間ずっと続けるので、解除しない
  let _ = element.watch_resize(() => backdrop.refit())
  if !still {
    backdrop.schedule()
  }
}

///|
/// 表示サイズが変わっていたら画素数を合わせて描き直す。
fn Backdrop::refit(self : Backdrop) -> Unit {
  let width = self.element.client_width()
  let height = self.element.client_height()
  guard width > 0.0 && height > 0.0 else { return }
  guard width != self.width || height != self.height else { return }
  self.ctx.fit_canvas(width, height, 1.0)
  self.width = width
  self.height = height
  self.draw(clock_now())
}

///|
/// 時計が `clock` のときの背景を描く。動きを減らす設定なら時刻を 0 に固定する。
fn Backdrop::draw(self : Backdrop, clock : Double) -> Unit {
  let t = if self.still { 0.0 } else { clock }
  @render.draw_backdrop(self.ctx, self.width, self.height, t)
  self.drawn_at = clock
}

///|
/// 次のフレームを予約し、前回から `BACKDROP_INTERVAL` 秒以上たっていれば描き直す。
fn Backdrop::schedule(self : Backdrop) -> Unit {
  let _ = @ffi.request_animation_frame(now => {
    let clock = now / 1000.0
    if clock - self.drawn_at >= BACKDROP_INTERVAL {
      self.draw(clock)
    }
    self.schedule()
  })
}

///|
/// 描画後に背景を描き始めるコマンド。起動時に1回だけ使う。
fn backdrop_cmd(still : Bool) -> @cmd.Cmd {
  @cmd.custom_cmd(_ => Backdrop::start(still), kind=@cmd.after_render)
}
