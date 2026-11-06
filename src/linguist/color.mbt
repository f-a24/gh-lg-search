///|
/// Linguist に色がない言語、または未知の言語に使う色。
pub let default_color : String = "#cccccc"

///|
/// 言語名から `#rrggbb` 形式の色を返す。
///
/// 色は Linguist の `languages.yml` の表記のまま返す（大文字の16進数もある）。
/// 言語名は完全一致で引く。
///
/// ```mbt check
/// test {
///   inspect(@linguist.color_of("TypeScript"), content="#3178c6")
///   inspect(@linguist.color_of("未知の言語"), content="#cccccc")
/// }
/// ```
pub fn color_of(language : String) -> String {
  lookup_color(language).unwrap_or(default_color)
}
