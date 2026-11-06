///|
/// GitHub API から受け取ったままのリポジトリ。集計の対象外も含む。
#derive(Debug, Eq)
pub(all) struct RawRepo {
  name : String
  url : String
  language : String?
  fork : Bool
  created_year : Int32
}

///|
/// 集計の対象になるリポジトリ。
#derive(Debug, Eq)
pub(all) struct Repo {
  name : String
  url : String
  language : String
  created_year : Int32
}

///|
/// 言語ごとの集計結果。`count` はリポジトリ数。
#derive(Debug, Eq)
pub(all) struct LanguageStat {
  name : String
  color : String
  count : Int32
}

///|
/// GitHub ユーザーのプロフィール。
#derive(Debug, Eq)
pub(all) struct Profile {
  login : String
  name : String?
  avatar_url : String
  bio : String?
}

///|
pub extend RawRepo with @debug.Debug::{to_repr}

///|
pub extend RawRepo with Eq::{equal, not_equal}

///|
pub extend Repo with @debug.Debug::{to_repr}

///|
pub extend Repo with Eq::{equal, not_equal}

///|
pub extend LanguageStat with @debug.Debug::{to_repr}

///|
pub extend LanguageStat with Eq::{equal, not_equal}

///|
pub extend Profile with @debug.Debug::{to_repr}

///|
pub extend Profile with Eq::{equal, not_equal}
