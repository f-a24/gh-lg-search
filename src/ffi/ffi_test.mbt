// ブラウザの API を記録用の偽物に差し替えて、FFI が正しい名前と引数で呼ぶことを確かめる。
// 実際の描画の確認は T3-2 のスクリーンショットで行う。

///|
/// 呼び出しを `name(引数,...)` の形で記録する偽の 2D コンテキストを作る。
extern "js" fn fake_context() -> @ffi.Context2d =
  #|() => {
  #|  const calls = [];
  #|  const record = (name) => (...args) => {
  #|    calls.push(`${name}(${args.join(',')})`);
  #|  };
  #|  const ctx = { calls, canvas: { style: {} } };
  #|  for (const name of [
  #|    'save', 'restore', 'translate', 'rotate', 'fillRect', 'beginPath',
  #|    'arc', 'ellipse', 'fill', 'stroke', 'fillText', 'setTransform',
  #|  ]) {
  #|    ctx[name] = record(name);
  #|  }
  #|  ctx.measureText = (text) => ({ width: text.length * 2 });
  #|  ctx.createRadialGradient = (...args) => {
  #|    record('createRadialGradient')(...args);
  #|    return {
  #|      label: 'gradient',
  #|      addColorStop: record('addColorStop'),
  #|      toString() { return this.label; },
  #|    };
  #|  };
  #|  return ctx;
  #|}

///|
extern "js" fn calls_of(ctx : @ffi.Context2d) -> String = "(c) => c.calls.join(' ')"

///|
/// コンテキストに設定された値を `名前=値` の形で返す。
extern "js" fn styles_of(ctx : @ffi.Context2d) -> String =
  #|(c) => ['fillStyle', 'strokeStyle', 'lineWidth', 'font', 'textAlign']
  #|  .map((name) => `${name}=${c[name]}`).join(' ')

///|
extern "js" fn canvas_size_of(ctx : @ffi.Context2d) -> String =
  #|(c) => [
  #|  c.canvas.width, c.canvas.height, c.canvas.style.width, c.canvas.style.height,
  #|].join(' ')

///|
/// `getElementById` などのブラウザの大域の API を偽物に差し替える。
extern "js" fn install_fake_browser(reduced_motion : Bool) -> Unit =
  #|(reducedMotion) => {
  #|  class FakeCanvas {
  #|    clientWidth = 640;
  #|    getContext(kind) { return kind === '2d' ? { kind } : null; }
  #|  }
  #|  const noContext = new FakeCanvas();
  #|  noContext.getContext = () => null;
  #|  const elements = { stage: new FakeCanvas(), blank: noContext, title: {} };
  #|  globalThis.HTMLCanvasElement = FakeCanvas;
  #|  globalThis.document = { getElementById: (id) => elements[id] ?? null };
  #|  globalThis.devicePixelRatio = 2;
  #|  globalThis.matchMedia = (query) => ({
  #|    matches: reducedMotion && query === '(prefers-reduced-motion: reduce)',
  #|  });
  #|  globalThis.requestAnimationFrame = (callback) => {
  #|    callback(16.5);
  #|    return 7;
  #|  };
  #|  globalThis.cancelAnimationFrame = (id) => { globalThis.cancelledFrame = id; };
  #|}

///|
extern "js" fn cancelled_frame() -> Int32 = "() => globalThis.cancelledFrame"

///|
extern "js" fn clear_device_pixel_ratio() -> Unit = "() => { delete globalThis.devicePixelRatio; }"

///|
test "図形の描画" {
  let ctx = fake_context()
  ctx.save()
  ctx.translate(1, 2)
  ctx.rotate(0.5)
  ctx.begin_path()
  ctx.arc(1, 2, 3, 0, 6)
  ctx.ellipse(1, 2, 3, 4, 0.5, 0, 6)
  ctx.fill()
  ctx.stroke()
  ctx.fill_rect(1, 2, 3, 4)
  ctx.restore()
  inspect(
    calls_of(ctx),
    content="save() translate(1,2) rotate(0.5) beginPath() arc(1,2,3,0,6) ellipse(1,2,3,4,0.5,0,6) fill() stroke() fillRect(1,2,3,4) restore()",
  )
}

///|
test "スタイルと文字" {
  let ctx = fake_context()
  ctx.set_fill_color("#0b0d14")
  ctx.set_stroke_color("#fff")
  ctx.set_line_width(1.5)
  ctx.set_font("500 10px monospace")
  ctx.set_text_align("center")
  ctx.fill_text("Rust", 1, 2)
  inspect(
    styles_of(ctx),
    content="fillStyle=#0b0d14 strokeStyle=#fff lineWidth=1.5 font=500 10px monospace textAlign=center",
  )
  inspect(calls_of(ctx), content="fillText(Rust,1,2)")
  inspect(ctx.measure_text("Rust"), content="8")
}

///|
test "放射グラデーション" {
  let ctx = fake_context()
  let gradient = ctx.create_radial_gradient(1, 2, 0, 1, 2, 3)
  gradient.add_color_stop(0.38, "#3178c6aa")
  ctx.set_fill_gradient(gradient)
  inspect(
    calls_of(ctx),
    content="createRadialGradient(1,2,0,1,2,3) addColorStop(0.38,#3178c6aa)",
  )
  inspect(
    styles_of(ctx),
    content="fillStyle=gradient strokeStyle=undefined lineWidth=undefined font=undefined textAlign=undefined",
  )
}

///|
test "fit_canvas は画素数を dpr 倍にして変換行列を設定し直す" {
  let ctx = fake_context()
  ctx.fit_canvas(320.5, 200, 2)
  inspect(canvas_size_of(ctx), content="641 400 320.5px 200px")
  inspect(calls_of(ctx), content="setTransform(2,0,0,2,0,0)")
}

///|
test "find_canvas と context_2d" {
  install_fake_browser(false)
  guard @ffi.find_canvas("stage") is Some(canvas) else {
    fail("stage が見つからない")
  }
  inspect(canvas.client_width(), content="640")
  assert_true(canvas.context_2d() is Some(_))
  guard @ffi.find_canvas("blank") is Some(blank) else {
    fail("blank が見つからない")
  }
  assert_true(blank.context_2d() is None)
  assert_true(@ffi.find_canvas("title") is None)
  assert_true(@ffi.find_canvas("missing") is None)
}

///|
test "アニメーションフレーム" {
  install_fake_browser(false)
  let received = Ref(0.0)
  let id = @ffi.request_animation_frame(time => received.val = time)
  inspect(id, content="7")
  inspect(received.val, content="16.5")
  @ffi.cancel_animation_frame(id)
  inspect(cancelled_frame(), content="7")
  assert_true(@ffi.performance_now() >= 0)
}

///|
test "device_pixel_ratio" {
  install_fake_browser(false)
  inspect(@ffi.device_pixel_ratio(), content="2")
  clear_device_pixel_ratio()
  inspect(@ffi.device_pixel_ratio(), content="1")
}

///|
test "prefers_reduced_motion" {
  install_fake_browser(true)
  assert_true(@ffi.prefers_reduced_motion())
  install_fake_browser(false)
  assert_false(@ffi.prefers_reduced_motion())
}
