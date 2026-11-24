///|
test "再生は最初の年から約10秒で最後の年に着く" {
  let playback = @orbit.Playback::start(2017, 2026, 100.0)
  assert_true(playback.is_running())
  inspect(playback.time(100.0), content="0")
  inspect(playback.year(100.0), content="2017")
  inspect(playback.year(105.0), content="2021")
  inspect(playback.year(109.9), content="2026")
  inspect(playback.year(110.0), content="2026")
}

///|
test "再生が終わったあとも t は増え、最後の年のまま公転を続ける" {
  let playback = @orbit.Playback::start(2017, 2026, 0.0)
  inspect(playback.time(30.0), content="30")
  inspect(playback.year(30.0), content="2026")
}

///|
test "時計が少し戻っても t は負にならない" {
  let playback = @orbit.Playback::start(2017, 2026, 100.0)
  inspect(playback.time(99.99), content="0")
}

///|
test "一時停止すると t が止まり、再開すると続きから進む" {
  let paused = @orbit.Playback::start(2017, 2026, 0.0).pause(3.0)
  assert_false(paused.is_running())
  inspect(paused.time(50.0), content="3")
  let resumed = paused.play(50.0)
  assert_true(resumed.is_running())
  inspect(resumed.time(50.0), content="3")
  inspect(resumed.time(52.0), content="5")
}

///|
test "seek はどの範囲でも指定した年の始まりで止まる" {
  for range in [(2017, 2026), (2008, 2026), (2020, 2021), (2024, 2024)] {
    let (first_year, last_year) = range
    let playback = @orbit.Playback::start(first_year, last_year, 0.0)
    for year in first_year..<=last_year {
      let seeked = playback.seek(year, 4.0)
      assert_false(seeked.is_running())
      assert_eq(seeked.year(100.0), year)
      // 再開すれば次の年へ進む
      assert_eq(seeked.play(0.0).year(10.0), last_year)
    }
  }
}

///|
test "seek は範囲外の年を丸める" {
  let playback = @orbit.Playback::start(2017, 2026, 0.0)
  inspect(playback.seek(2000, 0.0).year(0.0), content="2017")
  inspect(playback.seek(2100, 0.0).year(0.0), content="2026")
}

///|
test "planet_scale は作成年の始まりから 0.5 秒で 0 から 1 になる" {
  let playback = @orbit.Playback::start(2017, 2026, 0.0)
  inspect(playback.planet_scale(2017, 0.0), content="0")
  inspect(playback.planet_scale(2017, 0.25), content="0.5")
  inspect(playback.planet_scale(2017, 0.5), content="1")
  inspect(playback.planet_scale(2017, 9.0), content="1")
  // 2018 年の始まりは 10 / 9.99 秒のあたり
  inspect(playback.planet_scale(2018, 0.5), content="0")
  assert_true(playback.planet_scale(2018, 1.25) > 0.0)
  assert_true(playback.planet_scale(2018, 1.25) < 1.0)
  inspect(playback.planet_scale(2018, 2.0), content="1")
}

///|
test "一時停止すると大きくなる途中のまま止まる" {
  let paused = @orbit.Playback::start(2017, 2026, 0.0).pause(0.25)
  inspect(paused.planet_scale(2017, 100.0), content="0.5")
}

///|
test "seek した年までの惑星は最大の大きさで、それより後は再生で大きくなる" {
  let seeked = @orbit.Playback::start(2017, 2026, 0.0).seek(2020, 0.0)
  inspect(seeked.planet_scale(2017, 0.0), content="1")
  inspect(seeked.planet_scale(2020, 0.0), content="1")
  inspect(seeked.planet_scale(2021, 0.0), content="0")
  let resumed = seeked.play(0.0)
  inspect(resumed.planet_scale(2020, 0.0), content="1")
  inspect(resumed.planet_scale(2021, 3.0), content="1")
}

///|
test "finished はすべての惑星が揃った状態で止まっている" {
  let playback = @orbit.Playback::finished(2017, 2026)
  assert_false(playback.is_running())
  inspect(playback.time(123.0), content="10")
  inspect(playback.year(123.0), content="2026")
  inspect(playback.planet_scale(2026, 123.0), content="1")
}

///|
test "finished から play すると惑星が揃ったまま公転だけ進む" {
  let playback = @orbit.Playback::finished(2017, 2026).play(100.0)
  assert_true(playback.is_running())
  inspect(playback.year(100.0), content="2026")
  inspect(playback.planet_scale(2026, 100.0), content="1")
  inspect(playback.time(100.0), content="10")
  inspect(playback.time(103.0), content="13")
}
