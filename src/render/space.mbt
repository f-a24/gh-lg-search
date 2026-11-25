///|
/// 背景の星の最大数。
const SPACE_STAR_LIMIT : Int32 = 420

///|
/// 背景の星 1 個あたりの面積（px²）。キャンバスが広いほど星を増やす。
const SPACE_STAR_AREA : Double = 2400.0

///|
/// 背景の星を作る乱数のシード。惑星系の配置とは独立に固定する。
const SPACE_SEED : Int32 = 20261125

///|
/// 背景の星の色。ほとんどは白で、ときどき青白い星と黄色い星を混ぜる。
const SPACE_STAR_WHITE : String = "#ffffff"

///|
const SPACE_STAR_BLUE : String = "#b9cdff"

///|
const SPACE_STAR_YELLOW : String = "#ffe7b8"

///|
/// 背景の星。座標はキャンバスの幅と高さに対する割合（0〜1）で持ち、リサイズしても同じ星空にする。
priv struct SpaceStar {
  x : Double
  y : Double
  /// 半径（px）
  radius : Double
  /// 明るさの基準（0〜1）
  alpha : Double
  /// 瞬きの位相（ラジアン）
  phase : Double
  /// 瞬きの角速度（ラジアン/秒）
  speed : Double
  color : String
}

///|
/// 星雲。位置と半径はキャンバスに対する割合で持つ。
priv struct Nebula {
  x : Double
  y : Double
  /// キャンバスの幅に対する半径の割合
  radius : Double
  /// 中心の色（不透明度を含む）
  color : String
}

///|
/// シードから背景の星を `count` 個作る。同じシードなら同じ星空になる。
fn starfield(seed : Int32, count : Int32) -> Array[SpaceStar] {
  let random = @layout.Random::new(seed)
  Array::makei(count, _ => {
    let x = random.next_double()
    let y = random.next_double()
    // 小さく暗い星を多く、大きく明るい星を少なくする
    let size = random.next_double()
    let radius = 0.35 + size * size * size * 1.15
    let alpha = 0.25 + random.next_double() * 0.6
    let phase = random.next_double() * 2.0 * @math.PI
    let speed = 0.4 + random.next_double() * 1.4
    let tint = random.next_double()
    let color = if tint < 0.12 {
      SPACE_STAR_BLUE
    } else if tint < 0.2 {
      SPACE_STAR_YELLOW
    } else {
      SPACE_STAR_WHITE
    }
    { x, y, radius, alpha, phase, speed, color, }
  })
}

///|
/// 背景の星の並び。描画のたびに作り直さないよう一度だけ作る。
let space_stars : Array[SpaceStar] = starfield(SPACE_SEED, SPACE_STAR_LIMIT)

///|
/// 星雲の並び。キャンバスの端に寄せて、惑星系の邪魔をしない淡さにする。
let nebulae : Array[Nebula] = [
  { x: 0.18, y: 0.22, radius: 0.42, color: "rgba(88,64,170,.16)", },
  { x: 0.86, y: 0.78, radius: 0.46, color: "rgba(36,96,160,.14)", },
  { x: 0.7, y: 0.12, radius: 0.3, color: "rgba(150,52,120,.09)", },
]

///|
/// 幅 `width`、高さ `height` のキャンバスに描く背景の星の数を返す。
fn space_star_count(width : Double, height : Double) -> Int32 {
  let count = (width * height / SPACE_STAR_AREA).to_int()
  @cmp.minimum(SPACE_STAR_LIMIT, @cmp.maximum(0, count))
}

///|
/// 時刻 `t`（秒）のときの星の明るさを返す。基準の明るさの 55〜100% の間で瞬く。
fn twinkle(star : SpaceStar, t : Double) -> Double {
  star.alpha * (0.775 + 0.225 * @math.sin(t * star.speed + star.phase))
}

///|
/// 画面全体の背景として、宇宙空間（地の色、星雲、時刻 `t` 秒の瞬く星）を描く。
/// `ctx` の座標は CSS ピクセルで、幅 `width`、高さ `height` になっている前提。
pub fn draw_backdrop(
  ctx : @ffi.Context2d,
  width : Double,
  height : Double,
  t : Double,
) -> Unit {
  ctx.set_fill_color(BACKGROUND)
  ctx.fill_rect(0.0, 0.0, width, height)
  for nebula in nebulae {
    let x = nebula.x * width
    let y = nebula.y * height
    let radius = nebula.radius * width
    let glow = ctx.create_radial_gradient(x, y, 0.0, x, y, radius)
    glow.add_color_stop(0.0, nebula.color)
    glow.add_color_stop(1.0, "rgba(0,0,0,0)")
    ctx.set_fill_gradient(glow)
    ctx.fill_rect(0.0, 0.0, width, height)
  }
  let count = space_star_count(width, height)
  for star in space_stars[:count] {
    ctx.set_global_alpha(twinkle(star, t))
    ctx.set_fill_color(star.color)
    fill_circle(ctx, star.x * width, star.y * height, star.radius)
  }
  ctx.set_global_alpha(1.0)
}
