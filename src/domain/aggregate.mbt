///|
/// `created_at`（`2021-02-15T00:00:00Z` の形式）から作成年を取り出す。
/// 先頭が `YYYY-` の形でなければ `None` を返す。
///
/// ```mbt check
/// test {
///   debug_inspect(
///     @domain.parse_created_year("2021-02-15T00:00:00Z"),
///     content="Some(2021)",
///   )
///   debug_inspect(@domain.parse_created_year("unknown"), content="None")
/// }
/// ```
pub fn parse_created_year(created_at : String) -> Int32? {
  guard created_at.length() >= 5 && created_at[4] == '-' else { return None }
  for i = 0, year = 0; i < 4; {
    let digit = created_at[i].to_int() - '0'.to_int()
    guard digit >= 0 && digit <= 9 else { break None }
    continue i + 1, year * 10 + digit
  } nobreak {
    Some(year)
  }
}

///|
/// fork と、言語が判定されていないリポジトリを取り除く。
pub fn filter_countable(repos : Array[RawRepo]) -> Array[Repo] {
  let countable = []
  for repo in repos {
    if repo.language is Some(language) && !repo.fork {
      countable.push({
        name: repo.name,
        url: repo.url,
        language,
        created_year: repo.created_year,
      })
    }
  }
  countable
}

///|
/// 文字列を UTF-16 コード単位の辞書順で比べる。
///
/// `String::compare` は長さを先に比べるため、名前の昇順には使えない。
fn compare_names(a : String, b : String) -> Int32 {
  let common = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<common {
    let order = a[i].to_int() - b[i].to_int()
    if order != 0 {
      return order
    }
  }
  a.length() - b.length()
}

///|
/// 言語ごとのリポジトリ数を集計する。
/// 並び順は件数の降順で、同数なら言語名の昇順。
pub fn aggregate(repos : Array[Repo]) -> Array[LanguageStat] {
  let counts : Map[String, Int32] = Map([])
  for repo in repos {
    counts[repo.language] = counts.get(repo.language).unwrap_or(0) + 1
  }
  let stats = []
  for name, count in counts {
    stats.push({ name, color: @linguist.color_of(name), count, })
  }
  stats.sort_by((a, b) => {
    let by_count = b.count - a.count
    if by_count != 0 {
      by_count
    } else {
      compare_names(a.name, b.name)
    }
  })
  stats
}

///|
/// 作成年の最小値と最大値を返す。リポジトリが空なら `None`。
pub fn year_range(repos : Array[Repo]) -> (Int32, Int32)? {
  guard repos is [first, .. rest] else { return None }
  let range = rest.fold(init=(first.created_year, first.created_year), (
    acc,
    repo,
  ) => {
    let (oldest, newest) = acc
    (
      @cmp.minimum(oldest, repo.created_year),
      @cmp.maximum(newest, repo.created_year),
    )
  })
  Some(range)
}
