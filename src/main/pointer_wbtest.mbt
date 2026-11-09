///|
let pointer_size : @layout.Canvas = { width: 640.0, height: 400.0, }

///|
let pointer_systems : Array[@layout.System] = [
  {
    language: "Rust",
    color: "#dea584",
    x: 100.0,
    y: 100.0,
    star_radius: 10.0,
    orbit_step: 3.0,
    tilt: 0.0,
    extent: 60.0,
  },
]

///|
/// 2020 年と 2024 年の惑星。`t = 0` で恒星の右に並ぶ。
let pointer_planets : Array[@orbit.Planet] = [
  {
    repo: repo("old", "Rust", 2020),
    system_index: 0,
    orbit_radius: 20.0,
    phase: 0.0,
    angular_speed: 1.0,
  },
  {
    repo: repo("new", "Rust", 2024),
    system_index: 0,
    orbit_radius: 40.0,
    phase: 0.0,
    angular_speed: 1.0,
  },
]

///|
fn target_of(pointer : Pointer, year~ : Int32 = 2026) -> @orbit.Hit? {
  pointer.target(0.0, year, pointer_planets, pointer_systems, pointer_size)
}

///|
test "マウスの座標で惑星と恒星を判定する" {
  assert_eq(target_of(Away), None)
  assert_eq(target_of(Hovering(120.0, 100.0)), Some(Planet(0)))
  assert_eq(target_of(Hovering(100.0, 100.0)), Some(Star(0)))
  assert_eq(target_of(Hovering(300.0, 300.0)), None)
}

///|
test "マウスの座標はまだ現れていない惑星に反応しない" {
  assert_eq(target_of(Hovering(140.0, 100.0), year=2023), None)
  assert_eq(target_of(Hovering(140.0, 100.0), year=2024), Some(Planet(1)))
}

///|
test "タップで選んだ惑星は年を戻すと対象から外れる" {
  assert_eq(target_of(Pinned(Planet(1)), year=2024), Some(Planet(1)))
  assert_eq(target_of(Pinned(Planet(1)), year=2023), None)
  assert_eq(target_of(Pinned(Star(0)), year=2000), Some(Star(0)))
}

///|
test "1回目のタップは選ぶだけで、同じ惑星の2回目で開く" {
  let (first, opened) = Away.tapped(Some(Planet(1)))
  assert_eq(first, Pinned(Planet(1)))
  assert_eq(opened, None)
  let (second, opened) = first.tapped(Some(Planet(1)))
  assert_eq(second, Pinned(Planet(1)))
  assert_eq(opened, Some(1))
}

///|
test "別の惑星のタップは選び直しで、開かない" {
  let (next, opened) = Pinned(Planet(0)).tapped(Some(Planet(1)))
  assert_eq(next, Pinned(Planet(1)))
  assert_eq(opened, None)
}

///|
test "恒星は何度タップしても開かない" {
  let (next, opened) = Pinned(Star(0)).tapped(Some(Star(0)))
  assert_eq(next, Pinned(Star(0)))
  assert_eq(opened, None)
}

///|
test "何もない場所のタップで選択を解除する" {
  let (next, opened) = Pinned(Planet(0)).tapped(None)
  assert_eq(next, Away)
  assert_eq(opened, None)
}
