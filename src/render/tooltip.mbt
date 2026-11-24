///|
const TIP_BACKGROUND : String = "rgba(19,23,34,.94)"

///|
const TIP_TEXT_COLOR : String = "#e7e9f0"

///|
/// ツールチップの文字の大きさ（px）。キャンバスの大きさによらず一定にする。
const TIP_FONT_SIZE : Double = 13.0

///|
const TIP_HEIGHT : Double = 26.0

///|
/// ツールチップの左右の余白（`s` 倍して使う）。
const TIP_PADDING : Double = 8.0

///|
const TIP_CORNER : Double = 6.0

///|
/// 対象からツールチップまでの横の距離（`s` 倍して使う）。
const TIP_OFFSET_X : Double = 12.0

///|
/// 対象の上に置くときの隙間（`s` 倍して使う）。
const TIP_GAP_ABOVE : Double = 10.0

///|
/// 対象の下に置くときの隙間（`s` 倍して使う）。
const TIP_GAP_BELOW : Double = 14.0

///|
/// キャンバスの端とツールチップの間に空ける長さ（px）。
const TIP_MARGIN : Double = 4.0

///|
/// ツールチップの倍率。キャンバスを広げても文字が大きくなりすぎないよう、常に等倍で描く。
const TIP_SCALE : Double = 1.0

///|
/// 強調する白い輪の半径（`s` 倍して使う）。
const RING_RADIUS : Double = 5.0

///|
/// ツールチップの位置と大きさ。
priv struct TipBox {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
/// ツールチップの文字列を返す。恒星の割合は全リポジトリに対する値。
fn tooltip_text(
  hit : @orbit.Hit,
  planets : Array[@orbit.Planet],
  systems : Array[@layout.System],
) -> String {
  match hit {
    Planet(index) => {
      let repo = planets[index].repo
      "\{repo.name} · \{repo.language} · \{repo.created_year}"
    }
    Star(index) => {
      let count = planets
        .filter(planet => planet.system_index == index)
        .length()
      let percent = @domain.percent_text(count, planets.length())
      "\{systems[index].language} · \{count} repos（\{percent}%）"
    }
  }
}

///|
/// `text` が `max_width` に収まらなければ、末尾を削って「…」を付ける。
fn fit_text(
  text : String,
  max_width : Double,
  measure : (String) -> Double,
) -> String {
  if measure(text) <= max_width {
    return text
  }
  for length = text.length() - 1; length > 0; length = length - 1 {
    let shortened = text[:length].to_owned() + "…"
    if measure(shortened) <= max_width {
      return shortened
    }
  }
  "…"
}

///|
/// `(x, y)` の対象に添えるツールチップの位置を求める。
/// 左右はキャンバス内に収め、上に置く場所がなければ対象の下に置く。
fn tip_box(
  x : Double,
  y : Double,
  text_width : Double,
  canvas_width : Double,
  s : Double,
) -> TipBox {
  let width = text_width + 2.0 * TIP_PADDING * s
  let height = TIP_HEIGHT * s
  let above = y - height - TIP_GAP_ABOVE * s
  {
    x: @cmp.maximum(
      TIP_MARGIN,
      @cmp.minimum(canvas_width - width - TIP_MARGIN, x + TIP_OFFSET_X * s),
    ),
    y: if above < TIP_MARGIN {
      y + TIP_GAP_BELOW * s
    } else {
      above
    },
    width,
    height,
  }
}

///|
/// `(x, y)` の対象に、`color` の枠のツールチップを描く。
fn draw_tip(
  ctx : @ffi.Context2d,
  canvas : @layout.Canvas,
  x : Double,
  y : Double,
  text : String,
  color : String,
) -> Unit {
  let s = TIP_SCALE
  ctx.set_font(font(TIP_FONT_SIZE, s))
  let max_width = canvas.width - 2.0 * (TIP_MARGIN + TIP_PADDING * s)
  let shown = fit_text(text, max_width, candidate => ctx.measure_text(candidate))
  let tip = tip_box(x, y, ctx.measure_text(shown), canvas.width, s)
  ctx.set_fill_color(TIP_BACKGROUND)
  ctx.set_stroke_color(color)
  ctx.set_line_width(1.2)
  ctx.begin_path()
  ctx.round_rect(tip.x, tip.y, tip.width, tip.height, TIP_CORNER * s)
  ctx.fill()
  ctx.stroke()
  ctx.set_fill_color(TIP_TEXT_COLOR)
  ctx.set_text_align("left")
  ctx.set_text_baseline("middle")
  ctx.fill_text(shown, tip.x + TIP_PADDING * s, tip.y + tip.height / 2.0)
  ctx.set_text_baseline("alphabetic")
}

///|
/// `hit` のツールチップを描く。惑星は白い輪で強調する。
fn draw_hover(
  ctx : @ffi.Context2d,
  canvas : @layout.Canvas,
  systems : Array[@layout.System],
  planets : Array[@orbit.Planet],
  hit : @orbit.Hit,
  t : Double,
) -> Unit {
  let text = tooltip_text(hit, planets, systems)
  match hit {
    Planet(index) => {
      let planet = planets[index]
      let (x, y) = @orbit.position(planet, systems, t)
      ctx.set_stroke_color("#fff")
      ctx.set_line_width(1.5)
      ctx.begin_path()
      ctx.arc(x, y, RING_RADIUS * canvas.scale(), 0.0, 2.0 * @math.PI)
      ctx.stroke()
      draw_tip(ctx, canvas, x, y, text, systems[planet.system_index].color)
    }
    Star(index) => {
      let system = systems[index]
      draw_tip(ctx, canvas, system.x, system.y, text, system.color)
    }
  }
}
