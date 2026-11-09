///|
/// GitHub からの取得に失敗した理由。
#derive(Debug, Eq)
pub(all) suberror FetchError {
  NotFound
  RateLimited(reset_epoch~ : Int32)
  Network(String)
  Decode(String)
}

///|
pub extend FetchError with @debug.Debug::{to_repr}

///|
pub extend FetchError with Eq::{equal, not_equal}

///|
let api_base = "https://api.github.com"

///|
let repos_per_page = 100

///|
fn profile_url(user : String) -> String {
  "\{api_base}/users/\{@ffi.encode_uri_component(user)}"
}

///|
fn repos_url(user : String, page : Int32) -> String {
  "\{profile_url(user)}/repos?per_page=\{repos_per_page}&page=\{page}"
}

///|
/// `public_repos` 件を取得するのに必要なページ数。
fn page_count(public_repos : Int32) -> Int32 {
  (public_repos + repos_per_page - 1) / repos_per_page
}

///|
/// 応答を確かめて本文を返す。成功以外は理由ごとの `FetchError` にする。
fn body_of(response : @ffi.HttpResponse) -> String raise FetchError {
  match (response.status, response.ratelimit_remaining) {
    (200..<300, _) => response.body
    (404, _) => raise NotFound
    (403, Some("0")) => raise RateLimited(reset_epoch=reset_epoch_of(response))
    (status, _) => raise Network("HTTP \{status}")
  }
}

///|
fn reset_epoch_of(response : @ffi.HttpResponse) -> Int32 raise FetchError {
  let reset = response.ratelimit_reset.unwrap_or("")
  @string.parse_int(reset) catch {
    _ => raise Decode("x-ratelimit-reset を解釈できない: \{reset}")
  }
}

///|
fn parse_json(text : String) -> Json raise FetchError {
  @json.parse(text) catch {
    _ => raise Decode("JSON として解釈できない")
  }
}

///|
/// `null` や欠けているフィールドは `None` にする。
fn optional_string(value : Json?) -> String? {
  if value is Some(String(text)) {
    Some(text)
  } else {
    None
  }
}

///|
/// `GET /users/{user}` の本文をデコードする。未知のフィールドは無視する。
fn decode_profile(text : String) -> @domain.Profile raise FetchError {
  guard parse_json(text)
    is {
      "login": String(login),
      "avatar_url": String(avatar_url),
      "public_repos": Number(public_repos, ..),
      "name"? : name,
      "bio"? : bio,
      ..
    } else {
    raise Decode("ユーザー情報の形が想定と違う")
  }
  {
    login,
    name: optional_string(name),
    avatar_url,
    bio: optional_string(bio),
    public_repos: public_repos.to_int(),
  }
}

///|
fn decode_repo(item : Json) -> @domain.RawRepo raise FetchError {
  guard item
    is {
      "name": String(name),
      "html_url": String(url),
      "fork": True
      | False as fork,
      "created_at": String(created_at),
      "language"? : language,
      ..
    } else {
    raise Decode("リポジトリの形が想定と違う")
  }
  guard @domain.parse_created_year(created_at) is Some(created_year) else {
    raise Decode("created_at を解釈できない: \{created_at}")
  }
  {
    name,
    url,
    language: optional_string(language),
    fork: fork is True,
    created_year,
  }
}

///|
/// `GET /users/{user}/repos` の本文をデコードする。未知のフィールドは無視する。
fn decode_repos(text : String) -> Array[@domain.RawRepo] raise FetchError {
  guard parse_json(text) is Array(items) else {
    raise Decode("リポジトリの一覧が配列ではない")
  }
  items.map(decode_repo)
}

///|
/// すべての `urls` を取得して本文を返す。
async fn get_bodies(urls : Array[String]) -> Array[String] raise FetchError {
  let responses = @ffi.http_get_all(urls) catch {
    error => raise Network(error.to_string())
  }
  responses.map(body_of)
}

///|
/// ユーザーのプロフィールを取得する。
pub async fn fetch_profile(user : String) -> @domain.Profile raise FetchError {
  decode_profile(get_bodies([profile_url(user)])[0])
}

///|
/// ユーザーの公開リポジトリを全ページ取得し、集計の対象になるものだけを返す。
/// `public_repos` は `fetch_profile` で得た値を渡す。
pub async fn fetch_repos(
  user : String,
  public_repos : Int32,
) -> Array[@domain.Repo] raise FetchError {
  let urls = [
    for page in 1..<=page_count(public_repos) => repos_url(user, page)
  ]
  let raw = []
  for body in get_bodies(urls) {
    raw.append(decode_repos(body))
  }
  @domain.filter_countable(raw)
}
