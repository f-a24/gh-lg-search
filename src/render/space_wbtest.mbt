///|
test "starfield は同じシードなら同じ星空を作る" {
  let a = starfield(7, 50)
  let b = starfield(7, 50)
  assert_eq(a.length(), 50)
  for i, star in a {
    assert_eq(star.x, b[i].x)
    assert_eq(star.y, b[i].y)
    assert_eq(star.radius, b[i].radius)
  }
  assert_true(starfield(8, 1)[0].x != a[0].x)
}

///|
test "starfield の星はキャンバスの内側にあり、大きさと明るさが範囲に収まる" {
  for star in starfield(SPACE_SEED, SPACE_STAR_LIMIT) {
    assert_true(star.x >= 0.0 && star.x < 1.0)
    assert_true(star.y >= 0.0 && star.y < 1.0)
    assert_true(star.radius >= 0.35 && star.radius <= 1.5)
    assert_true(star.alpha >= 0.25 && star.alpha <= 0.85)
  }
}

///|
test "space_star_count は面積に比例し、上限を超えない" {
  inspect(space_star_count(375.0, 234.0), content="36")
  inspect(space_star_count(640.0, 400.0), content="106")
  inspect(space_star_count(2560.0, 1600.0), content="420")
}

///|
test "twinkle は基準の明るさの 55〜100% に収まり、時刻で変わる" {
  let star = starfield(SPACE_SEED, 1)[0]
  for i in 0..<100 {
    let alpha = twinkle(star, i.to_double() * 0.37)
    assert_true(alpha >= star.alpha * 0.55 - 1.0e-9)
    assert_true(alpha <= star.alpha + 1.0e-9)
  }
  assert_true(twinkle(star, 0.0) != twinkle(star, 1.0))
}
