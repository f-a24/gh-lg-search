///|
using @html {div}

///|
using @rabbita {type Val, type Html}

///|
/// 動作確認用の最小の画面。本物の画面は T4-2 で作る。
fn app() -> Val[Html] {
  let (hello, _) = @rabbita.create_pure_state("Hello", update=fn(
    state,
    _ : Unit,
  ) {
    state
  })
  hello.view(text => div(text))
}

///|
fn main {
  @rabbita.new(app).mount("app")
}
