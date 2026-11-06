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
/// 利用者が OS で「視差効果を減らす」を選んでいるとき `true`。
pub extern "js" fn prefers_reduced_motion() -> Bool =
  #|() => matchMedia('(prefers-reduced-motion: reduce)').matches
