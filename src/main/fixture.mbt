///|
/// 埋め込んだ fixture の JSON を、集計の対象になるリポジトリの配列にする。
/// GitHub API から取得できるようになるまでの仮のデータ源。T4-2 で取り除く。
fn fixture_repos() -> Array[@domain.Repo] raise {
  guard @json.parse(f_a24_repos_json) is Array(items) else {
    fail("fixture の最上位が配列ではない")
  }
  let raw = items.map(item => {
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
    let repo : @domain.RawRepo = {
      name,
      url,
      language,
      fork: fork is True,
      created_year,
    }
    repo
  })
  @domain.filter_countable(raw)
}
