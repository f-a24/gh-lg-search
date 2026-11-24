///|
/// 軌道の楕円の縦横比。
pub const ORBIT_ASPECT : Double = 0.45

///|
/// `s = 1` になるキャンバス幅。すべての長さはこの幅を基準に拡大縮小する。
const BASE_WIDTH : Double = 640.0

///|
/// 上端の予約領域の高さ（件数表示の領域）。`s` 倍して使う。
const TOP_RESERVED : Double = 34.0

///|
/// 下端の予約領域の高さ。`s` 倍して使う。
const BOTTOM_RESERVED : Double = 12.0

///|
/// 言語名の文字の大きさ。`s` 倍して使う。
const LABEL_FONT_SIZE : Double = 9.0

///|
/// 等幅フォントの1文字の幅（文字の大きさに対する比）。
const LABEL_CHAR_RATIO : Double = 0.6

///|
/// 恒星の表面から最も内側の軌道までの距離。`s` 倍して使う。
const FIRST_ORBIT_GAP : Double = 7.0

///|
/// 最も外側の軌道から惑星系の外縁までの距離。`s` 倍して使う。
const EDGE_MARGIN : Double = 8.0

///|
/// 軌道の間隔の下限。`s` 倍して使う。
const MIN_ORBIT_STEP : Double = 1.3

///|
/// 軌道の間隔の上限。`s` 倍して使う。
const MAX_ORBIT_STEP : Double = 3.1

///|
/// 傾きの幅。`-0.35〜0.35` ラジアンの範囲になる。
const TILT_RANGE : Double = 0.7

///|
/// これ以上離れていれば、隙間をさらに広げても評価を上げない距離。`s` 倍して使う。
const PREFERRED_CLEARANCE : Double = 34.0

///|
/// 重なる候補が、重ならない候補より必ず低い評価になるように引く値。
const OVERLAP_PENALTY : Double = 1.0e9

///|
/// 配置の候補にする格子の横方向の分割数。
const GRID_COLUMNS : Int32 = 36

///|
/// 配置の候補にする格子の縦方向の分割数。
const GRID_ROWS : Int32 = 24

///|
/// 惑星系を描くキャンバスの大きさ。
#derive(Debug, Eq)
pub(all) struct Canvas {
  width : Double
  height : Double
  /// 惑星系全体の拡大率。`fit_zoom` で決める
  zoom : Double
}

///|
/// 1つの言語の惑星系。`x` と `y` は恒星の中心の座標。
#derive(Debug, Eq)
pub(all) struct System {
  language : String
  color : String
  x : Double
  y : Double
  star_radius : Double
  orbit_step : Double
  tilt : Double
  extent : Double
}

///|
pub extend Canvas with @debug.Debug::{to_repr}

///|
pub extend Canvas with Eq::{equal, not_equal}

///|
pub extend System with @debug.Debug::{to_repr}

///|
pub extend System with Eq::{equal, not_equal}

///|
/// 長さの倍率 `s` を返す。
///
/// ```mbt check
/// test {
///   let canvas : @layout.Canvas = { width: 320.0, height: 200.0, zoom: 1.0, }
///   inspect(canvas.scale(), content="0.5")
/// }
/// ```
pub fn Canvas::scale(self : Canvas) -> Double {
  self.width / BASE_WIDTH * self.zoom
}

///|
/// 言語名の文字の大きさ（px）を返す。
///
/// ```mbt check
/// test {
///   let canvas : @layout.Canvas = { width: 1280.0, height: 800.0, zoom: 1.0, }
///   inspect(canvas.label_font_size(), content="18")
/// }
/// ```
pub fn Canvas::label_font_size(self : Canvas) -> Double {
  LABEL_FONT_SIZE * self.scale()
}

///|
/// 言語名を描いたときの幅の見積もりを返す。言語名は恒星の中心に重ねて描く。
///
/// 配置は純粋関数なので Canvas の `measureText` を使わず、等幅フォントの字幅から計算する。
pub fn System::label_width(self : System, canvas : Canvas) -> Double {
  self.language.length().to_double() *
  LABEL_CHAR_RATIO *
  canvas.label_font_size()
}

///|
/// 恒星の中心から、恒星と言語名の上端（下端）までの距離を返す。
pub fn System::half_height(self : System, canvas : Canvas) -> Double {
  @cmp.maximum(self.star_radius, canvas.label_font_size() / 2.0)
}

///|
/// 内側から `index` 番目（0 始まり）の軌道の半径を返す。
pub fn System::orbit_radius(
  self : System,
  index : Int32,
  canvas : Canvas,
) -> Double {
  self.star_radius +
  FIRST_ORBIT_GAP * canvas.scale() +
  index.to_double() * self.orbit_step
}

///|
/// 位置が決まる前の惑星系を作る。
fn new_system(
  stat : @domain.LanguageStat,
  canvas : Canvas,
  tilt : Double,
) -> System {
  let s = canvas.scale()
  let star_radius = (3.0 + stat.count.to_double().sqrt() * 2.6) * s
  let gaps = @cmp.maximum(1, stat.count - 1).to_double()
  // 件数が多い言語は軌道の間隔を詰めて、惑星系がキャンバスの 35% を超えないようにする。
  // 縮小しているときは、この上限も同じ割合で縮める
  let room = @cmp.minimum(canvas.width, canvas.height) *
    0.35 *
    @cmp.minimum(1.0, canvas.zoom) -
    star_radius -
    FIRST_ORBIT_GAP * s
  let orbit_step = @cmp.minimum(
    MAX_ORBIT_STEP * s,
    @cmp.maximum(MIN_ORBIT_STEP * s, room / gaps),
  )
  let outermost = star_radius +
    FIRST_ORBIT_GAP * s +
    (stat.count - 1).to_double() * orbit_step
  {
    language: stat.name,
    color: stat.color,
    x: 0.0,
    y: 0.0,
    star_radius,
    orbit_step,
    tilt,
    extent: outermost + EDGE_MARGIN * s,
  }
}

///|
/// 候補の範囲を返す。範囲が成り立たないほど大きい惑星系は、中央の1点に固定する。
fn candidate_range(low : Double, high : Double) -> (Double, Double) {
  if low <= high {
    (low, high)
  } else {
    let middle = (low + high) / 2.0
    (middle, middle)
  }
}

///|
/// 配置済みの惑星系との隙間の最小値を返す。
/// 楕円は縦方向を `ORBIT_ASPECT` で割ると円になるので、その空間で距離を測る。
fn clearance(
  system : System,
  x : Double,
  y : Double,
  placed : Array[System],
) -> Double {
  placed.fold(init=@double.infinity, (nearest, other) => {
    let distance = @math.hypot(x - other.x, (y - other.y) / ORBIT_ASPECT)
    @cmp.minimum(nearest, distance - other.extent - system.extent)
  })
}

///|
/// 格子点の中から惑星系を置く位置を選ぶ。
///
/// 配置済みの惑星系に重ならない点を必ず優先し、その中では隙間が十分にあって中心に近い点を選ぶ。
/// 重ならない点がなければ、重なりが最も小さい点を選ぶ。
fn choose_position(
  system : System,
  canvas : Canvas,
  placed : Array[System],
) -> (Double, Double) {
  let s = canvas.scale()
  let half_width = @cmp.maximum(
    system.extent * 0.9,
    system.label_width(canvas) / 2.0 + EDGE_MARGIN * s,
  )
  let half_height = @cmp.maximum(
    system.extent * 0.5,
    system.half_height(canvas),
  )
  let (left, right) = candidate_range(half_width, canvas.width - half_width)
  let (top, bottom) = candidate_range(
    half_height + TOP_RESERVED * s,
    canvas.height - half_height - BOTTOM_RESERVED * s,
  )
  let mut best = (left, top)
  let mut best_score = -@double.infinity
  for row in 0..<=GRID_ROWS {
    for column in 0..<=GRID_COLUMNS {
      let x = left +
        (right - left) * column.to_double() / GRID_COLUMNS.to_double()
      let y = top + (bottom - top) * row.to_double() / GRID_ROWS.to_double()
      let clear = clearance(system, x, y, placed)
      let off_center = @math.hypot(
        x - canvas.width * 0.42,
        (y - canvas.height * 0.52) * 1.4,
      )
      let score = if clear >= 0.0 {
        @cmp.minimum(clear, PREFERRED_CLEARANCE * s) - 0.08 * off_center
      } else {
        clear - OVERLAP_PENALTY
      }
      if score > best_score {
        best_score = score
        best = (x, y)
      }
    }
  }
  best
}

///|
/// 言語の統計から惑星系の配置を計算する。戻り値は `stats` と同じ順に並ぶ。
///
/// 外縁の大きい順に、配置済みの惑星系と重ならない格子点へ置いていく。同じ入力なら同じ結果になる。
/// 惑星系が大きすぎて重ならない点がないときは、重なりが最小になる点に置く。
pub fn layout(
  stats : Array[@domain.LanguageStat],
  canvas : Canvas,
  seed : Int32,
) -> Array[System] {
  let random = Random::new(seed)
  let systems = stats.map(stat => {
    new_system(stat, canvas, (random.next_double() - 0.5) * TILT_RANGE)
  })
  let order = Array::makei(systems.length(), i => i)
  // `sort_by` は安定ソートではないので、同じ大きさなら元の順序で固定する
  order.sort_by((a, b) => {
    let by_extent = systems[b].extent.compare(systems[a].extent)
    if by_extent != 0 {
      by_extent
    } else {
      a - b
    }
  })
  let placed = []
  for index in order {
    let (x, y) = choose_position(systems[index], canvas, placed)
    systems[index] = { ..systems[index], x, y, }
    placed.push(systems[index])
  }
  systems
}

///|
/// 惑星系の外縁がキャンバスの中に収まっていれば `true`。
fn System::fits(self : System, canvas : Canvas) -> Bool {
  self.x - self.extent * 0.9 >= 0.0 &&
  self.x + self.extent * 0.9 <= canvas.width &&
  self.y - self.extent * 0.5 >= 0.0 &&
  self.y + self.extent * 0.5 <= canvas.height
}

///|
/// どの惑星系の外縁も重なっていなければ `true`。
fn no_overlap(systems : Array[System]) -> Bool {
  for i, a in systems {
    for b in systems[i + 1:] {
      let distance = @math.hypot(a.x - b.x, (a.y - b.y) / ORBIT_ASPECT)
      if distance < a.extent + b.extent {
        return false
      }
    }
  }
  true
}

///|
/// `fit_zoom` が試す拡大率。大きい順に 0.1 刻み。
let zoom_steps : FixedArray[Double] = [
  1.5, 1.4, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3,
]

///|
/// 惑星系が重ならず、キャンバスに収まる最大の拡大率を返す。
/// リポジトリが多くて 1 倍で収まらなければ縮小する。最小の 0.3 でも収まらなければ 0.3 を返す。
///
/// 言語が少ないほど大きく描ける。同じ入力なら同じ結果になる。
pub fn fit_zoom(
  stats : Array[@domain.LanguageStat],
  canvas : Canvas,
  seed : Int32,
) -> Double {
  for zoom in zoom_steps {
    let zoomed = { ..canvas, zoom, }
    let systems = layout(stats, zoomed, seed)
    if no_overlap(systems) && systems.iter().all(system => system.fits(zoomed)) {
      return zoom
    }
  }
  zoom_steps[zoom_steps.length() - 1]
}
