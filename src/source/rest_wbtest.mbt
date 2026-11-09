///|
fn response(
  status : Int32,
  remaining? : String,
  reset? : String,
  body~ : String = "ok",
) -> @ffi.HttpResponse {
  { status, ratelimit_remaining: remaining, ratelimit_reset: reset, body, }
}

///|
/// `f` が投げた `FetchError` を返す。投げなければテストを失敗させる。
fn[T] error_of(f : () -> T raise FetchError) -> FetchError raise {
  try f() catch {
    error => error
  } noraise {
    _ => fail("FetchError が投げられなかった")
  }
}

///|
test "fixture のプロフィールをデコードする" {
  assert_eq(decode_profile(f_a24_user_json), {
    login: "f-a24",
    name: Some("Atsushi Fujisawa"),
    avatar_url: "https://avatars.githubusercontent.com/u/33566510?v=4",
    bio: None,
    public_repos: 53,
  })
}

///|
test "fixture のリポジトリをデコードする" {
  let raw = decode_repos(f_a24_repos_json)
  assert_eq(raw.length(), 53)
  assert_eq(raw[0], {
    name: "deep-zero1",
    url: "https://github.com/f-a24/deep-zero1",
    language: Some("Jupyter Notebook"),
    fork: false,
    created_year: 2021,
  })
  assert_true(raw.iter().any(repo => repo.name == "three.js" && repo.fork))
  assert_true(
    raw
    .iter()
    .any(repo => repo.name == "slides-sandbox" && repo.language is None),
  )
  assert_eq(@domain.filter_countable(raw).length(), 51)
}

///|
test "未知のフィールドは無視し、欠けた任意項目は None にする" {
  let profile_body =
    #|{"login":"a","avatar_url":"u","public_repos":0,"id":1,"extra":{"x":[]}}
  let profile = decode_profile(profile_body)
  assert_eq(profile.name, None)
  assert_eq(profile.bio, None)
  let repos_body =
    #|[{"name":"r","html_url":"u","fork":false,"created_at":"2020-01-02T03:04:05Z","stargazers_count":3}]
  let repos = decode_repos(repos_body)
  assert_eq(repos[0].language, None)
  assert_eq(repos[0].created_year, 2020)
}

///|
test "形が違う本文は Decode になる" {
  assert_true(error_of(() => decode_profile("<html>")) is Decode(_))
  assert_true(error_of(() => decode_profile("[]")) is Decode(_))
  assert_true(error_of(() => decode_repos("{}")) is Decode(_))
  assert_true(error_of(() => decode_repos("[{\"name\":1}]")) is Decode(_))
  let bad_year =
    #|[{"name":"r","html_url":"u","fork":false,"created_at":"unknown"}]
  assert_true(error_of(() => decode_repos(bad_year)) is Decode(_))
}

///|
test "応答のステータスで FetchError を返し分ける" {
  assert_eq(body_of(response(200, body="hello")), "hello")
  assert_eq(error_of(() => body_of(response(404))), NotFound)
  assert_eq(
    error_of(() => body_of(response(403, remaining="0", reset="1800000000"))),
    RateLimited(reset_epoch=1800000000),
  )
  // 残り回数があるときの 403 はレート制限ではない
  assert_eq(
    error_of(() => body_of(response(403, remaining="5", reset="1800000000"))),
    Network("HTTP 403"),
  )
  assert_eq(error_of(() => body_of(response(500))), Network("HTTP 500"))
  assert_true(
    error_of(() => body_of(response(403, remaining="0"))) is Decode(_),
  )
}

///|
test "ページ数は public_repos から切り上げで求める" {
  assert_eq(page_count(0), 0)
  assert_eq(page_count(1), 1)
  assert_eq(page_count(100), 1)
  assert_eq(page_count(101), 2)
  assert_eq(page_count(530), 6)
}

///|
test "URL のユーザー名を符号化する" {
  assert_eq(profile_url("f-a24"), "https://api.github.com/users/f-a24")
  assert_eq(
    repos_url("f-a24", 2),
    "https://api.github.com/users/f-a24/repos?per_page=100&page=2",
  )
  assert_eq(profile_url("a/b?c"), "https://api.github.com/users/a%2Fb%3Fc")
}
