///|
/// fixture の JSON を `RawRepo` の配列にする。
fn fixture_repos() -> Array[@domain.RawRepo] raise {
  guard @json.parse(f_a24_repos_json) is Array(items) else {
    fail("fixture の最上位が配列ではない")
  }
  items.map(item => {
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
}

///|
fn repo(name : String, language : String, year : Int32) -> @domain.Repo {
  { name, url: "https://github.com/x/\{name}", language, created_year: year, }
}

///|
test "f-a24 の fixture を集計する" {
  let repos = @domain.filter_countable(fixture_repos())
  assert_eq(repos.length(), 51)
  assert_false(repos.iter().any(r => r.name is ("three.js" | "slides-sandbox")))
  let stats = @domain.aggregate(repos)
  assert_eq(stats.map(stat => (stat.name, stat.count)), [
    ("TypeScript", 27),
    ("JavaScript", 7),
    ("Jupyter Notebook", 6),
    ("Haskell", 2),
    ("Rust", 2),
    ("CSS", 1),
    ("Elm", 1),
    ("GLSL", 1),
    ("Kotlin", 1),
    ("Python", 1),
    ("Svelte", 1),
    ("Swift", 1),
  ])
  assert_eq(@domain.year_range(repos), Some((2017, 2026)))
}

///|
test "fork と言語なしを除外する" {
  let raw : Array[@domain.RawRepo] = [
    {
      name: "a",
      url: "u",
      language: Some("Rust"),
      fork: false,
      created_year: 2020,
    },
    {
      name: "b",
      url: "u",
      language: Some("Rust"),
      fork: true,
      created_year: 2020,
    },
    { name: "c", url: "u", language: None, fork: false, created_year: 2020, },
  ]
  assert_eq(@domain.filter_countable(raw), [
    { name: "a", url: "u", language: "Rust", created_year: 2020, },
  ])
}

///|
test "同数の言語は長さではなく名前の昇順に並ぶ" {
  let stats = @domain.aggregate([
    repo("a", "Swift", 2020),
    repo("b", "Rust", 2020),
    repo("c", "Haskell", 2020),
    repo("d", "Go", 2020),
    repo("e", "Go", 2021),
    repo("f", "C", 2021),
    repo("g", "C++", 2021),
  ])
  assert_eq(stats.map(stat => stat.name), [
    "Go", "C", "C++", "Haskell", "Rust", "Swift",
  ])
}

///|
test "集計結果に言語の色が入る" {
  let stats = @domain.aggregate([
    repo("a", "TypeScript", 2020),
    repo("b", "TypeScript", 2021),
    repo("c", "Unknown", 2020),
  ])
  assert_eq(stats[0].color, "#3178c6")
  assert_eq(stats[1].color, "#cccccc")
}

///|
test "空の入力" {
  assert_eq(@domain.aggregate([]), [])
  assert_eq(@domain.year_range([]), None)
}

///|
test "作成年を解釈できない文字列" {
  assert_eq(@domain.parse_created_year(""), None)
  assert_eq(@domain.parse_created_year("20x1-01-01"), None)
  assert_eq(@domain.parse_created_year("20210101"), None)
}
