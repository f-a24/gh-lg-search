///|
/// Linguist に色がない言語、または未知の言語に使う色。
pub let default_color : String = "#cccccc"

///|
/// 言語名から `#rrggbb` 形式の色を返す。
///
/// 色の表は T1-2 で生成する。それまではすべての言語に `default_color` を返す。
pub fn color_of(_language : String) -> String {
  default_color
}
