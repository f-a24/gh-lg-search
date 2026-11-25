///|
const BACKGROUND : String = "#0b0d14"

///|
const ORBIT_COLOR : String = "rgba(231,233,240,.2)"

///|
const STAR_CORE_COLOR : String = "rgba(255,255,255,.75)"

///|
const LABEL_COLOR : String = "rgba(231,233,240,.92)"

///|
/// 言語名の縁取りの色。恒星の明るい核の上でも文字を読めるようにする。
const LABEL_OUTLINE_COLOR : String = "rgba(11,13,20,.8)"

///|
/// 言語名の縁取りの太さ（文字の大きさに対する比）。
const LABEL_OUTLINE_RATIO : Double = 0.3

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
/// 件数の文字の大きさ（`s` 倍して使う）。
const STATUS_FONT_SIZE : Double = 10.0

///|
/// 件数の左端の位置（`s` 倍して使う）。
const STATUS_X : Double = 14.0

///|
/// 件数のベースラインの位置（`s` 倍して使う）。
const STATUS_Y : Double = 20.0

///|
/// 大きさ `size` を倍率 `s` で拡大した、Canvas の `font` の文字列を返す。
fn font(size : Double, s : Double) -> String {
  let px = (size * s).round().to_int()
  "500 \{px}px \"IBM Plex Mono\", ui-monospace, monospace"
}

///|
/// 左上に表示する、今見えているリポジトリの件数の文字列を返す。
fn status_text(shown : Int32) -> String {
  "\{shown} repos"
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
/// 出現の倍率 `grow`（0〜1）のときの惑星の半径を返す。
fn planet_radius(s : Double, grow : Double) -> Double {
  PLANET_RADIUS * s * grow + PLANET_MIN_RADIUS
}

///|
/// 時計が `clock` のときの惑星系を1フレーム描く。
///
/// 再生の状態から求めた年までに作成されたリポジトリの惑星だけを描く。
/// `hover` があれば、その惑星や恒星のツールチップを重ねる。
/// `ctx` の座標は CSS ピクセルで、`canvas` と同じ大きさになっている前提。
pub fn draw_frame(
  ctx : @ffi.Context2d,
  canvas : @layout.Canvas,
  systems : Array[@layout.System],
  planets : Array[@orbit.Planet],
  playback : @orbit.Playback,
  clock : Double,
  hover : @orbit.Hit?,
) -> Unit {
  let s = canvas.scale()
  let t = playback.time(clock)
  let year = playback.year(clock)
  // 背景は画面全体の背景用キャンバス（`draw_backdrop`）が描くので、ここでは透明にする
  ctx.clear_rect(0.0, 0.0, canvas.width, canvas.height)
  // 軌道と惑星
  let visible = @orbit.visible_until(year, planets)
  for index in visible {
    let planet = planets[index]
    let system = systems[planet.system_index]
    draw_orbit(ctx, system, planet.orbit_radius)
    let (x, y) = @orbit.position(planet, systems, t)
    ctx.set_fill_color(system.color)
    let grow = playback.planet_scale(planet.repo.created_year, clock)
    fill_circle(ctx, x, y, planet_radius(s, grow))
  }
  // 恒星
  for system in systems {
    draw_star(ctx, system)
  }
  // 言語名（恒星の中心に重ね、暗い縁取りで読みやすくする）
  let label_size = canvas.label_font_size()
  ctx.set_font(font(label_size, 1.0))
  ctx.set_text_align("center")
  ctx.set_text_baseline("middle")
  ctx.set_line_join("round")
  ctx.set_line_width(label_size * LABEL_OUTLINE_RATIO)
  ctx.set_stroke_color(LABEL_OUTLINE_COLOR)
  ctx.set_fill_color(LABEL_COLOR)
  for system in systems {
    ctx.stroke_text(system.language, system.x, system.y)
    ctx.fill_text(system.language, system.x, system.y)
  }
  ctx.set_text_baseline("alphabetic")
  // 件数
  ctx.set_font(font(STATUS_FONT_SIZE, s))
  ctx.set_text_align("left")
  ctx.set_fill_color(STATUS_COLOR)
  ctx.fill_text(status_text(visible.length()), STATUS_X * s, STATUS_Y * s)
  if hover is Some(hit) {
    draw_hover(ctx, canvas, systems, planets, hit, t)
  }
}
