///|
test "font は大きさを倍率で拡大して整数に丸める" {
  inspect(
    font(LABEL_FONT_SIZE, 1.0),
    content="500 11px \"IBM Plex Mono\", ui-monospace, monospace",
  )
  inspect(
    font(STATUS_FONT_SIZE, 1.5),
    content="500 20px \"IBM Plex Mono\", ui-monospace, monospace",
  )
}

///|
test "planet_radius は出現の倍率で大きくなり、0 でも点として残る" {
  inspect(planet_radius(2.0, 0.0), content="0.3")
  inspect(planet_radius(2.0, 0.5), content="3.3")
  inspect(planet_radius(2.0, 1.0), content="6.3")
}

///|
test "status_text は年と件数を並べる" {
  inspect(status_text(2019, 25, 51), content="2019  ·  25/51 repos")
}
