///|
test "完了条件の言語の色が引ける" {
  assert_eq(@linguist.color_of("TypeScript"), "#3178c6")
  assert_eq(@linguist.color_of("JavaScript"), "#f1e05a")
  assert_eq(@linguist.color_of("Jupyter Notebook"), "#DA5B0B")
}

///|
test "f-a24 の12言語はすべて Linguist に色がある" {
  for
    language in [
      "TypeScript", "JavaScript", "Jupyter Notebook", "Haskell", "Rust", "CSS", "Elm",
      "GLSL", "Kotlin", "Python", "Svelte", "Swift",
    ] {
    assert_true(
      @linguist.color_of(language) != @linguist.default_color,
      msg="\{language} の色がありません",
    )
  }
}

///|
test "記号を含む言語名も引ける" {
  assert_eq(@linguist.color_of("C++"), "#f34b7d")
  assert_eq(@linguist.color_of("Ren'Py"), "#ff7f7f")
}

///|
test "未知の言語は既定の色" {
  assert_eq(@linguist.default_color, "#cccccc")
  assert_eq(@linguist.color_of("Unknown"), "#cccccc")
  assert_eq(@linguist.color_of(""), "#cccccc")
}

///|
test "Linguist に色がない言語は既定の色" {
  assert_eq(@linguist.color_of("ABNF"), "#cccccc")
}

///|
test "言語名は大文字小文字を区別する" {
  assert_eq(@linguist.color_of("typescript"), "#cccccc")
}
