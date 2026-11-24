///|
fn tip_planet(name : String, language : String, index : Int32) -> @orbit.Planet {
  {
    repo: {
      name,
      url: "https://github.com/a/\{name}",
      language,
      created_year: 2021,
    },
    system_index: index,
    orbit_radius: 20.0,
    phase: 0.0,
    angular_speed: 1.0,
  }
}

///|
fn tip_system(language : String) -> @layout.System {
  {
    language,
    color: "#dea584",
    x: 100.0,
    y: 100.0,
    star_radius: 10.0,
    orbit_step: 3.0,
    tilt: 0.0,
    extent: 60.0,
  }
}

///|
test "tooltip_text は惑星のリポジトリ名・言語・作成年を並べる" {
  let planets = [tip_planet("rabbit", "Rust", 0)]
  inspect(
    tooltip_text(Planet(0), planets, [tip_system("Rust")]),
    content="rabbit · Rust · 2021",
  )
}

///|
test "tooltip_text は恒星の件数と全体に対する割合を出す" {
  let planets = [
    tip_planet("a", "Rust", 0),
    tip_planet("b", "Rust", 0),
    tip_planet("c", "Elm", 1),
  ]
  let systems = [tip_system("Rust"), tip_system("Elm")]
  inspect(
    tooltip_text(Star(0), planets, systems),
    content="Rust · 2 repos（66.7%）",
  )
  inspect(
    tooltip_text(Star(1), planets, systems),
    content="Elm · 1 repos（33.3%）",
  )
}

///|
test "fit_text は収まる文字列をそのまま返す" {
  let measure = (text : String) => text.length().to_double()
  inspect(fit_text("abcd", 4.0, measure), content="abcd")
}

///|
test "fit_text は収まらない文字列の末尾を削る" {
  let measure = (text : String) => text.length().to_double()
  inspect(fit_text("abcdefg", 4.0, measure), content="abc…")
  inspect(fit_text("abcdefg", 0.5, measure), content="…")
}

///|
test "tip_box は対象の右上に置く" {
  let tip = tip_box(100.0, 100.0, 50.0, 640.0, 1.0)
  assert_eq((tip.x, tip.y), (112.0, 64.0))
  assert_eq((tip.width, tip.height), (66.0, 26.0))
}

///|
test "tip_box は右端からはみ出さない" {
  let tip = tip_box(630.0, 100.0, 50.0, 640.0, 1.0)
  assert_eq(tip.x + tip.width, 636.0)
}

///|
test "tip_box は左端からはみ出さない" {
  assert_eq(tip_box(0.0, 100.0, 700.0, 640.0, 1.0).x, 4.0)
}

///|
test "tip_box は上に場所がなければ対象の下に置く" {
  assert_eq(tip_box(100.0, 20.0, 50.0, 640.0, 1.0).y, 34.0)
}
