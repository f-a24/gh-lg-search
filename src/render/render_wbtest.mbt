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
test "status_text は年と件数を並べる" {
  inspect(status_text(2019, 25, 51), content="2019  ·  25/51 repos")
}
