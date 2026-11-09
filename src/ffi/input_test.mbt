///|
/// Node の `EventTarget` でポインターのイベントを受けられる偽の canvas を作る。
extern "js" fn fake_event_canvas() -> @ffi.Canvas =
  #|() => {
  #|  const canvas = new EventTarget();
  #|  canvas.getBoundingClientRect = () => ({ left: 10, top: 20 });
  #|  canvas.style = {};
  #|  return canvas;
  #|}

///|
extern "js" fn send_pointer(
  canvas : @ffi.Canvas,
  kind : String,
  pointer_type : String,
  x : Double,
  y : Double,
) -> Unit =
  #|(canvas, kind, pointerType, x, y) => {
  #|  canvas.dispatchEvent(
  #|    Object.assign(new Event(kind), { pointerType, clientX: x, clientY: y }),
  #|  );
  #|}

///|
extern "js" fn cursor_of(canvas : @ffi.Canvas) -> String = "(canvas) => canvas.style.cursor"

///|
/// `canvas` の操作を監視し、受けた内容を文字列で `log` に記録する。
fn watch_log(canvas : @ffi.Canvas, log : Array[String]) -> @ffi.Subscription {
  canvas.watch_pointer(
    (x, y) => log.push("hover \{x} \{y}"),
    () => log.push("leave"),
    (x, y, touch) => log.push("tap \{x} \{y} \{touch}"),
  )
}

///|
test "watch_pointer はキャンバス内の座標を渡す" {
  let canvas = fake_event_canvas()
  let log = []
  let _ = watch_log(canvas, log)
  send_pointer(canvas, "pointermove", "mouse", 15, 27)
  send_pointer(canvas, "pointerleave", "mouse", 0, 0)
  send_pointer(canvas, "pointerdown", "mouse", 15, 27)
  send_pointer(canvas, "click", "", 15, 27)
  inspect(log.join(" / "), content="hover 5 7 / leave / tap 5 7 false")
}

///|
test "watch_pointer はタッチの移動と離脱を無視し、タップを知らせる" {
  let canvas = fake_event_canvas()
  let log = []
  let _ = watch_log(canvas, log)
  send_pointer(canvas, "pointerdown", "touch", 15, 27)
  send_pointer(canvas, "pointermove", "touch", 16, 28)
  send_pointer(canvas, "pointerleave", "touch", 16, 28)
  send_pointer(canvas, "click", "", 15, 27)
  inspect(log.join(" / "), content="tap 5 7 true")
}

///|
test "cancel のあとは watch_pointer が呼ばれない" {
  let canvas = fake_event_canvas()
  let log = []
  let subscription = watch_log(canvas, log)
  subscription.cancel()
  send_pointer(canvas, "pointermove", "mouse", 15, 27)
  inspect(log.length(), content="0")
}

///|
/// `ResizeObserver` と `setTimeout` を、手で進められる偽物に差し替える。
extern "js" fn install_fake_observer() -> Unit =
  #|() => {
  #|  globalThis.realSetTimeout ??= globalThis.setTimeout;
  #|  globalThis.pendingTimer = null;
  #|  globalThis.setTimeout = (callback) => {
  #|    globalThis.pendingTimer = callback;
  #|    return 1;
  #|  };
  #|  globalThis.ResizeObserver = class {
  #|    constructor(callback) { globalThis.notifyResize = callback; }
  #|    observe(target) { globalThis.observed = target; }
  #|    disconnect() { globalThis.observed = null; }
  #|  };
  #|}

///|
extern "js" fn restore_timers() -> Unit = "() => { globalThis.setTimeout = globalThis.realSetTimeout; }"

///|
extern "js" fn notify_resize() -> Unit = "() => globalThis.notifyResize()"

///|
extern "js" fn run_pending_timer() -> Unit = "() => { globalThis.pendingTimer?.(); globalThis.pendingTimer = null; }"

///|
extern "js" fn is_observed() -> Bool = "() => globalThis.observed != null"

///|
test "watch_resize は変化が落ち着いてから1回呼ぶ" {
  install_fake_observer()
  let canvas = fake_event_canvas()
  let count = Ref(0)
  let subscription = canvas.watch_resize(() => count.val += 1)
  assert_true(is_observed())
  notify_resize()
  notify_resize()
  inspect(count.val, content="0")
  run_pending_timer()
  inspect(count.val, content="1")
  subscription.cancel()
  assert_false(is_observed())
  restore_timers()
}

///|
test "set_cursor" {
  let canvas = fake_event_canvas()
  canvas.set_cursor("pointer")
  inspect(cursor_of(canvas), content="pointer")
}

///|
extern "js" fn install_fake_open() -> Unit =
  #|() => {
  #|  globalThis.open = (...args) => { globalThis.opened = args.join(' '); };
  #|}

///|
extern "js" fn opened() -> String = "() => globalThis.opened"

///|
test "open_new_tab は別のタブで開く" {
  install_fake_open()
  @ffi.open_new_tab("https://github.com/a/b")
  inspect(opened(), content="https://github.com/a/b _blank noopener")
}

///|
extern "js" fn fake_rect_context(with_round : Bool) -> @ffi.Context2d =
  #|(withRound) => {
  #|  const ctx = { calls: [], textBaseline: '' };
  #|  ctx.rect = (...args) => ctx.calls.push(`rect(${args.join(',')})`);
  #|  if (withRound) {
  #|    ctx.roundRect = (...args) => ctx.calls.push(`roundRect(${args.join(',')})`);
  #|  }
  #|  return ctx;
  #|}

///|
extern "js" fn rect_calls(ctx : @ffi.Context2d) -> String = "(c) => c.calls.join(' ')"

///|
extern "js" fn baseline_of(ctx : @ffi.Context2d) -> String = "(c) => c.textBaseline"

///|
test "round_rect は roundRect がなければ長方形にする" {
  let rounded = fake_rect_context(true)
  rounded.round_rect(1, 2, 3, 4, 5)
  inspect(rect_calls(rounded), content="roundRect(1,2,3,4,5)")
  let plain = fake_rect_context(false)
  plain.round_rect(1, 2, 3, 4, 5)
  inspect(rect_calls(plain), content="rect(1,2,3,4)")
}

///|
test "set_text_baseline" {
  let ctx = fake_rect_context(true)
  ctx.set_text_baseline("middle")
  inspect(baseline_of(ctx), content="middle")
}
