///|
test "埋め込んだ fixture から対象のリポジトリを読める" {
  let repos = fixture_repos()
  assert_eq(repos.length(), 51)
  assert_eq(@domain.year_range(repos), Some((2017, 2026)))
}
