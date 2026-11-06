///|
/// `orbit_radius / s = 1` の軌道の角速度（ラジアン/秒）。
/// プロトタイプの `60fps × 0.02 × 0.9 [rad/frame]` を秒に直した値。
const BASE_ANGULAR_SPEED : Double = 1.08

///|
/// 惑星の当たり判定の半径。`s` 倍して使う。
const PLANET_HIT_RADIUS : Double = 9.0

///|
/// 恒星の当たり判定の半径。恒星の半径に対する倍率。
const STAR_HIT_SCALE : Double = 1.3

///|
/// 年の再生で、最後の年にも他の年とほぼ同じ長さを割り当てるための余り。
const LAST_YEAR_SHARE : Double = 0.99

///|
/// リポジトリ1つに対応する惑星。`system_index` は惑星系の配列の添字。
#derive(Debug, Eq)
pub(all) struct Planet {
  repo : @domain.Repo
  system_index : Int32
  orbit_radius : Double
  phase : Double
  angular_speed : Double
}

///|
/// 当たり判定の結果。添字は惑星または惑星系の配列のもの。
#derive(Debug, Eq)
pub(all) enum Hit {
  Planet(Int32)
  Star(Int32)
}

///|
pub extend Planet with @debug.Debug::{to_repr}

///|
pub extend Planet with Eq::{equal, not_equal}

///|
pub extend Hit with @debug.Debug::{to_repr}

///|
pub extend Hit with Eq::{equal, not_equal}

///|
/// 軌道の半径から角速度（ラジアン/秒）を返す。外側ほど遅い。
fn angular_speed(orbit_radius : Double, s : Double) -> Double {
  BASE_ANGULAR_SPEED / (orbit_radius / s).sqrt()
}

///|
/// リポジトリを作成年の昇順に並べる。同じ年なら名前（大文字小文字を区別しない）の昇順。
fn sort_by_age(repos : Array[@domain.Repo]) -> Array[@domain.Repo] {
  let names = repos.map(repo => repo.name.to_lower())
  let order = Array::makei(repos.length(), i => i)
  // `sort_by` は安定ソートではないので、最後は元の順序で固定する
  order.sort_by((a, b) => {
    let by_year = repos[a].created_year - repos[b].created_year
    if by_year != 0 {
      return by_year
    }
    let by_name = @domain.compare_names(names[a], names[b])
    if by_name != 0 {
      by_name
    } else {
      a - b
    }
  })
  order.map(i => repos[i])
}

///|
/// リポジトリから惑星を作る。戻り値は作成年の昇順に並ぶ。
///
/// 言語ごとに古いリポジトリから順に内側の軌道へ割り当てる。
/// `systems` にない言語のリポジトリは惑星にしない。同じ入力なら同じ結果になる。
pub fn planets(
  repos : Array[@domain.Repo],
  systems : Array[@layout.System],
  canvas : @layout.Canvas,
  seed : Int32,
) -> Array[Planet] {
  let s = canvas.scale()
  // 傾きの乱数列と重ならないように、`layout` とは別のシードにする
  let random = @layout.Random::new(seed + 1)
  let system_indices : Map[String, Int32] = Map([])
  for index, system in systems {
    system_indices[system.language] = index
  }
  let used = Array::make(systems.length(), 0)
  let result = []
  for repo in sort_by_age(repos) {
    guard system_indices.get(repo.language) is Some(system_index) else {
      continue
    }
    let orbit_radius = systems[system_index].orbit_radius(
      used[system_index],
      canvas,
    )
    used[system_index] += 1
    result.push({
      repo,
      system_index,
      orbit_radius,
      phase: random.next_double() * 2.0 * @math.PI,
      angular_speed: angular_speed(orbit_radius, s),
    })
  }
  result
}

///|
/// 時刻 `t`（秒）での惑星の位置を返す。
///
/// 楕円上の点を恒星の傾きで回転し、恒星の中心へ平行移動する。
pub fn position(
  planet : Planet,
  systems : Array[@layout.System],
  t : Double,
) -> (Double, Double) {
  let system = systems[planet.system_index]
  let angle = planet.phase + t * planet.angular_speed
  let local_x = @math.cos(angle) * planet.orbit_radius
  let local_y = @math.sin(angle) * planet.orbit_radius * @layout.ORBIT_ASPECT
  let cos_tilt = @math.cos(system.tilt)
  let sin_tilt = @math.sin(system.tilt)
  (
    system.x + local_x * cos_tilt - local_y * sin_tilt,
    system.y + local_x * sin_tilt + local_y * cos_tilt,
  )
}

///|
/// `year` までに作成されたリポジトリの惑星の添字を返す。
pub fn visible_until(year : Int32, planets : Array[Planet]) -> Array[Int32] {
  let visible = []
  for index, planet in planets {
    if planet.repo.created_year <= year {
      visible.push(index)
    }
  }
  visible
}

///|
/// 再生の進捗（0〜1）から表示する年を返す。範囲外の進捗は 0〜1 に丸める。
///
/// ```mbt check
/// test {
///   inspect(@orbit.year_at(0.0, 2017, 2026), content="2017")
///   inspect(@orbit.year_at(0.5, 2017, 2026), content="2021")
///   inspect(@orbit.year_at(1.0, 2017, 2026), content="2026")
/// }
/// ```
pub fn year_at(
  progress : Double,
  first_year : Int32,
  last_year : Int32,
) -> Int32 {
  let clamped = @cmp.maximum(0.0, @cmp.minimum(1.0, progress))
  let span = (last_year - first_year).to_double() + LAST_YEAR_SHARE
  @cmp.minimum(last_year, first_year + (clamped * span).floor().to_int())
}

///|
/// 座標 `(x, y)` にある惑星または恒星を返す。何もなければ `None`。
///
/// 惑星を優先し、`visible_year` までに作成された惑星のうち最も近いものを選ぶ。
pub fn hit_test(
  x : Double,
  y : Double,
  t : Double,
  planets : Array[Planet],
  systems : Array[@layout.System],
  canvas : @layout.Canvas,
  visible_year : Int32,
) -> Hit? {
  let mut nearest = None
  let mut nearest_distance = PLANET_HIT_RADIUS * canvas.scale()
  for index in visible_until(visible_year, planets) {
    let (planet_x, planet_y) = position(planets[index], systems, t)
    let distance = @math.hypot(planet_x - x, planet_y - y)
    if distance < nearest_distance {
      nearest_distance = distance
      nearest = Some(Hit::Planet(index))
    }
  }
  if nearest is Some(_) {
    return nearest
  }
  for index, system in systems {
    let distance = @math.hypot(system.x - x, system.y - y)
    if distance < system.star_radius * STAR_HIT_SCALE {
      return Some(Hit::Star(index))
    }
  }
  None
}
