///|
/// fixture の JSON を集計の対象になるリポジトリの配列にする。
fn fixture_repos() -> Array[@domain.Repo] raise {
  guard @json.parse(f_a24_repos_json) is Array(items) else {
    fail("fixture の最上位が配列ではない")
  }
  let raw : Array[@domain.RawRepo] = items.map(item => {
    guard item
      is {
        "name": String(name),
        "html_url": String(url),
        "language": language,
        "fork": fork,
        "created_at": String(created_at),
        ..
      } else {
      fail("fixture の項目の形が想定と違う")
    }
    guard @domain.parse_created_year(created_at) is Some(created_year) else {
      fail("created_at を解釈できない: \{created_at}")
    }
    let language = if language is String(language) {
      Some(language)
    } else {
      None
    }
    { name, url, language, fork: fork is True, created_year, }
  })
  @domain.filter_countable(raw)
}

///|
fn canvas() -> @layout.Canvas {
  { width: 640.0, height: 400.0, }
}

///|
fn repo(name : String, language : String, year : Int32) -> @domain.Repo {
  { name, url: "https://github.com/x/\{name}", language, created_year: year, }
}

///|
/// 傾きのない惑星系を、指定の位置に1つ作る。
fn system(
  language : String,
  x : Double,
  y : Double,
  star_radius : Double,
) -> @layout.System {
  {
    language,
    color: "#cccccc",
    x,
    y,
    star_radius,
    orbit_step: 3.0,
    tilt: 0.0,
    extent: 100.0,
  }
}

///|
/// `t = 0` に恒星の右側 `orbit_radius` の位置へ来る惑星を作る。
fn planet(
  name : String,
  year : Int32,
  system_index : Int32,
  orbit_radius : Double,
) -> @orbit.Planet {
  {
    repo: repo(name, "Rust", year),
    system_index,
    orbit_radius,
    phase: 0.0,
    angular_speed: 1.0,
  }
}

///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true(
    (actual - expected).abs() < 1.0e-6,
    msg="\{actual} と \{expected} が一致しない",
  )
}

///|
/// f-a24 の実データから惑星系と惑星を作る。
fn f_a24() -> (Array[@layout.System], Array[@orbit.Planet]) raise {
  let repos = fixture_repos()
  let systems = @layout.layout(@domain.aggregate(repos), canvas(), 7)
  (systems, @orbit.planets(repos, systems, canvas(), 7))
}

///|
test "f-a24 のすべてのリポジトリが惑星になる" {
  let (systems, planets) = f_a24()
  assert_eq(planets.length(), 51)
  for planet in planets {
    assert_eq(systems[planet.system_index].language, planet.repo.language)
  }
}

///|
test "同じ言語の惑星は作成年が古いほど内側の軌道を回る" {
  let (_, planets) = f_a24()
  for a in planets {
    for b in planets {
      if a.system_index == b.system_index &&
        a.repo.created_year < b.repo.created_year {
        assert_true(a.orbit_radius < b.orbit_radius)
      }
    }
  }
}

///|
test "軌道は恒星の外側で、惑星系の外縁より内側にある" {
  let (systems, planets) = f_a24()
  for planet in planets {
    let system = systems[planet.system_index]
    assert_true(planet.orbit_radius > system.star_radius)
    assert_true(planet.orbit_radius < system.extent)
  }
}

///|
test "同じ年のリポジトリは大文字小文字を区別せず名前順に内側から並ぶ" {
  let repos = [repo("beta", "Rust", 2020), repo("Alpha", "Rust", 2020)]
  let systems = [system("Rust", 100.0, 100.0, 10.0)]
  let planets = @orbit.planets(repos, systems, canvas(), 1)
  assert_eq(planets.map(planet => planet.repo.name), ["Alpha", "beta"])
  assert_close(planets[0].orbit_radius, 17.0)
  assert_close(planets[1].orbit_radius, 20.0)
}

///|
test "惑星系にない言語のリポジトリは惑星にしない" {
  let repos = [repo("a", "Rust", 2020), repo("b", "Elm", 2020)]
  let systems = [system("Rust", 100.0, 100.0, 10.0)]
  let planets = @orbit.planets(repos, systems, canvas(), 1)
  assert_eq(planets.map(planet => planet.repo.name), ["a"])
}

///|
test "外側の軌道ほど角速度が遅い" {
  let (_, planets) = f_a24()
  for a in planets {
    for b in planets {
      if a.orbit_radius < b.orbit_radius {
        assert_true(a.angular_speed > b.angular_speed)
      }
    }
  }
}

///|
test "同じシードなら同じ惑星になり、違うシードなら初期位相が変わる" {
  let repos = fixture_repos()
  let systems = @layout.layout(@domain.aggregate(repos), canvas(), 7)
  let first = @orbit.planets(repos, systems, canvas(), 7)
  assert_eq(first, @orbit.planets(repos, systems, canvas(), 7))
  let other = @orbit.planets(repos, systems, canvas(), 8)
  assert_true(first.map(p => p.phase) != other.map(p => p.phase))
}

///|
test "position は t に対して周期的" {
  let (systems, planets) = f_a24()
  for planet in planets {
    let period = 2.0 * @math.PI / planet.angular_speed
    for t in [0.0, 1.5, 42.0] {
      let (x0, y0) = @orbit.position(planet, systems, t)
      let (x1, y1) = @orbit.position(planet, systems, t + period)
      assert_close(x0, x1)
      assert_close(y0, y1)
    }
  }
}

///|
test "position は傾いた楕円の上にある" {
  let (systems, planets) = f_a24()
  for planet in planets {
    let system = systems[planet.system_index]
    for step in 0..<40 {
      let (x, y) = @orbit.position(planet, systems, step.to_double() * 0.7)
      let dx = x - system.x
      let dy = y - system.y
      // 恒星の傾きを戻して、楕円の軸に揃える
      let u = dx * @math.cos(system.tilt) + dy * @math.sin(system.tilt)
      let v = dy * @math.cos(system.tilt) - dx * @math.sin(system.tilt)
      let major = u / planet.orbit_radius
      let minor = v / (planet.orbit_radius * @layout.ORBIT_ASPECT)
      assert_close(major * major + minor * minor, 1.0)
    }
  }
}

///|
test "f-a24 の 2019 年時点の表示件数は 25 件" {
  let (_, planets) = f_a24()
  assert_eq(@orbit.visible_until(2019, planets).length(), 25)
  assert_eq(@orbit.visible_until(2016, planets).length(), 0)
  assert_eq(@orbit.visible_until(2026, planets).length(), 51)
}

///|
test "visible_until は惑星の配列の添字を返す" {
  let planets = [
    planet("a", 2018, 0, 20.0),
    planet("b", 2021, 0, 23.0),
    planet("c", 2019, 0, 26.0),
  ]
  assert_eq(@orbit.visible_until(2019, planets), [0, 2])
}

///|
test "year_at は最初の年から最後の年まで順に進む" {
  assert_eq(@orbit.year_at(0.0, 2017, 2026), 2017)
  assert_eq(@orbit.year_at(1.0, 2017, 2026), 2026)
  assert_eq(@orbit.year_at(-1.0, 2017, 2026), 2017)
  assert_eq(@orbit.year_at(2.0, 2017, 2026), 2026)
  assert_eq(@orbit.year_at(0.5, 2020, 2020), 2020)
  let years = Array::makei(101, i => {
    @orbit.year_at(i.to_double() / 100.0, 2017, 2026)
  })
  for i in 1..<years.length() {
    assert_true((years[i] - years[i - 1]) is (0 | 1))
  }
}

///|
test "hit_test は最も近い惑星を返す" {
  let systems = [system("Rust", 100.0, 100.0, 10.0)]
  let planets = [planet("a", 2020, 0, 20.0), planet("b", 2020, 0, 26.0)]
  let hit = (x : Double) => {
    @orbit.hit_test(x, 100.0, 0.0, planets, systems, canvas(), 2020)
  }
  assert_eq(hit(121.0), Some(@orbit.Hit::Planet(0)))
  assert_eq(hit(125.0), Some(@orbit.Hit::Planet(1)))
}

///|
test "hit_test は判定の半径の外にある惑星を返さない" {
  let systems = [system("Rust", 100.0, 100.0, 10.0)]
  let planets = [planet("a", 2020, 0, 40.0)]
  let hit = (x : Double) => {
    @orbit.hit_test(x, 100.0, 0.0, planets, systems, canvas(), 2020)
  }
  assert_eq(hit(148.9), Some(@orbit.Hit::Planet(0)))
  assert_eq(hit(149.0), None)
}

///|
test "hit_test は時刻 t の位置で判定する" {
  let systems = [system("Rust", 100.0, 100.0, 10.0)]
  let planets = [planet("a", 2020, 0, 40.0)]
  // 半周すると恒星の左側に来る
  let t = @math.PI
  let hit = (x : Double) => {
    @orbit.hit_test(x, 100.0, t, planets, systems, canvas(), 2020)
  }
  assert_eq(hit(60.0), Some(@orbit.Hit::Planet(0)))
  assert_eq(hit(140.0), None)
}

///|
test "hit_test はまだ現れていない惑星を無視する" {
  let systems = [system("Rust", 100.0, 100.0, 10.0)]
  let planets = [planet("a", 2021, 0, 40.0)]
  let hit = (year : Int32) => {
    @orbit.hit_test(140.0, 100.0, 0.0, planets, systems, canvas(), year)
  }
  assert_eq(hit(2020), None)
  assert_eq(hit(2021), Some(@orbit.Hit::Planet(0)))
}

///|
test "hit_test は恒星の半径の 1.3 倍以内を恒星と判定する" {
  let systems = [
    system("Rust", 100.0, 100.0, 10.0),
    system("Elm", 300.0, 100.0, 20.0),
  ]
  let hit = (x : Double) => {
    @orbit.hit_test(x, 100.0, 0.0, [], systems, canvas(), 2020)
  }
  assert_eq(hit(100.0), Some(@orbit.Hit::Star(0)))
  assert_eq(hit(112.9), Some(@orbit.Hit::Star(0)))
  assert_eq(hit(113.0), None)
  assert_eq(hit(325.0), Some(@orbit.Hit::Star(1)))
}

///|
test "hit_test は恒星より惑星を優先する" {
  let systems = [system("Rust", 100.0, 100.0, 10.0)]
  let planets = [planet("a", 2020, 0, 12.0)]
  assert_eq(
    @orbit.hit_test(111.0, 100.0, 0.0, planets, systems, canvas(), 2020),
    Some(@orbit.Hit::Planet(0)),
  )
}

///|
test "hit_test は何もない場所で None を返す" {
  let (systems, planets) = f_a24()
  assert_eq(
    @orbit.hit_test(-100.0, -100.0, 0.0, planets, systems, canvas(), 2026),
    None,
  )
}
