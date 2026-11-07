///|
const BACKGROUND : String = "#0b0d14"

///|
const ORBIT_COLOR : String = "rgba(231,233,240,.12)"

///|
const STAR_CORE_COLOR : String = "rgba(255,255,255,.75)"

///|
const LABEL_COLOR : String = "rgba(231,233,240,.6)"

///|
const STATUS_COLOR : String = "rgba(231,233,240,.85)"

///|
/// 惑星の半径（`s` 倍して使う）。
const PLANET_RADIUS : Double = 3.0

///|
/// 惑星の半径に足す長さ（px）。キャンバスが小さくても点として見えるようにする。
const PLANET_MIN_RADIUS : Double = 0.3

///|
/// 恒星の半径に対する光彩の半径の比。
const GLOW_RATIO : Double = 2.6

///|
/// 恒星の半径に対する白い核の半径の比。
const CORE_RATIO : Double = 0.55

///|
/// 言語名の文字の大きさ（`s` 倍して使う）。
const LABEL_FONT_SIZE : Double = 10.5

///|
/// 年と件数の文字の大きさ（`s` 倍して使う）。
const STATUS_FONT_SIZE : Double = 13.0

///|
/// 年と件数の左端の位置（`s` 倍して使う）。
const STATUS_X : Double = 14.0

///|
/// 年と件数のベースラインの位置（`s` 倍して使う）。
const STATUS_Y : Double = 24.0

///|
/// 大きさ `size` を倍率 `s` で拡大した、Canvas の `font` の文字列を返す。
fn font(size : Double, s : Double) -> String {
  let px = (size * s).round().to_int()
  "500 \{px}px \"IBM Plex Mono\", ui-monospace, monospace"
}

///|
/// 左上に表示する年と件数の文字列を返す。
fn status_text(year : Int32, shown : Int32, total : Int32) -> String {
  "\{year}  ·  \{shown}/\{total} repos"
}

///|
/// 軌道の線を描く。
fn draw_orbit(
  ctx : @ffi.Context2d,
  system : @layout.System,
  radius : Double,
) -> Unit {
  ctx.set_stroke_color(ORBIT_COLOR)
  ctx.set_line_width(1.0)
  ctx.begin_path()
  ctx.ellipse(
    system.x,
    system.y,
    radius,
    radius * @layout.ORBIT_ASPECT,
    system.tilt,
    0.0,
    2.0 * @math.PI,
  )
  ctx.stroke()
}

///|
/// 円を塗る。
fn fill_circle(
  ctx : @ffi.Context2d,
  x : Double,
  y : Double,
  radius : Double,
) -> Unit {
  ctx.begin_path()
  ctx.arc(x, y, radius, 0.0, 2.0 * @math.PI)
  ctx.fill()
}

///|
/// 恒星を描く。言語色の光彩の上に白い核を重ねる。
fn draw_star(ctx : @ffi.Context2d, system : @layout.System) -> Unit {
  let { x, y, star_radius, color, .. } = system
  let glow_radius = star_radius * GLOW_RATIO
  let glow = ctx.create_radial_gradient(x, y, 0.0, x, y, glow_radius)
  glow.add_color_stop(0.0, color)
  glow.add_color_stop(0.38, color + "aa")
  glow.add_color_stop(1.0, color + "00")
  ctx.set_fill_gradient(glow)
  fill_circle(ctx, x, y, glow_radius)
  ctx.set_fill_color(STAR_CORE_COLOR)
  fill_circle(ctx, x, y, star_radius * CORE_RATIO)
}

///|
/// 時刻 `t`（秒）の惑星系を1フレーム描く。
///
/// `year` までに作成されたリポジトリの惑星だけを描く。`ctx` の座標は
/// CSS ピクセルで、`canvas` と同じ大きさになっている前提。
pub fn draw_frame(
  ctx : @ffi.Context2d,
  canvas : @layout.Canvas,
  systems : Array[@layout.System],
  planets : Array[@orbit.Planet],
  t : Double,
  year : Int32,
) -> Unit {
  let s = canvas.scale()
  ctx.set_fill_color(BACKGROUND)
  ctx.fill_rect(0.0, 0.0, canvas.width, canvas.height)
  // 軌道と惑星
  let visible = @orbit.visible_until(year, planets)
  for index in visible {
    let planet = planets[index]
    let system = systems[planet.system_index]
    draw_orbit(ctx, system, planet.orbit_radius)
    let (x, y) = @orbit.position(planet, systems, t)
    ctx.set_fill_color(system.color)
    fill_circle(ctx, x, y, PLANET_RADIUS * s + PLANET_MIN_RADIUS)
  }
  // 恒星
  for system in systems {
    draw_star(ctx, system)
  }
  // 言語名
  ctx.set_font(font(LABEL_FONT_SIZE, s))
  ctx.set_text_align("center")
  ctx.set_fill_color(LABEL_COLOR)
  for system in systems {
    ctx.fill_text(system.language, system.x, system.label_baseline(canvas))
  }
  // 年と件数
  ctx.set_font(font(STATUS_FONT_SIZE, s))
  ctx.set_text_align("left")
  ctx.set_fill_color(STATUS_COLOR)
  ctx.fill_text(
    status_text(year, visible.length(), planets.length()),
    STATUS_X * s,
    STATUS_Y * s,
  )
}
