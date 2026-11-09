///|
/// イベントの監視。`cancel` で解除する。
#external
pub type Subscription

///|
/// 監視を解除する。
pub extern "js" fn Subscription::cancel(self : Subscription) -> Unit = "(cancel) => cancel()"

///|
/// キャンバス上のポインター操作を監視する。座標はキャンバスの左上からの CSS ピクセル。
///
/// `on_hover` と `on_leave` はマウスとペンのときだけ呼ぶ。タッチの指の移動は
/// スクロールなので扱わない。`on_tap` はクリックとタップで呼び、3番目の引数は
/// タッチのとき `true`。
pub extern "js" fn Canvas::watch_pointer(
  self : Canvas,
  on_hover : (Double, Double) -> Unit,
  on_leave : () -> Unit,
  on_tap : (Double, Double, Bool) -> Unit,
) -> Subscription =
  #|(canvas, onHover, onLeave, onTap) => {
  #|  const controller = new AbortController();
  #|  const options = { signal: controller.signal };
  #|  const locate = (event) => {
  #|    const rect = canvas.getBoundingClientRect();
  #|    return [event.clientX - rect.left, event.clientY - rect.top];
  #|  };
  #|  // click の pointerType はブラウザによってはないので、直前の pointerdown で判断する
  #|  let touch = false;
  #|  canvas.addEventListener('pointerdown', (event) => {
  #|    touch = event.pointerType === 'touch';
  #|  }, options);
  #|  canvas.addEventListener('pointermove', (event) => {
  #|    if (event.pointerType !== 'touch') onHover(...locate(event));
  #|  }, options);
  #|  canvas.addEventListener('pointerleave', (event) => {
  #|    if (event.pointerType !== 'touch') onLeave();
  #|  }, options);
  #|  canvas.addEventListener('click', (event) => {
  #|    onTap(...locate(event), touch);
  #|  }, options);
  #|  return () => controller.abort();
  #|}

///|
/// キャンバスの表示サイズの変化を監視する。変化が落ち着いてから `callback` を呼ぶ。
/// 監視を始めた直後にも1回呼ばれる。
pub extern "js" fn Canvas::watch_resize(
  self : Canvas,
  callback : () -> Unit,
) -> Subscription =
  #|(canvas, callback) => {
  #|  let timer;
  #|  const observer = new ResizeObserver(() => {
  #|    clearTimeout(timer);
  #|    timer = setTimeout(() => callback(), 120);
  #|  });
  #|  observer.observe(canvas);
  #|  return () => {
  #|    clearTimeout(timer);
  #|    observer.disconnect();
  #|  };
  #|}

///|
/// マウスカーソルの形を CSS の `cursor` の値で設定する。
pub extern "js" fn Canvas::set_cursor(self : Canvas, cursor : String) -> Unit = "(canvas, cursor) => { canvas.style.cursor = cursor; }"

///|
/// `url` を新しいタブで開く。
pub extern "js" fn open_new_tab(url : String) -> Unit = "(url) => { globalThis.open(url, '_blank', 'noopener'); }"
