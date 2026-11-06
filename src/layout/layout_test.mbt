///|
fn stat(name : String, count : Int32) -> @domain.LanguageStat {
  { name, color: "#cccccc", count, }
}

///|
/// f-a24 の実データの集計結果。
fn f_a24_stats() -> Array[@domain.LanguageStat] {
  [
    stat("TypeScript", 27),
    stat("JavaScript", 7),
    stat("Jupyter Notebook", 6),
    stat("Haskell", 2),
    stat("Rust", 2),
    stat("CSS", 1),
    stat("Elm", 1),
    stat("GLSL", 1),
    stat("Kotlin", 1),
    stat("Python", 1),
    stat("Svelte", 1),
    stat("Swift", 1),
  ]
}

///|
/// 件数が 1 の言語だけを `n` 個並べる。
fn single_repo_stats(n : Int32) -> Array[@domain.LanguageStat] {
  Array::makei(n, i => stat("Language\{i}", 1))
}

///|
/// 件数が順位に反比例する（よくある分布の）言語を 25 個並べる。
fn zipf_stats(top_count : Int32) -> Array[@domain.LanguageStat] {
  Array::makei(25, i => {
    stat("Language\{i}", @cmp.maximum(1, top_count / (i + 1)))
  })
}

///|
/// 16:10 のキャンバスを幅から作る。
fn canvas_of(width : Double) -> @layout.Canvas {
  { width, height: width * 10.0 / 16.0, }
}

///|
/// 恒星と言語名がキャンバス内（予約領域を除く）に収まることを確かめる。
fn assert_inside(
  systems : Array[@layout.System],
  canvas : @layout.Canvas,
) -> Unit raise {
  let s = canvas.scale()
  let top = 34.0 * s
  let bottom = canvas.height - 46.0 * s
  for system in systems {
    let half_label = system.label_width(canvas) / 2.0
    let half_width = @cmp.maximum(system.star_radius, half_label)
    assert_true(
      system.x - half_width >= 0.0,
      msg="\{system.language} が左にはみ出す",
    )
    assert_true(
      system.x + half_width <= canvas.width,
      msg="\{system.language} が右にはみ出す",
    )
    assert_true(
      system.y - system.star_radius >= top,
      msg="\{system.language} が上にはみ出す",
    )
    assert_true(
      // 範囲の下端に置かれたときの丸め誤差を許容する
      system.label_baseline(canvas) + 3.0 * s <= bottom + 1.0e-9,
      msg="\{system.language} の言語名が下にはみ出す",
    )
  }
}

///|
/// 惑星系の外縁どうしが重ならないことを確かめる。
fn assert_no_overlap(systems : Array[@layout.System]) -> Unit raise {
  for i, a in systems {
    for b in systems[i + 1:] {
      let distance = @math.hypot(a.x - b.x, (a.y - b.y) / @layout.ORBIT_ASPECT)
      assert_true(
        distance >= a.extent + b.extent,
        msg="\{a.language} と \{b.language} が重なる",
      )
    }
  }
}

///|
/// 代表的な画面幅とシードで、配置の性質がすべて成り立つことを確かめる。
fn assert_valid_layout(stats : Array[@domain.LanguageStat]) -> Unit raise {
  for width in [375.0, 640.0, 1280.0] {
    let canvas = canvas_of(width)
    for seed in 0..<20 {
      let systems = @layout.layout(stats, canvas, seed)
      assert_eq(
        systems.map(system => system.language),
        stats.map(stat => stat.name),
      )
      assert_no_overlap(systems)
      assert_inside(systems, canvas)
      assert_true(systems.iter().all(system => system.tilt.abs() <= 0.35))
    }
  }
}

///|
test "mulberry32 が JavaScript の参照実装と同じ列を返す" {
  let random = @layout.Random::new(42)
  assert_eq(random.next_double(), 0.6011037519201636)
  assert_eq(random.next_double(), 0.44829055899754167)
  assert_eq(random.next_double(), 0.8524657934904099)
  let negative = @layout.Random::new(-7)
  assert_eq(negative.next_double(), 0.43306733411736786)
  assert_eq(negative.next_double(), 0.32539576734416187)
  assert_eq(negative.next_double(), 0.5442695003002882)
}

///|
test "恒星の半径と軌道の間隔が仕様の式に従う" {
  let systems = @layout.layout(
    [stat("Many", 100), stat("Some", 27), stat("One", 1)],
    canvas_of(640.0),
    1,
  )
  assert_true((systems[0].star_radius - 29.0).abs() < 1.0e-9)
  assert_true((systems[0].orbit_step - 1.3).abs() < 1.0e-9)
  assert_true(
    (systems[0].extent - (29.0 + 7.0 + 99.0 * 1.3 + 8.0)).abs() < 1.0e-9,
  )
  assert_true((systems[1].orbit_step - 3.1).abs() < 1.0e-9)
  assert_true((systems[2].orbit_step - 3.1).abs() < 1.0e-9)
  assert_true((systems[2].extent - (5.6 + 7.0 + 8.0)).abs() < 1.0e-9)
}

///|
test "長さがキャンバスの幅に比例する" {
  let stats = f_a24_stats()
  let small = @layout.layout(stats, canvas_of(320.0), 1)
  let large = @layout.layout(stats, canvas_of(640.0), 1)
  for i, system in large {
    assert_true(
      (system.star_radius - small[i].star_radius * 2.0).abs() < 1.0e-9,
    )
    assert_true((system.extent - small[i].extent * 2.0).abs() < 1.0e-9)
    assert_true((system.x - small[i].x * 2.0).abs() < 1.0e-9)
    assert_true((system.y - small[i].y * 2.0).abs() < 1.0e-9)
  }
}

///|
test "同じ入力と同じシードなら同じ配置になる" {
  let canvas = canvas_of(640.0)
  let stats = zipf_stats(60)
  assert_eq(@layout.layout(stats, canvas, 7), @layout.layout(stats, canvas, 7))
}

///|
test "シードが変わると傾きが変わる" {
  let canvas = canvas_of(640.0)
  let stats = f_a24_stats()
  assert_true(
    @layout.layout(stats, canvas, 1)[0].tilt !=
    @layout.layout(stats, canvas, 2)[0].tilt,
  )
}

///|
test "言語がなければ空の配置を返す" {
  assert_eq(@layout.layout([], canvas_of(640.0), 1), [])
}

///|
test "f-a24 の実データを配置できる" {
  assert_valid_layout(f_a24_stats())
}

///|
test "言語が 1 個でも配置できる" {
  assert_valid_layout([stat("TypeScript", 27)])
  assert_valid_layout([stat("Jupyter Notebook", 1)])
}

///|
test "件数が 1 の言語が 20 個でも配置できる" {
  assert_valid_layout(single_repo_stats(20))
}

///|
test "言語が 25 個でも配置できる" {
  assert_valid_layout(single_repo_stats(25))
  assert_valid_layout(zipf_stats(30))
  assert_valid_layout(zipf_stats(60))
  assert_valid_layout(zipf_stats(80))
}

///|
test "惑星系の面積がキャンバスを超えても恒星と言語名は収まる" {
  let canvas = canvas_of(640.0)
  assert_inside(@layout.layout(zipf_stats(200), canvas, 1), canvas)
}

///|
test "1 言語に 500 件あっても恒星と言語名はキャンバスに収まる" {
  let canvas = canvas_of(640.0)
  assert_inside(@layout.layout([stat("TypeScript", 500)], canvas, 1), canvas)
  let stats = [stat("TypeScript", 500), ..single_repo_stats(11)]
  assert_inside(@layout.layout(stats, canvas, 1), canvas)
}
