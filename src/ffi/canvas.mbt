///|
/// `<canvas>` 要素。
#external
pub type Canvas

///|
/// Canvas の 2D 描画コンテキスト（`CanvasRenderingContext2D`）。
#external
pub type Context2d

///|
/// 放射グラデーション（`CanvasGradient`）。
#external
pub type Gradient

///|
extern "js" fn canvas_by_id(id : String) -> Canvas =
  #|(id) => {
  #|  const el = document.getElementById(id);
  #|  return el instanceof HTMLCanvasElement ? el : null;
  #|}

///|
extern "js" fn Canvas::is_null(self : Canvas) -> Bool = "(x) => x == null"

///|
extern "js" fn Canvas::context_2d_raw(self : Canvas) -> Context2d = "(c) => c.getContext('2d')"

///|
extern "js" fn Context2d::is_null(self : Context2d) -> Bool = "(x) => x == null"

///|
/// id から `<canvas>` 要素を探す。ないとき、または canvas 以外の要素のときは `None`。
pub fn find_canvas(id : String) -> Canvas? {
  let canvas = canvas_by_id(id)
  if canvas.is_null() {
    None
  } else {
    Some(canvas)
  }
}

///|
/// 2D コンテキストを取得する。取得できないときは `None`。
pub fn Canvas::context_2d(self : Canvas) -> Context2d? {
  let ctx = self.context_2d_raw()
  if ctx.is_null() {
    None
  } else {
    Some(ctx)
  }
}

///|
/// CSS ピクセルでの表示幅（`clientWidth`）。
pub extern "js" fn Canvas::client_width(self : Canvas) -> Double = "(c) => c.clientWidth"

///|
/// 表示サイズを CSS ピクセルで設定し、実際の画素数を `dpr` 倍にする。
///
/// 以後の描画は CSS ピクセルの座標で行える。`canvas.width` を設定すると
/// コンテキストの状態が初期化されるので、変換行列はここで設定し直す。
pub extern "js" fn Context2d::fit_canvas(
  self : Context2d,
  width : Double,
  height : Double,
  dpr : Double,
) -> Unit =
  #|(ctx, width, height, dpr) => {
  #|  const canvas = ctx.canvas;
  #|  canvas.width = Math.round(width * dpr);
  #|  canvas.height = Math.round(height * dpr);
  #|  canvas.style.width = `${width}px`;
  #|  canvas.style.height = `${height}px`;
  #|  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  #|}

///|
pub extern "js" fn Context2d::save(self : Context2d) -> Unit = "(c) => c.save()"

///|
pub extern "js" fn Context2d::restore(self : Context2d) -> Unit = "(c) => c.restore()"

///|
pub extern "js" fn Context2d::translate(
  self : Context2d,
  x : Double,
  y : Double,
) -> Unit = "(c, x, y) => c.translate(x, y)"

///|
/// 座標系を `angle` ラジアン回転する。
pub extern "js" fn Context2d::rotate(self : Context2d, angle : Double) -> Unit = "(c, angle) => c.rotate(angle)"

///|
/// 塗りの色を CSS の色文字列で設定する。
pub extern "js" fn Context2d::set_fill_color(
  self : Context2d,
  color : String,
) -> Unit = "(c, color) => { c.fillStyle = color; }"

///|
/// 塗りにグラデーションを設定する。
pub extern "js" fn Context2d::set_fill_gradient(
  self : Context2d,
  gradient : Gradient,
) -> Unit = "(c, gradient) => { c.fillStyle = gradient; }"

///|
/// 線の色を CSS の色文字列で設定する。
pub extern "js" fn Context2d::set_stroke_color(
  self : Context2d,
  color : String,
) -> Unit = "(c, color) => { c.strokeStyle = color; }"

///|
pub extern "js" fn Context2d::set_line_width(
  self : Context2d,
  width : Double,
) -> Unit = "(c, width) => { c.lineWidth = width; }"

///|
pub extern "js" fn Context2d::fill_rect(
  self : Context2d,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit = "(c, x, y, width, height) => c.fillRect(x, y, width, height)"

///|
pub extern "js" fn Context2d::begin_path(self : Context2d) -> Unit = "(c) => c.beginPath()"

///|
/// 中心 `(x, y)`、半径 `radius` の円弧をパスに足す。角度はラジアン。
pub extern "js" fn Context2d::arc(
  self : Context2d,
  x : Double,
  y : Double,
  radius : Double,
  start_angle : Double,
  end_angle : Double,
) -> Unit =
  #|(c, x, y, radius, startAngle, endAngle) =>
  #|  c.arc(x, y, radius, startAngle, endAngle)

///|
/// 中心 `(x, y)` の楕円弧をパスに足す。角度はラジアン。
pub extern "js" fn Context2d::ellipse(
  self : Context2d,
  x : Double,
  y : Double,
  radius_x : Double,
  radius_y : Double,
  rotation : Double,
  start_angle : Double,
  end_angle : Double,
) -> Unit =
  #|(c, x, y, radiusX, radiusY, rotation, startAngle, endAngle) =>
  #|  c.ellipse(x, y, radiusX, radiusY, rotation, startAngle, endAngle)

///|
pub extern "js" fn Context2d::fill(self : Context2d) -> Unit = "(c) => c.fill()"

///|
pub extern "js" fn Context2d::stroke(self : Context2d) -> Unit = "(c) => c.stroke()"

///|
/// 放射グラデーションを作る。円 `(x0, y0, r0)` から円 `(x1, y1, r1)` へ変化する。
pub extern "js" fn Context2d::create_radial_gradient(
  self : Context2d,
  x0 : Double,
  y0 : Double,
  r0 : Double,
  x1 : Double,
  y1 : Double,
  r1 : Double,
) -> Gradient =
  #|(c, x0, y0, r0, x1, y1, r1) =>
  #|  c.createRadialGradient(x0, y0, r0, x1, y1, r1)

///|
/// `offset`（0〜1）の位置に色を足す。
pub extern "js" fn Gradient::add_color_stop(
  self : Gradient,
  offset : Double,
  color : String,
) -> Unit = "(g, offset, color) => g.addColorStop(offset, color)"

///|
/// フォントを CSS の `font` の書式で設定する。
pub extern "js" fn Context2d::set_font(self : Context2d, font : String) -> Unit = "(c, font) => { c.font = font; }"

///|
/// 文字揃えを設定する（`"left"` / `"center"` など）。
pub extern "js" fn Context2d::set_text_align(
  self : Context2d,
  align : String,
) -> Unit = "(c, align) => { c.textAlign = align; }"

///|
pub extern "js" fn Context2d::fill_text(
  self : Context2d,
  text : String,
  x : Double,
  y : Double,
) -> Unit = "(c, text, x, y) => c.fillText(text, x, y)"

///|
/// 現在のフォントで描いたときの文字列の幅を返す。
pub extern "js" fn Context2d::measure_text(
  self : Context2d,
  text : String,
) -> Double = "(c, text) => c.measureText(text).width"
