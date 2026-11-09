///|
/// 次の描画の前に `callback` を呼ぶよう予約し、取り消し用の id を返す。
/// `callback` は `performance_now` と同じ基準の時刻（ミリ秒）を受け取る。
pub extern "js" fn request_animation_frame(
  callback : (Double) -> Unit,
) -> Int32 = "(callback) => requestAnimationFrame(callback)"

///|
/// `request_animation_frame` の予約を取り消す。
pub extern "js" fn cancel_animation_frame(id : Int32) -> Unit = "(id) => cancelAnimationFrame(id)"

///|
/// ページを開いてからの経過時間（ミリ秒）。
pub extern "js" fn performance_now() -> Double = "() => performance.now()"

///|
/// 画面の CSS ピクセルあたりの実ピクセル数。取得できないときは 1。
pub extern "js" fn device_pixel_ratio() -> Double = "() => globalThis.devicePixelRatio || 1"

///|
/// URL のクエリ `name` の値を返す。ないときは空文字列。
pub extern "js" fn query_param(name : String) -> String = "(name) => new URLSearchParams(location.search).get(name) ?? ''"

///|
/// 履歴を増やさずに、URL のクエリ `name` を `value` にする。パスはそのまま残す。
pub extern "js" fn set_query_param(name : String, value : String) -> Unit =
  #|(name, value) => {
  #|  const url = new URL(location.href);
  #|  url.searchParams.set(name, value);
  #|  history.replaceState(history.state, '', url.href);
  #|}

///|
/// 今の年（利用者のタイムゾーン）。
pub extern "js" fn current_year() -> Int32 = "() => new Date().getFullYear()"

///|
/// UNIX 時刻（秒）を、利用者のタイムゾーンの `HH:MM:SS` にする。
pub extern "js" fn format_time(epoch : Int32) -> String = "(epoch) => new Date(epoch * 1000).toLocaleTimeString('ja-JP')"

///|
/// 利用者が OS で「視差効果を減らす」を選んでいるとき `true`。
pub extern "js" fn prefers_reduced_motion() -> Bool =
  #|() => matchMedia('(prefers-reduced-motion: reduce)').matches
